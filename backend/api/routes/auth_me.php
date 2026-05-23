<?php
declare(strict_types=1);

$u = current_user();
json_ok([
    'id'       => $u['id'],
    'email'    => $u['email'],
    'name'     => $u['name'],
    'photoURL' => $u['photo_url'],
    'provider' => $u['provider'],
]);
