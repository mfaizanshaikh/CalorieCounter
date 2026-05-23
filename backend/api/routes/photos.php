<?php
declare(strict_types=1);

$user = current_user();
$method = $_SERVER['REQUEST_METHOD'];
$id = $GLOBALS['route_param_id'] ?? null;
$pdo = db();

if ($method === 'POST') {
    if (empty($_FILES['photo'])) json_error(400, 'Missing photo file.');
    $photoId = photo_save_upload($CONFIG, $user['id'], $_FILES['photo']);
    // The meal upsert is responsible for setting photo_id on the meals row.
    json_ok(['id' => $photoId]);
}

if ($method === 'GET' && $id) {
    $stmt = $pdo->prepare('SELECT id, user_id FROM meals WHERE photo_id = :p LIMIT 1');
    $stmt->execute([':p' => $id]);
    $row = $stmt->fetch();
    if (!$row || $row['user_id'] !== $user['id']) json_error(404, 'Photo not found.');

    $path = photo_path($CONFIG, $user['id'], $id);
    if (!file_exists($path)) json_error(404, 'Photo file missing.');

    header('Content-Type: image/jpeg');
    header('Cache-Control: private, max-age=3600');
    header('Content-Length: ' . filesize($path));
    readfile($path);
    exit;
}

if ($method === 'DELETE' && $id) {
    $pdo->prepare('DELETE FROM public_wall_posts WHERE photo_id = :p AND user_id = :u')
        ->execute([':p' => $id, ':u' => $user['id']]);
    photo_delete($CONFIG, $user['id'], $id);
    $pdo->prepare('UPDATE meals SET photo_id = NULL, updated_at = :n WHERE photo_id = :p AND user_id = :u')
        ->execute([':n' => db_now(), ':p' => $id, ':u' => $user['id']]);
    json_ok(['status' => 'deleted']);
}

json_error(405, 'Method not allowed.');
