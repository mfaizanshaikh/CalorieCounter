<?php
declare(strict_types=1);

$user = current_user();
$method = $_SERVER['REQUEST_METHOD'];
$id = $GLOBALS['route_param_id'] ?? null;
$pdo = db();

if ($method === 'POST') {
    upsert_saved_food($pdo, $user);
    return;
}
if ($method === 'PATCH' && $id) {
    upsert_saved_food($pdo, $user, $id);
    return;
}
if ($method === 'DELETE' && $id) {
    $stmt = $pdo->prepare('SELECT user_id FROM saved_foods WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch();
    if (!$row) { json_ok(['status' => 'already_gone']); return; }
    if ($row['user_id'] !== $user['id']) json_error(403, 'Forbidden.');
    $pdo->prepare('UPDATE saved_foods SET deleted_at = :n, updated_at = :n WHERE id = :id')
        ->execute([':n' => db_now(), ':id' => $id]);
    json_ok(['status' => 'deleted']);
    return;
}
json_error(405, 'Method not allowed.');

function upsert_saved_food(PDO $pdo, array $user, ?string $forceId = null): void {
    $body = read_json_body();
    $id = $forceId ?: (string)require_field($body, 'id');
    if (!uuid_valid($id)) json_error(400, 'Invalid saved food id.');

    $name = (string)require_field($body, 'name');
    $cal  = (float)require_field($body, 'calPer100g');

    $stmt = $pdo->prepare('SELECT user_id FROM saved_foods WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $id]);
    $existing = $stmt->fetch();
    if ($existing && $existing['user_id'] !== $user['id']) json_error(403, 'Forbidden.');

    $sql = 'INSERT INTO saved_foods
            (id, user_id, name, cal_per_100g, protein, carbs, fat, fiber, sodium,
             default_serving_g, default_serving_label, search_count, is_from_ai,
             date_added, updated_at, deleted_at)
            VALUES (:id, :u, :n, :cal, :p, :c, :f, :fb, :s, :dg, :dl, :sc, :ai, :da, :ua, :del)
            ON DUPLICATE KEY UPDATE
                name = :n, cal_per_100g = :cal, protein = :p, carbs = :c, fat = :f,
                fiber = :fb, sodium = :s, default_serving_g = :dg, default_serving_label = :dl,
                search_count = :sc, is_from_ai = :ai, updated_at = :ua, deleted_at = :del';
    $pdo->prepare($sql)->execute([
        ':id' => $id, ':u' => $user['id'], ':n' => $name, ':cal' => $cal,
        ':p'  => $body['protein']  ?? null,
        ':c'  => $body['carbs']    ?? null,
        ':f'  => $body['fat']      ?? null,
        ':fb' => $body['fiber']    ?? null,
        ':s'  => $body['sodium']   ?? null,
        ':dg' => (float)($body['defaultServingG'] ?? 100),
        ':dl' => (string)($body['defaultServingLabel'] ?? '100 g'),
        ':sc' => (int)($body['searchCount'] ?? 0),
        ':ai' => !empty($body['isFromAI']) ? 1 : 0,
        ':da' => iso_to_mysql($body['dateAdded'] ?? null) ?? db_now(),
        ':ua' => iso_to_mysql($body['updatedAt'] ?? null) ?? db_now(),
        ':del'=> iso_to_mysql($body['deletedAt'] ?? null),
    ]);
    json_ok(['status' => 'ok', 'id' => $id]);
}
