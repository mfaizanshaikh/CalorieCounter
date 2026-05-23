<?php
declare(strict_types=1);

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

/** Issue a short-lived app access JWT (HS256). */
function jwt_issue_access(string $userId, string $secret, int $ttlSeconds): string {
    $now = time();
    $payload = [
        'iss' => 'aicaloriecoach',
        'sub' => $userId,
        'iat' => $now,
        'exp' => $now + $ttlSeconds,
        'jti' => bin2hex(random_bytes(8)),
    ];
    return JWT::encode($payload, $secret, 'HS256');
}

/** Verify the app access JWT and return the user id (sub claim). */
function jwt_verify_access(string $token, string $secret): string {
    try {
        $decoded = JWT::decode($token, new Key($secret, 'HS256'));
    } catch (Throwable $e) {
        throw new HttpException(401, 'Invalid or expired access token.');
    }
    $sub = $decoded->sub ?? '';
    if (!is_string($sub) || !uuid_valid($sub)) {
        throw new HttpException(401, 'Invalid token payload.');
    }
    return $sub;
}

/** Generate an opaque refresh token + its SHA-256 hash for DB storage. */
function refresh_token_create(): array {
    $raw = bin2hex(random_bytes(32));
    $hash = hash('sha256', $raw);
    return ['raw' => $raw, 'hash' => $hash];
}

function refresh_token_hash(string $raw): string {
    return hash('sha256', $raw);
}

/** v4 UUID. */
function uuid_v4(): string {
    $data = random_bytes(16);
    $data[6] = chr(ord($data[6]) & 0x0f | 0x40);
    $data[8] = chr(ord($data[8]) & 0x3f | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}
