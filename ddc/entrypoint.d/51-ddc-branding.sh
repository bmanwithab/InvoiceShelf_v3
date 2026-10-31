#!/bin/sh
# Paint the instance with the Air Reel Technologies brand.
#
# Two halves, kept apart on purpose:
#   - the pixels (lockups, favicons, <title> fallback, UI copy) are baked into
#     the image by ddc/branding/apply.sh at build time — immutable, testable;
#   - the application settings InvoiceShelf itself owns (tab title, sidebar
#     logo) are seeded here on every start, because they live in the database.
#     An operator who edits them in Administration → Settings always wins:
#     seed.php only writes empty values.
#
# Never blocks a boot. Branding is cosmetic; the invoice app is not.

BRAND_NAME="${BRAND_NAME:-Air Reel Technologies}"
SEED=/opt/ddc/branding/seed.php

[ -f "$SEED" ] || exit 0
cd /var/www/html || exit 0

if ! ./artisan migrate:status > /dev/null 2>&1; then
    echo "**** DDC: InvoiceShelf is not installed yet; branding seeds on the next start ****"
    exit 0
fi

echo "**** DDC: branding the instance as $BRAND_NAME ****"
BRAND_NAME="$BRAND_NAME" php "$SEED" || echo "!!!! DDC: branding seed failed; the app keeps its current settings"

# A blade shell baked at build time must not be served from a stale compiled
# view left in the storage volume by the previous image.
./artisan view:clear > /dev/null 2>&1 || true
