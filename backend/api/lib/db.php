<?php
declare(strict_types=1);

function db_init(array $cfg): void {
    $dsn = sprintf(
        'mysql:host=%s;dbname=%s;charset=%s',
        $cfg['host'],
        $cfg['name'],
        $cfg['charset'] ?? 'utf8mb4'
    );
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        // Emulated prepares are required because several upserts reuse the
        // same named placeholder on both sides of INSERT ... ON DUPLICATE KEY
        // UPDATE. Native prepares on some PHP/PDO_MySQL builds (notably
        // shared-host PHP < 8.1) reject this with SQLSTATE[HY093]. Safe with
        // utf8mb4; PDO still escapes via the driver.
        PDO::ATTR_EMULATE_PREPARES   => true,
    ];
    try {
        $pdo = new PDO($dsn, $cfg['user'], $cfg['password'], $options);
    } catch (PDOException $e) {
        json_error(500, 'Database connection failed.');
    }
    $GLOBALS['__pdo'] = $pdo;
}

function db(): PDO {
    if (empty($GLOBALS['__pdo'])) {
        throw new RuntimeException('db_init() was not called.');
    }
    return $GLOBALS['__pdo'];
}

function db_now(): string {
    return gmdate('Y-m-d H:i:s');
}
