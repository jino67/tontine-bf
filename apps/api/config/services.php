<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    // Ouverture de l'application Android sur les liens partagés. L'empreinte est celle de la clé
    // de signature de l'APK : `keytool -list -v -keystore <fichier>` donne la ligne SHA256.
    'app_links' => [
        'android_package' => env('ANDROID_PACKAGE', 'com.example.app_tontine_bf'),
        'android_fingerprints' => env('ANDROID_SHA256_FINGERPRINTS', ''),
        'apk_url' => env('APK_DOWNLOAD_URL'),
    ],

    // Codes de connexion. "log" les écrit dans storage/logs (refusé en production), "mail" les envoie
    // à l'adresse e-mail liée au numéro. Les numéros de OTP_TEST_PHONES, séparés par des virgules,
    // se connectent avec OTP_TEST_CODE (6 chiffres) sans rien recevoir, sauf en production.
    'otp' => [
        'channel' => env('OTP_CHANNEL', 'log'),
        'test_phones' => env('OTP_TEST_PHONES', ''),
        'test_code' => env('OTP_TEST_CODE'),
    ],

    // Paiements en ligne. En mode "test", les factures passent par la sandbox PayDunya.
    // Les remises (déboursements) n'ont pas de sandbox : elles déplacent de l'argent réel,
    // et restent refusées tant que PAYDUNYA_PAYOUTS_ENABLED ne vaut pas true.
    'paydunya' => [
        'mode' => env('PAYDUNYA_MODE', 'test'),
        'master_key' => env('PAYDUNYA_MASTER_KEY'),
        'public_key' => env('PAYDUNYA_PUBLIC_KEY'),
        'private_key' => env('PAYDUNYA_PRIVATE_KEY'),
        'token' => env('PAYDUNYA_TOKEN'),
        'store_name' => env('PAYDUNYA_STORE_NAME', 'Tontine BF'),
        'payouts_enabled' => (bool) env('PAYDUNYA_PAYOUTS_ENABLED', false),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
