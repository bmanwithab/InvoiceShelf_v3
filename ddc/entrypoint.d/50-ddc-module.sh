#!/bin/sh
# Install the Drone Data Command module that ships inside the image.
#
# Modules/ is a volume, so the module is copied in on every start: a rebuilt
# image with a newer module replaces the module's files there. Files are
# overwritten, never removed. install:module is idempotent; it runs the
# module's migrations and enables it.

SRC=/opt/ddc/modules/DroneDataCommand
DEST=/var/www/html/Modules/DroneDataCommand

[ -f "$SRC/module.json" ] || exit 0
cd /var/www/html || exit 0

if ! ./artisan migrate:status > /dev/null 2>&1; then
    echo "**** DDC: InvoiceShelf is not installed yet; the module installs on the next start ****"
    exit 0
fi

version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$SRC/module.json" | head -n 1)

echo "**** DDC: installing DroneDataCommand module $version ****"
mkdir -p "$DEST" && cp -a "$SRC/." "$DEST/" || {
    echo "!!!! DDC: cannot write to $DEST; is the Modules volume writable by www-data?"
    exit 0
}

./artisan install:module DroneDataCommand "$version" || echo "!!!! DDC: module install failed; InvoiceShelf keeps running without it"
./artisan optimize:clear > /dev/null 2>&1 || true
