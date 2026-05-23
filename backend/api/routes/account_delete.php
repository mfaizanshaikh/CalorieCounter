<?php
declare(strict_types=1);

$user = current_user();
$pdo = db();

$pdo->beginTransaction();
try {
    // Wipe photos from disk first.
    photo_user_wipe($CONFIG, $user['id']);
    // Revoke all refresh tokens.
    $pdo->prepare('UPDATE refresh_tokens SET revoked_at = :n WHERE user_id = :u')
        ->execute([':n' => db_now(), ':u' => $user['id']]);
    // The schema cascades on user delete, so this single DELETE removes:
    //   user_settings, meals, food_items, saved_foods, refresh_tokens.
    $pdo->prepare('DELETE FROM users WHERE id = :id')->execute([':id' => $user['id']]);
    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    throw $e;
}

http_response_code(204);
exit;
