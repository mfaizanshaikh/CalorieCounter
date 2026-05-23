<?php
declare(strict_types=1);

$user = current_user();
$method = $_SERVER['REQUEST_METHOD'];
$id = $GLOBALS['route_param_id'] ?? null;
$pdo = db();

if ($method === 'POST') {
    upsert_meal($pdo, $user);
    return;
}
if ($method === 'PATCH' && $id) {
    upsert_meal($pdo, $user, $id);
    return;
}
if ($method === 'DELETE' && $id) {
    delete_meal($pdo, $user, $id);
    return;
}
json_error(405, 'Method not allowed.');

function upsert_meal(PDO $pdo, array $user, ?string $forceId = null): void {
    $body = read_json_body();
    $id = $forceId ?: (string)require_field($body, 'id');
    if (!uuid_valid($id)) json_error(400, 'Invalid meal id.');

    $date    = iso_to_mysql((string)require_field($body, 'date'));
    $mealType = (string)require_field($body, 'mealType');
    $totalMin = (int)($body['totalMin'] ?? 0);
    $totalMax = (int)($body['totalMax'] ?? 0);
    $totalAvg = (int)($body['totalAvg'] ?? 0);
    $assumptions = $body['assumptions'] ?? [];
    $photoId = $body['photoId'] ?? null;
    if ($photoId !== null && !uuid_valid($photoId)) json_error(400, 'Invalid photo id.');
    $updatedAt = iso_to_mysql($body['updatedAt'] ?? null) ?? db_now();
    $deletedAt = iso_to_mysql($body['deletedAt'] ?? null);

    $foodItems = $body['foodItems'] ?? [];
    if (!is_array($foodItems)) json_error(400, 'foodItems must be an array.');

    $pdo->beginTransaction();
    try {
        // Verify ownership if the meal already exists.
        $stmt = $pdo->prepare('SELECT user_id FROM meals WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        $existing = $stmt->fetch();
        if ($existing && $existing['user_id'] !== $user['id']) {
            $pdo->rollBack();
            json_error(403, 'Forbidden.');
        }

        $sql = 'INSERT INTO meals
                (id, user_id, date, meal_type, total_min, total_max, total_avg, photo_id, assumptions, updated_at, deleted_at)
                VALUES (:id, :u, :d, :mt, :mn, :mx, :avg, :p, :a, :ua, :da)
                ON DUPLICATE KEY UPDATE
                    date = :d, meal_type = :mt,
                    total_min = :mn, total_max = :mx, total_avg = :avg,
                    photo_id = :p, assumptions = :a, updated_at = :ua, deleted_at = :da';
        $pdo->prepare($sql)->execute([
            ':id' => $id, ':u' => $user['id'], ':d' => $date, ':mt' => $mealType,
            ':mn' => $totalMin, ':mx' => $totalMax, ':avg' => $totalAvg,
            ':p' => $photoId, ':a' => json_encode($assumptions, JSON_UNESCAPED_UNICODE),
            ':ua' => $updatedAt, ':da' => $deletedAt,
        ]);

        // Replace food items.
        $pdo->prepare('DELETE FROM food_items WHERE meal_id = :m')->execute([':m' => $id]);
        if (!empty($foodItems)) {
            $ins = $pdo->prepare(
                'INSERT INTO food_items (id, meal_id, name, portion_size, cal_min, cal_max, cal_avg, confidence,
                    protein, carbs, fat, fiber, sugar, saturated_fat, trans_fat, cholesterol, sodium, potassium,
                    updated_at, deleted_at)
                VALUES (:id, :m, :n, :ps, :cn, :cx, :ca, :cf,
                    :pr, :cr, :ft, :fb, :sg, :sf, :tf, :ch, :so, :po,
                    :ua, :da)'
            );
            foreach ($foodItems as $f) {
                $fid = (string)($f['id'] ?? uuid_v4());
                if (!uuid_valid($fid)) continue;
                $ins->execute([
                    ':id' => $fid, ':m' => $id,
                    ':n'  => (string)($f['name'] ?? ''),
                    ':ps' => $f['portionSize'] ?? null,
                    ':cn' => (int)($f['calMin'] ?? 0),
                    ':cx' => (int)($f['calMax'] ?? 0),
                    ':ca' => (int)($f['calAvg'] ?? 0),
                    ':cf' => (float)($f['confidence'] ?? 0),
                    ':pr' => $f['protein']      ?? null,
                    ':cr' => $f['carbs']        ?? null,
                    ':ft' => $f['fat']          ?? null,
                    ':fb' => $f['fiber']        ?? null,
                    ':sg' => $f['sugar']        ?? null,
                    ':sf' => $f['saturatedFat'] ?? null,
                    ':tf' => $f['transFat']     ?? null,
                    ':ch' => $f['cholesterol']  ?? null,
                    ':so' => $f['sodium']       ?? null,
                    ':po' => $f['potassium']    ?? null,
                    ':ua' => iso_to_mysql($f['updatedAt'] ?? null) ?? db_now(),
                    ':da' => iso_to_mysql($f['deletedAt'] ?? null),
                ]);
            }
        }
        $pdo->commit();
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
    json_ok(['status' => 'ok', 'id' => $id]);
}

function delete_meal(PDO $pdo, array $user, string $id): void {
    $pdo->beginTransaction();
    try {
        // Soft-delete + unlink photo file if any.
        $stmt = $pdo->prepare('SELECT user_id, photo_id FROM meals WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        $row = $stmt->fetch();
        if (!$row) { $pdo->rollBack(); json_ok(['status' => 'already_gone']); }
        if ($row['user_id'] !== $user['id']) { $pdo->rollBack(); json_error(403, 'Forbidden.'); }
        if ($row['photo_id']) {
            global $CONFIG;
            photo_delete($CONFIG, $user['id'], $row['photo_id']);
        }
        $pdo->prepare('UPDATE meals SET deleted_at = :n, updated_at = :n WHERE id = :id')
            ->execute([':n' => db_now(), ':id' => $id]);
        $pdo->commit();
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
    json_ok(['status' => 'deleted']);
}
