<?php
declare(strict_types=1);

$user = current_user();
$pdo = db();
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $stmt = $pdo->prepare('SELECT daily_calorie_goal, show_calorie_range, has_completed_onboarding FROM user_settings WHERE user_id = :u LIMIT 1');
    $stmt->execute([':u' => $user['id']]);
    $row = $stmt->fetch();
    if (!$row) {
        json_ok([
            'dailyCalorieGoal'       => 2000,
            'showCalorieRange'       => true,
            'hasCompletedOnboarding' => false,
        ]);
    }
    json_ok([
        'dailyCalorieGoal'       => (int)$row['daily_calorie_goal'],
        'showCalorieRange'       => (bool)$row['show_calorie_range'],
        'hasCompletedOnboarding' => (bool)$row['has_completed_onboarding'],
    ]);
}

if ($method === 'POST') {
    $body = read_json_body();
    $pdo->prepare('INSERT INTO user_settings (user_id, daily_calorie_goal, show_calorie_range, has_completed_onboarding, updated_at)
                   VALUES (:u, :g, :r, :o, :n)
                   ON DUPLICATE KEY UPDATE
                       daily_calorie_goal = :g, show_calorie_range = :r, has_completed_onboarding = :o, updated_at = :n')
        ->execute([
            ':u' => $user['id'],
            ':g' => (int)($body['dailyCalorieGoal'] ?? 2000),
            ':r' => !empty($body['showCalorieRange']) ? 1 : 0,
            ':o' => !empty($body['hasCompletedOnboarding']) ? 1 : 0,
            ':n' => db_now(),
        ]);
    json_ok(['status' => 'ok']);
}

json_error(405, 'Method not allowed.');
