<?php
declare(strict_types=1);

class HttpException extends Exception {
    public int $status;
    public function __construct(int $status, string $message) {
        parent::__construct($message);
        $this->status = $status;
    }
}

function json_ok($payload, int $status = 200): void {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function json_error(int $status, string $message): void {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => $message]);
    exit;
}

function read_json_body(): array {
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') return [];
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        throw new HttpException(400, 'Request body must be valid JSON.');
    }
    return $data;
}

function require_field(array $body, string $key) {
    if (!array_key_exists($key, $body) || $body[$key] === null || $body[$key] === '') {
        throw new HttpException(400, "Missing field: $key");
    }
    return $body[$key];
}

function client_ip(): string {
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $parts = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        return trim($parts[0]);
    }
    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

/** ISO8601 / RFC3339 → "Y-m-d H:i:s" for MySQL DATETIME columns. */
function iso_to_mysql(?string $iso): ?string {
    if (!$iso) return null;
    $ts = strtotime($iso);
    if ($ts === false) {
        throw new HttpException(400, "Invalid date value: $iso");
    }
    return date('Y-m-d H:i:s', $ts);
}

/** MySQL DATETIME → ISO8601 string with UTC marker. */
function mysql_to_iso(?string $dt): ?string {
    if (!$dt) return null;
    return gmdate('Y-m-d\TH:i:s\Z', strtotime($dt . ' UTC'));
}

function uuid_valid(string $s): bool {
    return (bool) preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $s);
}
