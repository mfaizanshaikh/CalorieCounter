<?php
declare(strict_types=1);

$user = current_user();
$pdo = db();
$since = $_GET['since'] ?? null;
$sinceDt = $since ? iso_to_mysql($since) : '1970-01-01 00:00:00';

// Meals (including soft-deleted, since the client needs to know to remove them).
$mealStmt = $pdo->prepare(
    'SELECT id, date, meal_type, total_min, total_max, total_avg, photo_id, assumptions, updated_at, deleted_at
     FROM meals
     WHERE user_id = :u AND updated_at > :s
     ORDER BY updated_at ASC
     LIMIT 500'
);
$mealStmt->execute([':u' => $user['id'], ':s' => $sinceDt]);
$meals = [];
foreach ($mealStmt as $r) {
    $foodStmt = $pdo->prepare(
        'SELECT id, name, portion_size, cal_min, cal_max, cal_avg, confidence,
                protein, carbs, fat, fiber, sugar, saturated_fat, trans_fat, cholesterol, sodium, potassium,
                updated_at, deleted_at
         FROM food_items WHERE meal_id = :m'
    );
    $foodStmt->execute([':m' => $r['id']]);
    $items = [];
    foreach ($foodStmt as $fr) {
        $items[] = [
            'id'           => $fr['id'],
            'name'         => $fr['name'],
            'portionSize'  => $fr['portion_size'] ?? '',
            'calMin'       => (int)$fr['cal_min'],
            'calMax'       => (int)$fr['cal_max'],
            'calAvg'       => (int)$fr['cal_avg'],
            'confidence'   => (float)$fr['confidence'],
            'protein'      => $fr['protein']      !== null ? (float)$fr['protein']      : null,
            'carbs'        => $fr['carbs']        !== null ? (float)$fr['carbs']        : null,
            'fat'          => $fr['fat']          !== null ? (float)$fr['fat']          : null,
            'fiber'        => $fr['fiber']        !== null ? (float)$fr['fiber']        : null,
            'sugar'        => $fr['sugar']        !== null ? (float)$fr['sugar']        : null,
            'saturatedFat' => $fr['saturated_fat']!== null ? (float)$fr['saturated_fat']: null,
            'transFat'     => $fr['trans_fat']    !== null ? (float)$fr['trans_fat']    : null,
            'cholesterol'  => $fr['cholesterol']  !== null ? (float)$fr['cholesterol']  : null,
            'sodium'       => $fr['sodium']       !== null ? (float)$fr['sodium']       : null,
            'potassium'    => $fr['potassium']    !== null ? (float)$fr['potassium']    : null,
            'updatedAt'    => mysql_to_iso($fr['updated_at']),
            'deletedAt'    => mysql_to_iso($fr['deleted_at']),
        ];
    }
    $meals[] = [
        'id'          => $r['id'],
        'date'        => mysql_to_iso($r['date']),
        'mealType'    => $r['meal_type'],
        'totalMin'    => (int)$r['total_min'],
        'totalMax'    => (int)$r['total_max'],
        'totalAvg'    => (int)$r['total_avg'],
        'photoId'     => $r['photo_id'],
        'assumptions' => $r['assumptions'] ? json_decode($r['assumptions'], true) : [],
        'foodItems'   => $items,
        'updatedAt'   => mysql_to_iso($r['updated_at']),
        'deletedAt'   => mysql_to_iso($r['deleted_at']),
    ];
}

// Saved foods.
$sfStmt = $pdo->prepare(
    'SELECT id, name, cal_per_100g, protein, carbs, fat, fiber, sodium,
            default_serving_g, default_serving_label, search_count, is_from_ai,
            date_added, updated_at, deleted_at
     FROM saved_foods
     WHERE user_id = :u AND updated_at > :s
     ORDER BY updated_at ASC
     LIMIT 1000'
);
$sfStmt->execute([':u' => $user['id'], ':s' => $sinceDt]);
$savedFoods = [];
foreach ($sfStmt as $r) {
    $savedFoods[] = [
        'id'                  => $r['id'],
        'name'                => $r['name'],
        'calPer100g'          => (float)$r['cal_per_100g'],
        'protein'             => $r['protein']  !== null ? (float)$r['protein']  : null,
        'carbs'               => $r['carbs']    !== null ? (float)$r['carbs']    : null,
        'fat'                 => $r['fat']      !== null ? (float)$r['fat']      : null,
        'fiber'               => $r['fiber']    !== null ? (float)$r['fiber']    : null,
        'sodium'              => $r['sodium']   !== null ? (float)$r['sodium']   : null,
        'defaultServingG'     => (float)$r['default_serving_g'],
        'defaultServingLabel' => $r['default_serving_label'],
        'searchCount'         => (int)$r['search_count'],
        'isFromAI'            => (bool)$r['is_from_ai'],
        'dateAdded'           => mysql_to_iso($r['date_added']),
        'updatedAt'           => mysql_to_iso($r['updated_at']),
        'deletedAt'           => mysql_to_iso($r['deleted_at']),
    ];
}

// Settings (singleton).
$setStmt = $pdo->prepare('SELECT daily_calorie_goal, show_calorie_range, has_completed_onboarding, updated_at FROM user_settings WHERE user_id = :u LIMIT 1');
$setStmt->execute([':u' => $user['id']]);
$srow = $setStmt->fetch();
$settings = null;
if ($srow && strtotime($srow['updated_at']) > strtotime($sinceDt)) {
    $settings = [
        'dailyCalorieGoal'       => (int)$srow['daily_calorie_goal'],
        'showCalorieRange'       => (bool)$srow['show_calorie_range'],
        'hasCompletedOnboarding' => (bool)$srow['has_completed_onboarding'],
    ];
}

json_ok([
    'meals'      => $meals,
    'savedFoods' => $savedFoods,
    'settings'   => $settings,
    'serverTime' => mysql_to_iso(db_now()),
]);
