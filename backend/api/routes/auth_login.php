<?php
declare(strict_types=1);

$body = read_json_body();
$provider = require_field($body, 'provider');
$idToken  = require_field($body, 'idToken');
$fallbackEmail = $body['email']    ?? null;
$fallbackName  = $body['name']     ?? null;
$fallbackPhoto = $body['photoURL'] ?? null;

if (!in_array($provider, ['google', 'apple'], true)) {
    json_error(400, 'Unsupported provider.');
}

if (!rate_limit_login($CONFIG)) {
    json_error(429, 'Too many login attempts. Try again shortly.');
}

try {
    if ($provider === 'google') {
        $verified = verify_google_id_token($idToken, (string)($CONFIG['google_ios_client_id'] ?? ''));
        $email   = $verified['email']   ?? $fallbackEmail;
        $name    = $verified['name']    ?? $fallbackName;
        $picture = $verified['picture'] ?? $fallbackPhoto;
        $sub     = $verified['sub'];
    } else {
        $verified = verify_apple_id_token($idToken, (string)($CONFIG['apple_bundle_id'] ?? ''));
        $email   = $verified['email'] ?? $fallbackEmail;
        $name    = $fallbackName; // Apple does not return name in the token.
        $picture = null;
        $sub     = $verified['sub'];
    }
} catch (HttpException $e) {
    throw $e;
} catch (Throwable $e) {
    error_log('[api] Auth provider verification failed: ' . $e->getMessage());
    json_error(500, 'Auth provider verification failed: ' . $e->getMessage());
}

if (!$email) {
    json_error(400, 'No email available from sign-in. Please try again.');
}

$pdo = db();
$pdo->beginTransaction();
try {
    // Upsert user.
    $stmt = $pdo->prepare('SELECT id, email, name, photo_url FROM users WHERE provider = :p AND provider_sub = :s LIMIT 1');
    $stmt->execute([':p' => $provider, ':s' => $sub]);
    $user = $stmt->fetch();

    $now = db_now();
    if ($user) {
        $userId = $user['id'];
        $pdo->prepare('UPDATE users SET email = :e, photo_url = COALESCE(:pu, photo_url), updated_at = :u, deleted_at = NULL WHERE id = :id')
            ->execute([':e' => $email, ':pu' => $picture, ':u' => $now, ':id' => $userId]);
    } else {
        $userId = uuid_v4();
        $pdo->prepare('INSERT INTO users (id, email, name, photo_url, provider, provider_sub, created_at, updated_at) VALUES (:id, :e, :n, :pu, :p, :s, :c, :u)')
            ->execute([
                ':id' => $userId, ':e' => $email, ':n' => $name, ':pu' => $picture,
                ':p' => $provider, ':s' => $sub, ':c' => $now, ':u' => $now,
            ]);
        // Seed default settings.
        $pdo->prepare('INSERT INTO user_settings (user_id, updated_at) VALUES (:u, :n)')
            ->execute([':u' => $userId, ':n' => $now]);
    }

    // Issue tokens.
    $jwtSecret = (string)($CONFIG['jwt_secret'] ?? '');
    if ($jwtSecret === '' || str_starts_with($jwtSecret, 'REPLACE_WITH_')) {
        throw new HttpException(500, 'Backend JWT secret is not configured.');
    }
    $accessTtl = (int)($CONFIG['access_token_ttl_seconds'] ?? 15 * 60);
    $refreshTtl = (int)($CONFIG['refresh_token_ttl_seconds'] ?? 60 * 60 * 24 * 60);

    $access = jwt_issue_access($userId, $jwtSecret, $accessTtl);
    $refresh = refresh_token_create();
    $expiresAt = gmdate('Y-m-d H:i:s', time() + $refreshTtl);
    $pdo->prepare('INSERT INTO refresh_tokens (token_hash, user_id, issued_at, expires_at) VALUES (:h, :u, :i, :e)')
        ->execute([':h' => $refresh['hash'], ':u' => $userId, ':i' => $now, ':e' => $expiresAt]);

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    throw $e;
}

// Reload user for response.
$stmt = $pdo->prepare('SELECT id, email, name, photo_url, provider FROM users WHERE id = :id LIMIT 1');
$stmt->execute([':id' => $userId]);
$row = $stmt->fetch();

json_ok([
    'accessToken' => $access,
    'refreshToken' => $refresh['raw'],
    'user' => [
        'id'       => $row['id'],
        'email'    => $row['email'],
        'name'     => $row['name'],
        'photoURL' => $row['photo_url'],
        'provider' => $row['provider'],
    ],
]);
