<?php
declare(strict_types=1);

$u = current_user();
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'PATCH') {
    $body = read_json_body();
    if (!array_key_exists('name', $body)) {
        throw new HttpException(400, 'Missing field: name');
    }

    $name = trim((string)($body['name'] ?? ''));
    if (strlen($name) > 255) {
        throw new HttpException(400, 'Name must be 255 characters or fewer.');
    }
    $name = $name === '' ? null : $name;

    $pdo = db();
    $pdo->prepare('UPDATE users SET name = :n, updated_at = :u WHERE id = :id')
        ->execute([':n' => $name, ':u' => db_now(), ':id' => $u['id']]);

    $stmt = $pdo->prepare('SELECT id, email, name, photo_url, provider FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $u['id']]);
    $u = $stmt->fetch();
}

if ($method !== 'GET' && $method !== 'PATCH') {
    json_error(405, 'Method not allowed.');
}

json_ok([
    'id'       => $u['id'],
    'email'    => $u['email'],
    'name'     => $u['name'],
    'photoURL' => $u['photo_url'],
    'provider' => $u['provider'],
]);
