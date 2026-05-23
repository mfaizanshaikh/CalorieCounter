<?php
declare(strict_types=1);

$user = current_user();
$method = $_SERVER['REQUEST_METHOD'];
$id = $GLOBALS['route_param_id'] ?? null;
$action = $GLOBALS['route_action'] ?? null;
$pdo = db();

if ($method === 'GET' && !$id) {
    list_wall_posts($pdo, $user);
    return;
}
if ($method === 'POST' && !$id) {
    publish_wall_post($pdo, $user);
    return;
}
if ($method === 'GET' && $id && $action === 'photo') {
    stream_wall_photo($pdo, $user, $id, $CONFIG);
    return;
}
if ($method === 'DELETE' && $id && !$action) {
    delete_wall_post($pdo, $user, $id);
    return;
}
if ($id && $action === 'like') {
    if ($method === 'POST') {
        set_wall_like($pdo, $user, $id, true);
        return;
    }
    if ($method === 'DELETE') {
        set_wall_like($pdo, $user, $id, false);
        return;
    }
}
if ($id && $action === 'save') {
    if ($method === 'POST') {
        set_wall_save($pdo, $user, $id, true);
        return;
    }
    if ($method === 'DELETE') {
        set_wall_save($pdo, $user, $id, false);
        return;
    }
}
if ($method === 'POST' && $id && $action === 'report') {
    report_wall_post($pdo, $user, $id);
    return;
}
if ($method === 'POST' && $id && $action === 'block') {
    block_wall_user($pdo, $user, $id);
    return;
}

json_error(405, 'Method not allowed.');

function list_wall_posts(PDO $pdo, array $user): void {
    $sort = strtolower((string)($_GET['sort'] ?? 'recent'));
    if (!in_array($sort, ['recent', 'trending'], true)) {
        json_error(400, 'Invalid sort.');
    }
    $limit = max(1, min(50, (int)($_GET['limit'] ?? 30)));
    $order = $sort === 'trending'
        ? 'recent_score DESC, p.posted_at DESC'
        : 'p.posted_at DESC';

    $sql = wall_post_select_sql(
        "p.status = 'active'
         AND p.deleted_at IS NULL
         AND u.deleted_at IS NULL
         AND NOT EXISTS (
             SELECT 1 FROM wall_user_blocks b
             WHERE b.blocker_user_id = :viewer_blocker AND b.blocked_user_id = p.user_id
         )
         AND NOT EXISTS (
             SELECT 1 FROM wall_user_blocks b
             WHERE b.blocker_user_id = p.user_id AND b.blocked_user_id = :viewer_blocked
         )
         AND NOT EXISTS (
             SELECT 1 FROM wall_post_reports r
             WHERE r.post_id = p.id AND r.reporter_user_id = :viewer_reporter
         )",
        $order,
        $limit
    );
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':viewer' => $user['id'],
        ':viewer_blocker' => $user['id'],
        ':viewer_blocked' => $user['id'],
        ':viewer_reporter' => $user['id'],
    ]);

    $posts = [];
    foreach ($stmt as $row) {
        $posts[] = wall_post_payload($row, $user['id']);
    }

    json_ok(['posts' => $posts]);
}

function publish_wall_post(PDO $pdo, array $user): void {
    $body = read_json_body();
    $mealId = (string)require_field($body, 'mealId');
    if (!uuid_valid($mealId)) json_error(400, 'Invalid meal id.');

    $existingStmt = $pdo->prepare(
        'SELECT id, status FROM public_wall_posts
         WHERE user_id = :u AND meal_id = :m
         LIMIT 1'
    );
    $existingStmt->execute([':u' => $user['id'], ':m' => $mealId]);
    $existing = $existingStmt->fetch();
    if ($existing) {
        if ($existing['status'] !== 'active') {
            json_error(409, 'This meal is not eligible to be reposted.');
        }
        $post = fetch_wall_post($pdo, $existing['id'], $user['id']);
        json_ok(['post' => $post]);
    }

    $mealStmt = $pdo->prepare(
        'SELECT id, user_id, meal_type, total_min, total_max, total_avg, photo_id
         FROM meals
         WHERE id = :id AND user_id = :u AND deleted_at IS NULL
         LIMIT 1'
    );
    $mealStmt->execute([':id' => $mealId, ':u' => $user['id']]);
    $meal = $mealStmt->fetch();
    if (!$meal) json_error(404, 'Meal not found.');
    if (empty($meal['photo_id'])) json_error(400, 'Only meals with photos can be posted to the wall.');
    if ((int)$meal['total_avg'] <= 0 || (int)$meal['total_min'] < 0 || (int)$meal['total_max'] < 0) {
        json_error(400, 'Invalid meal nutrition.');
    }

    $foodStmt = $pdo->prepare(
        'SELECT name, protein, carbs, fat
         FROM food_items
         WHERE meal_id = :m AND deleted_at IS NULL
         ORDER BY name ASC'
    );
    $foodStmt->execute([':m' => $mealId]);
    $foodNames = [];
    $protein = 0.0;
    $carbs = 0.0;
    $fat = 0.0;
    $hasProtein = false;
    $hasCarbs = false;
    $hasFat = false;

    foreach ($foodStmt as $food) {
        $name = trim((string)$food['name']);
        if ($name === '') continue;
        if (wall_text_has_blocked_term($name)) {
            json_error(400, 'Food names contain text that cannot be posted.');
        }
        $foodNames[] = substr($name, 0, 80);
        if ($food['protein'] !== null) { $protein += (float)$food['protein']; $hasProtein = true; }
        if ($food['carbs'] !== null) { $carbs += (float)$food['carbs']; $hasCarbs = true; }
        if ($food['fat'] !== null) { $fat += (float)$food['fat']; $hasFat = true; }
    }

    if (empty($foodNames)) json_error(400, 'A wall post must include at least one food item.');
    $foodNames = array_slice(array_values(array_unique($foodNames)), 0, 8);

    $postId = uuid_v4();
    $now = db_now();
    $pdo->prepare(
        'INSERT INTO public_wall_posts
            (id, user_id, meal_id, photo_id, meal_type, food_names, total_min, total_max, total_avg,
             protein, carbs, fat, status, posted_at, updated_at)
         VALUES
            (:id, :u, :m, :p, :mt, :foods, :min, :max, :avg, :protein, :carbs, :fat, "active", :now, :now)'
    )->execute([
        ':id' => $postId,
        ':u' => $user['id'],
        ':m' => $mealId,
        ':p' => $meal['photo_id'],
        ':mt' => $meal['meal_type'],
        ':foods' => json_encode($foodNames, JSON_UNESCAPED_UNICODE),
        ':min' => (int)$meal['total_min'],
        ':max' => (int)$meal['total_max'],
        ':avg' => (int)$meal['total_avg'],
        ':protein' => $hasProtein ? round($protein, 1) : null,
        ':carbs' => $hasCarbs ? round($carbs, 1) : null,
        ':fat' => $hasFat ? round($fat, 1) : null,
        ':now' => $now,
    ]);

    $post = fetch_wall_post($pdo, $postId, $user['id']);
    json_ok(['post' => $post], 201);
}

function delete_wall_post(PDO $pdo, array $user, string $postId): void {
    if (!uuid_valid($postId)) json_error(400, 'Invalid post id.');

    $stmt = $pdo->prepare('SELECT user_id FROM public_wall_posts WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $postId]);
    $post = $stmt->fetch();
    if (!$post) json_ok(['status' => 'already_gone']);
    if ($post['user_id'] !== $user['id']) json_error(403, 'Forbidden.');

    $pdo->prepare('DELETE FROM public_wall_posts WHERE id = :id AND user_id = :u')
        ->execute([':id' => $postId, ':u' => $user['id']]);
    json_ok(['status' => 'deleted']);
}

function set_wall_like(PDO $pdo, array $user, string $postId, bool $liked): void {
    wall_require_visible_post($pdo, $postId, $user['id']);
    if ($liked) {
        $pdo->prepare('INSERT IGNORE INTO wall_post_likes (post_id, user_id, created_at) VALUES (:p, :u, :n)')
            ->execute([':p' => $postId, ':u' => $user['id'], ':n' => db_now()]);
    } else {
        $pdo->prepare('DELETE FROM wall_post_likes WHERE post_id = :p AND user_id = :u')
            ->execute([':p' => $postId, ':u' => $user['id']]);
    }
    json_ok(['state' => wall_action_state($pdo, $postId, $user['id'])]);
}

function set_wall_save(PDO $pdo, array $user, string $postId, bool $saved): void {
    wall_require_visible_post($pdo, $postId, $user['id']);
    if ($saved) {
        $pdo->prepare('INSERT IGNORE INTO wall_post_saves (post_id, user_id, created_at) VALUES (:p, :u, :n)')
            ->execute([':p' => $postId, ':u' => $user['id'], ':n' => db_now()]);
    } else {
        $pdo->prepare('DELETE FROM wall_post_saves WHERE post_id = :p AND user_id = :u')
            ->execute([':p' => $postId, ':u' => $user['id']]);
    }
    json_ok(['state' => wall_action_state($pdo, $postId, $user['id'])]);
}

function report_wall_post(PDO $pdo, array $user, string $postId): void {
    wall_require_visible_post($pdo, $postId, $user['id']);
    $body = read_json_body();
    $reason = (string)require_field($body, 'reason');
    $allowed = ['offensive_content', 'non_food_image', 'privacy_concern', 'spam', 'other'];
    if (!in_array($reason, $allowed, true)) json_error(400, 'Invalid report reason.');
    $details = trim((string)($body['details'] ?? ''));
    if ($details === '') $details = null;
    if ($details !== null) $details = substr($details, 0, 500);

    $pdo->prepare(
        'INSERT INTO wall_post_reports (id, post_id, reporter_user_id, reason, details, status, created_at)
         VALUES (:id, :p, :u, :r, :d, "open", :n)
         ON DUPLICATE KEY UPDATE reason = :r, details = :d, status = "open", created_at = :n'
    )->execute([
        ':id' => uuid_v4(),
        ':p' => $postId,
        ':u' => $user['id'],
        ':r' => $reason,
        ':d' => $details,
        ':n' => db_now(),
    ]);

    $countStmt = $pdo->prepare('SELECT COUNT(*) AS c FROM wall_post_reports WHERE post_id = :p AND status = "open"');
    $countStmt->execute([':p' => $postId]);
    if ((int)($countStmt->fetch()['c'] ?? 0) >= 3) {
        $pdo->prepare('UPDATE public_wall_posts SET status = "hidden", updated_at = :n WHERE id = :p')
            ->execute([':n' => db_now(), ':p' => $postId]);
    }

    json_ok(['status' => 'reported']);
}

function block_wall_user(PDO $pdo, array $user, string $blockedUserId): void {
    if (!uuid_valid($blockedUserId)) json_error(400, 'Invalid user id.');
    if ($blockedUserId === $user['id']) json_error(400, 'You cannot block yourself.');

    $exists = $pdo->prepare('SELECT id FROM users WHERE id = :id AND deleted_at IS NULL LIMIT 1');
    $exists->execute([':id' => $blockedUserId]);
    if (!$exists->fetch()) json_error(404, 'User not found.');

    $pdo->prepare(
        'INSERT IGNORE INTO wall_user_blocks (blocker_user_id, blocked_user_id, created_at)
         VALUES (:blocker, :blocked, :n)'
    )->execute([
        ':blocker' => $user['id'],
        ':blocked' => $blockedUserId,
        ':n' => db_now(),
    ]);

    json_ok(['status' => 'blocked']);
}

function stream_wall_photo(PDO $pdo, array $user, string $postId, array $config): void {
    $post = wall_require_visible_post($pdo, $postId, $user['id']);
    $path = photo_path($config, $post['user_id'], $post['photo_id']);
    if (!file_exists($path)) json_error(404, 'Photo file missing.');

    header('Content-Type: image/jpeg');
    header('Cache-Control: private, max-age=1800');
    header('Content-Length: ' . filesize($path));
    readfile($path);
    exit;
}

function fetch_wall_post(PDO $pdo, string $postId, string $viewerUserId): array {
    $sql = wall_post_select_sql('p.id = :post_id', 'p.posted_at DESC', 1);
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':viewer' => $viewerUserId, ':post_id' => $postId]);
    $row = $stmt->fetch();
    if (!$row) json_error(404, 'Post not found.');
    return wall_post_payload($row, $viewerUserId);
}

function wall_require_visible_post(PDO $pdo, string $postId, string $viewerUserId): array {
    if (!uuid_valid($postId)) json_error(400, 'Invalid post id.');
    $stmt = $pdo->prepare(
        'SELECT p.id, p.user_id, p.photo_id
         FROM public_wall_posts p
         JOIN users u ON u.id = p.user_id
         WHERE p.id = :p
           AND p.status = "active"
           AND p.deleted_at IS NULL
           AND u.deleted_at IS NULL
           AND NOT EXISTS (
               SELECT 1 FROM wall_user_blocks b
               WHERE b.blocker_user_id = :viewer_blocker AND b.blocked_user_id = p.user_id
           )
           AND NOT EXISTS (
               SELECT 1 FROM wall_user_blocks b
               WHERE b.blocker_user_id = p.user_id AND b.blocked_user_id = :viewer_blocked
           )
           AND NOT EXISTS (
               SELECT 1 FROM wall_post_reports r
               WHERE r.post_id = p.id AND r.reporter_user_id = :viewer_reporter
           )
         LIMIT 1'
    );
    $stmt->execute([
        ':p' => $postId,
        ':viewer_blocker' => $viewerUserId,
        ':viewer_blocked' => $viewerUserId,
        ':viewer_reporter' => $viewerUserId,
    ]);
    $post = $stmt->fetch();
    if (!$post) json_error(404, 'Post not found.');
    return $post;
}

function wall_action_state(PDO $pdo, string $postId, string $viewerUserId): array {
    $stmt = $pdo->prepare(
        'SELECT
            (SELECT COUNT(*) FROM wall_post_likes l WHERE l.post_id = :p_likes) AS like_count,
            (SELECT COUNT(*) FROM wall_post_saves s WHERE s.post_id = :p_saves) AS save_count,
            EXISTS(SELECT 1 FROM wall_post_likes l2 WHERE l2.post_id = :p_liked AND l2.user_id = :viewer_liked) AS is_liked,
            EXISTS(SELECT 1 FROM wall_post_saves s2 WHERE s2.post_id = :p_saved AND s2.user_id = :viewer_saved) AS is_saved'
    );
    $stmt->execute([
        ':p_likes' => $postId,
        ':p_saves' => $postId,
        ':p_liked' => $postId,
        ':viewer_liked' => $viewerUserId,
        ':p_saved' => $postId,
        ':viewer_saved' => $viewerUserId,
    ]);
    $row = $stmt->fetch() ?: [];
    return [
        'likeCount' => (int)($row['like_count'] ?? 0),
        'saveCount' => (int)($row['save_count'] ?? 0),
        'isLiked' => !empty($row['is_liked']),
        'isSaved' => !empty($row['is_saved']),
    ];
}

function wall_post_select_sql(string $where, string $order, int $limit): string {
    return "
        SELECT
            p.id, p.user_id, p.meal_id, p.meal_type, p.food_names,
            p.total_min, p.total_max, p.total_avg, p.protein, p.carbs, p.fat,
            p.status, p.posted_at, u.name,
            (SELECT COUNT(*) FROM wall_post_likes l WHERE l.post_id = p.id) AS like_count,
            (SELECT COUNT(*) FROM wall_post_saves s WHERE s.post_id = p.id) AS save_count,
            EXISTS(SELECT 1 FROM wall_post_likes l2 WHERE l2.post_id = p.id AND l2.user_id = :viewer) AS is_liked,
            EXISTS(SELECT 1 FROM wall_post_saves s2 WHERE s2.post_id = p.id AND s2.user_id = :viewer) AS is_saved,
            (
                (SELECT COUNT(*) FROM wall_post_likes rl WHERE rl.post_id = p.id AND rl.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)) * 3
                +
                (SELECT COUNT(*) FROM wall_post_saves rs WHERE rs.post_id = p.id AND rs.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)) * 2
            ) AS recent_score
        FROM public_wall_posts p
        JOIN users u ON u.id = p.user_id
        WHERE $where
        ORDER BY $order
        LIMIT $limit";
}

function wall_post_payload(array $row, string $viewerUserId): array {
    $foodNames = json_decode((string)$row['food_names'], true);
    if (!is_array($foodNames)) $foodNames = [];

    return [
        'id' => $row['id'],
        'userId' => $row['user_id'],
        'authorFirstName' => wall_first_name($row['name'] ?? null),
        'mealType' => $row['meal_type'],
        'foodNames' => array_values(array_filter($foodNames, 'is_string')),
        'totalCaloriesMin' => (int)$row['total_min'],
        'totalCaloriesMax' => (int)$row['total_max'],
        'totalCaloriesAvg' => (int)$row['total_avg'],
        'protein' => $row['protein'] !== null ? (float)$row['protein'] : null,
        'carbs' => $row['carbs'] !== null ? (float)$row['carbs'] : null,
        'fat' => $row['fat'] !== null ? (float)$row['fat'] : null,
        'postedAt' => mysql_to_iso($row['posted_at']),
        'likeCount' => (int)$row['like_count'],
        'saveCount' => (int)$row['save_count'],
        'isLiked' => !empty($row['is_liked']),
        'isSaved' => !empty($row['is_saved']),
        'isMine' => $row['user_id'] === $viewerUserId,
        'photoPath' => 'wall/posts/' . $row['id'] . '/photo',
    ];
}

function wall_first_name(?string $name): string {
    $source = trim((string)($name ?: ''));
    $source = preg_replace('/\s+/', ' ', trim($source));
    if ($source === '') return 'Someone';
    $parts = explode(' ', $source);
    return substr($parts[0], 0, 40);
}

function wall_text_has_blocked_term(string $text): bool {
    $terms = [
        'fuck', 'shit', 'bitch', 'cunt', 'nigger', 'faggot', 'kike', 'chink',
        'spic', 'rape', 'kill yourself', 'nazi', 'hitler', 'porn', 'sex'
    ];
    foreach ($terms as $term) {
        $pattern = '/(^|[^a-z0-9])' . preg_quote($term, '/') . '([^a-z0-9]|$)/i';
        if (preg_match($pattern, $text)) return true;
    }
    return false;
}
