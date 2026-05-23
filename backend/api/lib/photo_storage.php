<?php
declare(strict_types=1);

/**
 * Photos are stored OUTSIDE the webroot. Path:
 *   {uploads_dir}/{user_uuid}/{photo_uuid}.jpg
 *
 * The PHP route streams them with readfile() after verifying ownership.
 */

function photos_user_dir(array $config, string $userId): string {
    $base = rtrim($config['uploads_dir'], '/');
    $dir = $base . '/' . $userId;
    if (!is_dir($dir)) {
        if (!@mkdir($dir, 0750, true) && !is_dir($dir)) {
            $resolved = realpath($base) ?: $base;
            throw new HttpException(500, 'Could not create uploads directory. Tried: ' . $dir . ' (base resolved to: ' . $resolved . '). Ensure the parent exists, is writable by the web server, and is allowed by open_basedir.');
        }
    }
    return $dir;
}

function photo_path(array $config, string $userId, string $photoId): string {
    return photos_user_dir($config, $userId) . '/' . $photoId . '.jpg';
}

/**
 * Save an uploaded image to disk, re-encoded as JPEG (strips EXIF).
 * Returns the photo UUID.
 */
function photo_save_upload(array $config, string $userId, array $file): string {
    if (!is_uploaded_file($file['tmp_name'] ?? '')) {
        throw new HttpException(400, 'No file uploaded.');
    }
    if (($file['size'] ?? 0) > 4 * 1024 * 1024) {
        throw new HttpException(413, 'Photo exceeds 4 MB limit.');
    }
    $allowed = ['image/jpeg', 'image/png', 'image/heic'];
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->file($file['tmp_name']);
    if (!in_array($mime, $allowed, true)) {
        throw new HttpException(415, 'Unsupported image type: ' . $mime);
    }

    // Decode and re-encode as JPEG to strip metadata and normalize.
    $img = match ($mime) {
        'image/jpeg' => @imagecreatefromjpeg($file['tmp_name']),
        'image/png'  => @imagecreatefrompng($file['tmp_name']),
        'image/heic' => function_exists('imagecreatefromstring')
            ? @imagecreatefromstring(file_get_contents($file['tmp_name']))
            : null,
        default      => null,
    };
    if (!$img) {
        throw new HttpException(400, 'Could not decode image.');
    }

    $photoId = uuid_v4();
    $dest = photo_path($config, $userId, $photoId);
    if (!@imagejpeg($img, $dest, 88)) {
        imagedestroy($img);
        throw new HttpException(500, 'Could not write image.');
    }
    imagedestroy($img);
    @chmod($dest, 0640);

    return $photoId;
}

function photo_delete(array $config, string $userId, string $photoId): void {
    $path = photo_path($config, $userId, $photoId);
    if (file_exists($path)) {
        @unlink($path);
    }
}

function photo_user_wipe(array $config, string $userId): void {
    $dir = rtrim($config['uploads_dir'], '/') . '/' . $userId;
    if (!is_dir($dir)) return;
    foreach (glob($dir . '/*') as $file) {
        @unlink($file);
    }
    @rmdir($dir);
}
