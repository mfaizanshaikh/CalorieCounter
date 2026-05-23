<?php
declare(strict_types=1);

$body = read_json_body();
$raw = require_field($body, 'refreshToken');
$hash = refresh_token_hash($raw);

$pdo = db();
$stmt = $pdo->prepare('SELECT user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = :h LIMIT 1');
$stmt->execute([':h' => $hash]);
$row = $stmt->fetch();
if (!$row) {
    json_error(401, 'Unknown refresh token.');
}
if ($row['revoked_at'] !== null || strtotime($row['expires_at']) < time()) {
    json_error(401, 'Refresh token expired or revoked.');
}

// Rotate: revoke the old, issue a new pair.
$now = db_now();
$pdo->prepare('UPDATE refresh_tokens SET revoked_at = :n WHERE token_hash = :h')
    ->execute([':n' => $now, ':h' => $hash]);

$newRefresh = refresh_token_create();
$expiresAt = gmdate('Y-m-d H:i:s', time() + $CONFIG['refresh_token_ttl_seconds']);
$pdo->prepare('INSERT INTO refresh_tokens (token_hash, user_id, issued_at, expires_at) VALUES (:h, :u, :i, :e)')
    ->execute([':h' => $newRefresh['hash'], ':u' => $row['user_id'], ':i' => $now, ':e' => $expiresAt]);

$access = jwt_issue_access($row['user_id'], $CONFIG['jwt_secret'], $CONFIG['access_token_ttl_seconds']);

json_ok([
    'accessToken'  => $access,
    'refreshToken' => $newRefresh['raw'],
]);
