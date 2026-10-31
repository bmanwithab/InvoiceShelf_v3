<?php

/**
 * Seed the app's own white-label settings with the Air Reel Technologies brand.
 *
 * InvoiceShelf 3.x already ships the surfaces a host needs to white-label an
 * install: the browser tab title, the sign-in logo and copy, the sidebar logo
 * and the "Powered by" line. They are ordinary application settings, so writing
 * them here — rather than patching more templates — means an operator can still
 * change any of them from Administration → Settings afterwards.
 *
 * Only empty values are written: a value an operator has already set always
 * wins, so this step is safe to run on every container start.
 *
 * The sign-in logo is deliberately NOT seeded. A stored logo is one image for
 * both themes, and the brand lockup has a light cut and a dark cut; the Blade
 * shell picks between them instead (ddc/branding/login-logo.html). Seeding this
 * key would pin the sign-in page to one cut and break the other theme.
 */

declare(strict_types=1);

const APP_ROOT = '/var/www/html';

require APP_ROOT.'/vendor/autoload.php';

/** @var \Illuminate\Foundation\Application $app */
$app = require APP_ROOT.'/bootstrap/app.php';
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$brandName = getenv('BRAND_NAME') ?: 'Air Reel Technologies';
$tile = getenv('BRAND_TILE') ?: '/opt/ddc/branding/assets/tile-512.png';

$storageLogo = 'branding/logo-tile.png';
$storageDir = APP_ROOT.'/storage/app/public/branding';

$report = static function (string $line): void {
    fwrite(STDOUT, '  branding: '.$line.PHP_EOL);
};

try {
    if (! \App\Platform\Operations\Installation\Application\InstallationState::isDbCreated()) {
        $report('database not installed yet — skipping settings');

        return;
    }

    // The sidebar logo has to survive both themes from one file, so it is the
    // square cyan tile, not the lockup.
    if (! is_file($storageDir.'/logo-tile.png') && is_file($tile)) {
        if (! is_dir($storageDir) && ! mkdir($storageDir, 0775, true) && ! is_dir($storageDir)) {
            throw new RuntimeException('cannot create '.$storageDir);
        }

        if (! copy($tile, $storageDir.'/logo-tile.png')) {
            throw new RuntimeException('cannot copy the tile into storage');
        }

        @chmod($storageDir.'/logo-tile.png', 0664);
        @chown($storageDir.'/logo-tile.png', 'www-data');
        @chgrp($storageDir.'/logo-tile.png', 'www-data');
    }

    $wanted = [
        'admin_page_title' => $brandName,
        'admin_portal_logo' => $storageLogo,
    ];

    foreach ($wanted as $key => $value) {
        $current = \App\Platform\Operations\Models\Setting::getSetting($key);

        if (is_string($current) && trim($current) !== '') {
            $report($key.' already set — left as '.$current);

            continue;
        }

        \App\Platform\Operations\Models\Setting::setSetting($key, $value);
        $report($key.' -> '.$value);
    }
} catch (\Throwable $e) {
    // Never block a boot on branding: the app is more important than the paint.
    $report('skipped ('.$e->getMessage().')');
}
