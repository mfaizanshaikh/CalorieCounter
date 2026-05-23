<?php
declare(strict_types=1);

// First-sign-in bulk migration. The client sends a single multipart request:
//   - meta: JSON {meals: [...], savedFoods: [...], settings: {...}, photos: {mealId: photoTmpName, ...}}
//   - <name=photo_<mealId>>: a JPEG file per meal that has an imageData blob locally
//
// In this minimal implementation we accept the JSON meta and any photos with
// the name pattern "photo_<mealUuid>". On success we return a map mealId →
// photoId so the client can store the remote photoId.

$user = current_user();
$pdo = db();

$metaRaw = $_POST['meta'] ?? null;
if (!$metaRaw) json_error(400, 'Missing meta part.');
$meta = json_decode($metaRaw, true);
if (!is_array($meta)) json_error(400, 'meta is not valid JSON.');

$photoMap = []; // mealId => photoId

$pdo->beginTransaction();
try {
    foreach ($meta['meals'] ?? [] as $m) {
        $id = (string)($m['id'] ?? '');
        if (!uuid_valid($id)) continue;

        $photoId = null;
        $upload = $_FILES['photo_' . $id] ?? null;
        if ($upload && is_uploaded_file($upload['tmp_name'])) {
            $photoId = photo_save_upload($CONFIG, $user['id'], $upload);
            $photoMap[$id] = $photoId;
        }

        $pdo->prepare(
            'INSERT INTO meals (id, user_id, date, meal_type, total_min, total_max, total_avg, photo_id, assumptions, updated_at, deleted_at)
             VALUES (:id, :u, :d, :mt, :mn, :mx, :avg, :p, :a, :ua, NULL)
             ON DUPLICATE KEY UPDATE
                 date = :d, meal_type = :mt, total_min = :mn, total_max = :mx, total_avg = :avg,
                 photo_id = COALESCE(:p, photo_id), assumptions = :a, updated_at = :ua, deleted_at = NULL'
        )->execute([
            ':id' => $id, ':u' => $user['id'],
            ':d'  => iso_to_mysql($m['date'] ?? null) ?? db_now(),
            ':mt' => (string)($m['mealType'] ?? 'snack'),
            ':mn' => (int)($m['totalMin'] ?? 0),
            ':mx' => (int)($m['totalMax'] ?? 0),
            ':avg'=> (int)($m['totalAvg'] ?? 0),
            ':p'  => $photoId,
            ':a'  => json_encode($m['assumptions'] ?? [], JSON_UNESCAPED_UNICODE),
            ':ua' => iso_to_mysql($m['updatedAt'] ?? null) ?? db_now(),
        ]);

        $pdo->prepare('DELETE FROM food_items WHERE meal_id = :m')->execute([':m' => $id]);
        foreach ($m['foodItems'] ?? [] as $f) {
            $fid = (string)($f['id'] ?? uuid_v4());
            if (!uuid_valid($fid)) continue;
            $pdo->prepare(
                'INSERT INTO food_items (id, meal_id, name, portion_size, cal_min, cal_max, cal_avg, confidence,
                    protein, carbs, fat, fiber, sugar, saturated_fat, trans_fat, cholesterol, sodium, potassium,
                    updated_at)
                 VALUES (:id, :m, :n, :ps, :cn, :cx, :ca, :cf,
                    :pr, :cr, :ft, :fb, :sg, :sf, :tf, :ch, :so, :po, :ua)'
            )->execute([
                ':id' => $fid, ':m' => $id,
                ':n' => (string)($f['name'] ?? ''), ':ps' => $f['portionSize'] ?? null,
                ':cn' => (int)($f['calMin'] ?? 0), ':cx' => (int)($f['calMax'] ?? 0), ':ca' => (int)($f['calAvg'] ?? 0),
                ':cf' => (float)($f['confidence'] ?? 0),
                ':pr' => $f['protein']      ?? null, ':cr' => $f['carbs']        ?? null,
                ':ft' => $f['fat']          ?? null, ':fb' => $f['fiber']        ?? null,
                ':sg' => $f['sugar']        ?? null, ':sf' => $f['saturatedFat'] ?? null,
                ':tf' => $f['transFat']     ?? null, ':ch' => $f['cholesterol']  ?? null,
                ':so' => $f['sodium']       ?? null, ':po' => $f['potassium']    ?? null,
                ':ua' => iso_to_mysql($f['updatedAt'] ?? null) ?? db_now(),
            ]);
        }
    }

    foreach ($meta['savedFoods'] ?? [] as $f) {
        $id = (string)($f['id'] ?? '');
        if (!uuid_valid($id)) continue;
        $pdo->prepare(
            'INSERT INTO saved_foods (id, user_id, name, cal_per_100g, protein, carbs, fat, fiber, sodium,
                default_serving_g, default_serving_label, search_count, is_from_ai, date_added, updated_at)
             VALUES (:id, :u, :n, :c, :p, :ca, :ft, :fb, :s, :dg, :dl, :sc, :ai, :da, :ua)
             ON DUPLICATE KEY UPDATE
                 name = :n, cal_per_100g = :c, updated_at = :ua'
        )->execute([
            ':id' => $id, ':u' => $user['id'],
            ':n' => (string)($f['name'] ?? ''), ':c' => (float)($f['calPer100g'] ?? 0),
            ':p' => $f['protein'] ?? null, ':ca' => $f['carbs'] ?? null,
            ':ft'=> $f['fat']     ?? null, ':fb' => $f['fiber'] ?? null,
            ':s' => $f['sodium']  ?? null,
            ':dg'=> (float)($f['defaultServingG'] ?? 100), ':dl' => (string)($f['defaultServingLabel'] ?? '100 g'),
            ':sc'=> (int)($f['searchCount'] ?? 0), ':ai' => !empty($f['isFromAI']) ? 1 : 0,
            ':da'=> iso_to_mysql($f['dateAdded'] ?? null) ?? db_now(),
            ':ua'=> iso_to_mysql($f['updatedAt'] ?? null) ?? db_now(),
        ]);
    }

    if (!empty($meta['settings'])) {
        $s = $meta['settings'];
        $pdo->prepare(
            'INSERT INTO user_settings (user_id, daily_calorie_goal, show_calorie_range, has_completed_onboarding, updated_at)
             VALUES (:u, :g, :r, :o, :n)
             ON DUPLICATE KEY UPDATE
                 daily_calorie_goal = :g, show_calorie_range = :r, has_completed_onboarding = :o, updated_at = :n'
        )->execute([
            ':u' => $user['id'],
            ':g' => (int)($s['dailyCalorieGoal'] ?? 2000),
            ':r' => !empty($s['showCalorieRange']) ? 1 : 0,
            ':o' => !empty($s['hasCompletedOnboarding']) ? 1 : 0,
            ':n' => db_now(),
        ]);
    }

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    throw $e;
}

json_ok(['status' => 'ok', 'photoMap' => $photoMap]);
