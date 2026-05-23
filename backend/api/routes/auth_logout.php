<?php
declare(strict_types=1);

// We don't strictly need the raw refresh token here — invalidating all of the
// user's refresh tokens is the safe thing to do.
$pdo = db();
$pdo->prepare('UPDATE refresh_tokens SET revoked_at = :n WHERE user_id = :u AND revoked_at IS NULL')
    ->execute([':n' => db_now(), ':u' => current_user()['id']]);

json_ok(['status' => 'logged_out']);
