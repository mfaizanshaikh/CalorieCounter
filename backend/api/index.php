<?php
declare(strict_types=1);

/**
 * AI Calorie Coach — backend front controller.
 *
 * All requests under /api/* land here (see .htaccess). The router below
 * dispatches by method + path to a handler under routes/.
 */

require_once __DIR__ . '/lib/http.php';
require_once __DIR__ . '/lib/db.php';
require_once __DIR__ . '/lib/auth.php';
require_once __DIR__ . '/lib/jwt.php';
require_once __DIR__ . '/lib/photo_storage.php';

if (!file_exists(__DIR__ . '/config.php')) {
    json_error(500, 'Server not configured: copy config.example.php to config.php and fill in values.');
}
$CONFIG = require __DIR__ . '/config.php';

if (!file_exists(__DIR__ . '/vendor/autoload.php')) {
    json_error(500, 'Server dependencies not installed: upload vendor/ from composer install.');
}
require_once __DIR__ . '/vendor/autoload.php';

// Bootstrap singletons.
db_init($CONFIG['db']);

set_error_handler(function ($severity, $message, $file, $line) {
    if (!(error_reporting() & $severity)) return false;
    throw new ErrorException($message, 0, $severity, $file, $line);
});

set_exception_handler(function (Throwable $e) use ($CONFIG) {
    error_log('[api] Uncaught: ' . $e->getMessage() . ' @ ' . $e->getFile() . ':' . $e->getLine());
    $msg = $CONFIG['debug'] ? $e->getMessage() : 'Internal server error.';
    json_error(500, $msg);
});

// Parse path.
$rawUri = $_SERVER['REQUEST_URI'] ?? '/';
$path = parse_url($rawUri, PHP_URL_PATH) ?: '/';
// Strip the script's directory prefix so the router sees just "/health",
// "/auth/login", etc. — works whether the API is mounted at the domain root
// (/api/) or in a subfolder (/whatever/api/).
$scriptDir = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '')), '/');
if ($scriptDir !== '' && $scriptDir !== '/' && str_starts_with($path, $scriptDir)) {
    $path = substr($path, strlen($scriptDir));
}
$path = '/' . trim($path, '/');
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// Route.
try {
    route($method, $path, $CONFIG);
} catch (HttpException $e) {
    json_error($e->status, $e->getMessage());
}

// ---------------------------------------------------------------------------

function route(string $method, string $path, array $CONFIG): void {
    // Public routes (no auth).
    if ($method === 'POST' && $path === '/auth/login')   { require __DIR__ . '/routes/auth_login.php';   return; }
    if ($method === 'POST' && $path === '/auth/refresh') { require __DIR__ . '/routes/auth_refresh.php'; return; }
    if ($method === 'GET'  && $path === '/health')       { json_ok(['status' => 'ok']); return; }

    // All routes below require auth.
    $user = require_auth($CONFIG);

    if ($method === 'GET'  && $path === '/auth/me')       { require __DIR__ . '/routes/auth_me.php';      return; }
    if ($method === 'POST' && $path === '/auth/logout')   { require __DIR__ . '/routes/auth_logout.php';  return; }
    if ($method === 'DELETE' && $path === '/account')     { require __DIR__ . '/routes/account_delete.php'; return; }

    if ($method === 'GET'  && $path === '/sync/state')    { require __DIR__ . '/routes/sync_state.php';   return; }

    if ($method === 'POST' && $path === '/meals')         { require __DIR__ . '/routes/meals.php';        return; }
    if (preg_match('#^/meals/([0-9a-f-]{36})$#', $path, $m)) {
        $GLOBALS['route_param_id'] = $m[1];
        if ($method === 'DELETE') { require __DIR__ . '/routes/meals.php'; return; }
        if ($method === 'PATCH')  { require __DIR__ . '/routes/meals.php'; return; }
    }

    if ($method === 'POST' && $path === '/saved-foods')   { require __DIR__ . '/routes/saved_foods.php';  return; }
    if (preg_match('#^/saved-foods/([0-9a-f-]{36})$#', $path, $m)) {
        $GLOBALS['route_param_id'] = $m[1];
        if ($method === 'DELETE') { require __DIR__ . '/routes/saved_foods.php'; return; }
        if ($method === 'PATCH')  { require __DIR__ . '/routes/saved_foods.php'; return; }
    }

    if ($method === 'POST' && $path === '/settings')      { require __DIR__ . '/routes/settings.php';     return; }
    if ($method === 'GET'  && $path === '/settings')      { require __DIR__ . '/routes/settings.php';     return; }

    if ($method === 'POST' && $path === '/photos')        { require __DIR__ . '/routes/photos.php';       return; }
    if (preg_match('#^/photos/([0-9a-f-]{36})$#', $path, $m)) {
        $GLOBALS['route_param_id'] = $m[1];
        if ($method === 'GET')    { require __DIR__ . '/routes/photos.php'; return; }
        if ($method === 'DELETE') { require __DIR__ . '/routes/photos.php'; return; }
    }

    if ($path === '/wall/posts') {
        if ($method === 'GET' || $method === 'POST') { require __DIR__ . '/routes/wall.php'; return; }
    }
    if (preg_match('#^/wall/posts/([0-9a-f-]{36})$#', $path, $m)) {
        $GLOBALS['route_param_id'] = $m[1];
        if ($method === 'DELETE') { require __DIR__ . '/routes/wall.php'; return; }
    }
    if (preg_match('#^/wall/posts/([0-9a-f-]{36})/(like|save|report|photo)$#', $path, $m)) {
        $GLOBALS['route_param_id'] = $m[1];
        $GLOBALS['route_action'] = $m[2];
        if (in_array($method, ['GET', 'POST', 'DELETE'], true)) { require __DIR__ . '/routes/wall.php'; return; }
    }
    if (preg_match('#^/wall/users/([0-9a-f-]{36})/block$#', $path, $m)) {
        $GLOBALS['route_param_id'] = $m[1];
        $GLOBALS['route_action'] = 'block';
        if ($method === 'POST') { require __DIR__ . '/routes/wall.php'; return; }
    }

    if ($method === 'POST' && $path === '/migrate/bulk')  { require __DIR__ . '/routes/migrate_bulk.php'; return; }

    json_error(404, 'Not found: ' . $method . ' ' . $path);
}
