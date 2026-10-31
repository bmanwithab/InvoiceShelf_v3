#!/bin/sh
# Paint the instance with the Air Reel Technologies brand.
#
# Three layers, kept apart on purpose:
#   - the pixels (lockups, favicons, <title> fallback, UI copy) are baked into
#     the image by ddc/branding/apply.sh at build time — immutable, testable;
#   - the app name lives in .env, which the entrypoint writes from the
#     environment unquoted. A value containing a space makes that file invalid
#     and the container exits before it serves anything, so the name is
#     corrected here, quoted, before anything reads it;
#   - the settings InvoiceShelf itself owns (tab title, sidebar logo) live in the
#     database, so they are seeded on every start. An operator who edits them in
#     Administration → Settings always wins: seed.php only writes empty values.
#
# The file name matters. Among the 50-* steps this one sorts before
# 50-laravel-automations.sh, which is what runs `config:cache` — brand the .env
# after that and the cached config keeps the old name.
#
# Never blocks a boot. Branding is cosmetic; the invoice app is not.

BRAND_NAME="${BRAND_NAME:-Air Reel Technologies}"
SEED=/opt/ddc/branding/seed.php
APP=/var/www/html

[ -f "$SEED" ] || exit 0
cd "$APP" || exit 0

# 1. The app name, quoted. Covers a .env born from an environment that carried a
#    spaced APP_NAME, and one whose example still holds upstream's name.
if [ -f "$APP/.env" ]; then
    if grep -q '^APP_NAME=' "$APP/.env"; then
        sed -i "s|^APP_NAME=.*|APP_NAME=\"$BRAND_NAME\"|" "$APP/.env"
    else
        printf 'APP_NAME="%s"\n' "$BRAND_NAME" >> "$APP/.env"
    fi
fi

# 2. The settings the app owns — only once the database is installed and migrated.
if ! ./artisan migrate:status > /dev/null 2>&1; then
    echo "**** DDC: InvoiceShelf is not installed yet; the brand settings seed on the next start ****"
    exit 0
fi

echo "**** DDC: branding the instance as $BRAND_NAME ****"
BRAND_NAME="$BRAND_NAME" php "$SEED" || echo "!!!! DDC: branding seed failed; the app keeps its current settings"

# A blade shell baked at build time must not be served from a stale compiled
# view left in the storage volume by the previous image.
./artisan view:clear > /dev/null 2>&1 || true
