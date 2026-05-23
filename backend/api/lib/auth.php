<?php
declare(strict_types=1);

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\JWK;

/**
 * Verify a Google ID token. Returns ['sub' => ..., 'email' => ..., 'name' => ..., 'picture' => ...].
 * Throws HttpException on failure.
 */
function verify_google_id_token(string $idToken, string $clientId): array {
    $clientId = trim($clientId);
    if ($clientId === '' || str_starts_with($clientId, 'REPLACE_WITH_')) {
        throw new HttpException(500, 'Google Sign-In backend client ID is not configured.');
    }
    if (!class_exists(\Google\Client::class)) {
        throw new HttpException(500, 'Google Sign-In backend dependency is not installed. Upload backend/api/vendor/.');
    }

    try {
        $client = new Google\Client(['client_id' => $clientId]);
        $payload = $client->verifyIdToken($idToken);
    } catch (Throwable $e) {
        throw new HttpException(401, 'Google token verification error: ' . $e->getMessage());
    }
    if (!$payload || empty($payload['sub'])) {
        throw new HttpException(401, 'Invalid Google ID token.');
    }
    if (!isset($payload['aud']) || $payload['aud'] !== $clientId) {
        throw new HttpException(401, 'Google ID token audience mismatch.');
    }
    return [
        'sub'     => (string)$payload['sub'],
        'email'   => $payload['email']   ?? null,
        'name'    => $payload['name']    ?? null,
        'picture' => $payload['picture'] ?? null,
    ];
}

/**
 * Verify a Sign in with Apple identity token (ES256, JWKs from appleid.apple.com).
 * Returns ['sub' => ..., 'email' => ?]. Apple does not return name in the token —
 * the client passes it on first sign-in and we persist it.
 */
function verify_apple_id_token(string $idToken, string $bundleId): array {
    $bundleId = trim($bundleId);
    if ($bundleId === '' || str_starts_with($bundleId, 'REPLACE_WITH_')) {
        throw new HttpException(500, 'Apple Sign-In backend bundle ID is not configured.');
    }
    if (!class_exists(\Firebase\JWT\JWT::class) || !class_exists(\Firebase\JWT\JWK::class)) {
        throw new HttpException(500, 'Apple Sign-In backend dependency is not installed. Upload backend/api/vendor/.');
    }

    static $cachedKeys = null;
    if ($cachedKeys === null) {
        $json = @file_get_contents('https://appleid.apple.com/auth/keys');
        if (!$json) {
            throw new HttpException(503, 'Could not fetch Apple JWKs.');
        }
        $keys = json_decode($json, true);
        if (!$keys || empty($keys['keys'])) {
            throw new HttpException(503, 'Apple JWKs response malformed.');
        }
        $cachedKeys = JWK::parseKeySet($keys);
    }
    try {
        $decoded = JWT::decode($idToken, $cachedKeys);
    } catch (Throwable $e) {
        throw new HttpException(401, 'Apple token verification error: ' . $e->getMessage());
    }
    $sub = $decoded->sub ?? null;
    if (!$sub) {
        throw new HttpException(401, 'Invalid Apple ID token.');
    }
    if (($decoded->aud ?? '') !== $bundleId) {
        throw new HttpException(401, 'Apple ID token audience mismatch.');
    }
    if (($decoded->iss ?? '') !== 'https://appleid.apple.com') {
        throw new HttpException(401, 'Apple ID token issuer mismatch.');
    }
    if (($decoded->exp ?? 0) < time()) {
        throw new HttpException(401, 'Apple ID token expired.');
    }
    return [
        'sub'   => (string)$sub,
        'email' => $decoded->email ?? null,
    ];
}

/**
 * Read the bearer token from the Authorization header, verify it, and return
 * a user row from the DB. Used at the top of every protected route.
 * The user array is stashed in $GLOBALS['authed_user'] for easy access.
 */
function require_auth(array $config): array {
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $auth = '';
    foreach ($headers as $k => $v) {
        if (strcasecmp($k, 'Authorization') === 0) { $auth = $v; break; }
    }
    if (!$auth && isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $auth = $_SERVER['HTTP_AUTHORIZATION'];
    }
    if (!preg_match('/^Bearer\s+(.+)$/i', $auth, $m)) {
        throw new HttpException(401, 'Missing or invalid Authorization header.');
    }
    $userId = jwt_verify_access($m[1], $config['jwt_secret']);

    $stmt = db()->prepare('SELECT id, email, name, photo_url, provider, provider_sub FROM users WHERE id = :id AND deleted_at IS NULL LIMIT 1');
    $stmt->execute([':id' => $userId]);
    $user = $stmt->fetch();
    if (!$user) {
        throw new HttpException(401, 'User not found.');
    }
    $GLOBALS['authed_user'] = $user;
    return $user;
}

function current_user(): array {
    if (empty($GLOBALS['authed_user'])) {
        throw new RuntimeException('current_user() called without require_auth.');
    }
    return $GLOBALS['authed_user'];
}

/** Lightweight per-IP rate limit. Returns true if allowed, false if over limit. */
function rate_limit_login(array $config): bool {
    $ip = client_ip();
    $window = $config['login_rate']['window_seconds'] ?? 60;
    $max    = $config['login_rate']['max_attempts']   ?? 10;
    $windowStart = gmdate('Y-m-d H:i:s', (int)floor(time() / $window) * $window);

    $pdo = db();
    try {
        $pdo->prepare('INSERT INTO auth_rate_limit (ip, window_start, attempts) VALUES (:ip, :w, 1) ON DUPLICATE KEY UPDATE attempts = attempts + 1')
            ->execute([':ip' => $ip, ':w' => $windowStart]);

        $stmt = $pdo->prepare('SELECT attempts FROM auth_rate_limit WHERE ip = :ip AND window_start = :w LIMIT 1');
        $stmt->execute([':ip' => $ip, ':w' => $windowStart]);
        $row = $stmt->fetch();
        $attempts = (int)($row['attempts'] ?? 0);

        // Best-effort cleanup of old windows.
        $pdo->prepare('DELETE FROM auth_rate_limit WHERE window_start < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 HOUR)')->execute();

        return $attempts <= $max;
    } catch (Throwable $e) {
        error_log('[api] Login rate limit unavailable: ' . $e->getMessage());
        return true;
    }
}
