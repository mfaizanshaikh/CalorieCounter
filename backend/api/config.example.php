<?php
/**
 * Copy this file to `config.php` (same directory) and fill in real values.
 * `config.php` MUST NOT be committed to git and is blocked from direct HTTP
 * access by .htaccess.
 *
 * Generate JWT_SECRET with:  openssl rand -base64 48
 */

return [
    // Database (cPanel → MySQL Databases).
    'db' => [
        'host'     => 'localhost',
        'name'     => 'YOUR_DB_NAME',
        'user'     => 'YOUR_DB_USER',
        'password' => 'YOUR_DB_PASSWORD',
        'charset'  => 'utf8mb4',
    ],

    // JWT signing secret for app session tokens. Must be at least 32 bytes.
    'jwt_secret' => 'REPLACE_WITH_A_LONG_RANDOM_STRING',

    // The iOS Google OAuth client ID from Google Cloud Console
    // (NOT the web client ID). Looks like "12345-abcdef.apps.googleusercontent.com".
    'google_ios_client_id' => 'REPLACE_WITH_GOOGLE_IOS_CLIENT_ID',

    // Apple Services ID / app bundle ID used as the "aud" claim for Sign in with Apple.
    'apple_bundle_id' => 'com.mfaizanshaikh.caloriecounter',

    // Absolute path to a directory OUTSIDE the webroot for storing photo files.
    // Must be writable by the web server and reachable under open_basedir.
    //
    // The default below resolves one level above public_html via __DIR__,
    // which works on both Hostinger's simple layout (/home/<user>/public_html/...)
    // and multi-domain layout (/home/<user>/domains/<domain>/public_html/...).
    // Override with a literal absolute path (e.g. '/home/USER/private_uploads')
    // only if your install puts api/ somewhere unusual.
    'uploads_dir' => __DIR__ . '/../../../private_uploads',

    // Public wall photo safety. The default "hold" mode keeps newly posted
    // photos out of the public feed until you review them manually. Set mode
    // to "openai" and provide a server-side API key to publish only after the
    // image moderation endpoint returns a safe result.
    'wall_image_moderation' => [
        'mode' => 'hold', // "hold" or "openai"
        'openai_api_key' => null,
        'openai_model' => 'omni-moderation-latest',
    ],

    // Token lifetimes.
    'access_token_ttl_seconds'  => 15 * 60,                   // 15 minutes
    'refresh_token_ttl_seconds' => 60 * 60 * 24 * 60,         // 60 days

    // Rate-limit window for /auth/login (per IP).
    'login_rate' => [
        'window_seconds' => 60,
        'max_attempts'   => 10,
    ],

    // Set true while testing locally to see PHP errors in the JSON response.
    'debug' => false,
];
