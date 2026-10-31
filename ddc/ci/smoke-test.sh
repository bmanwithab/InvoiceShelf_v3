#!/usr/bin/env bash
# Start a throwaway container from a freshly built DDC image and prove it works:
# the PDF reader is installed, InvoiceShelf installs headlessly, and on the next
# start the DroneDataCommand module is installed and enabled.
#
#   ddc/ci/smoke-test.sh IMAGE
#
# Uses only `docker exec`, so it works on a runner that is itself a container.
# The container runs with --rm and anonymous volumes: stopping it leaves nothing.
set -euo pipefail

IMAGE="${1:?usage: smoke-test.sh IMAGE}"
NAME="ddc-smoke-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-0}-$$"

cleanup() { docker stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --rm --name "$NAME" \
  -v /var/www/html/storage -v /var/www/html/Modules \
  -e NGINX_LISTEN_IP_PROTOCOL=ipv4 \
  -e APP_ENV=production -e APP_URL=http://localhost \
  -e DB_CONNECTION=sqlite -e DB_DATABASE=/var/www/html/storage/app/database.sqlite \
  -e CACHE_STORE=file -e SESSION_DRIVER=file \
  "$IMAGE" >/dev/null

wait_ready() {
  for _ in $(seq 1 90); do
    if docker exec "$NAME" sh -c 'curl -fsS -o /dev/null http://127.0.0.1:8080/up' 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "::error::Container did not become ready"
  docker logs "$NAME" 2>&1 | tail -60
  return 1
}

wait_ready

echo "== PDF reader"
if ! docker exec "$NAME" pdftotext -v 2>&1 | head -n 1; then
  echo "::error::pdftotext is missing from the image"
  exit 1
fi

echo "== Headless install"
docker exec "$NAME" php artisan invoiceshelf:install \
  --admin-email=smoke@example.com --admin-password-random \
  --company="Smoke Test" --currency=USD --timezone=UTC --language=en >/dev/null

echo "== Restart: the DDC entrypoint step installs the module"
docker restart "$NAME" >/dev/null
wait_ready

docker logs "$NAME" 2>&1 | grep -E '\*\*\*\* DDC|!!!! DDC' || true
docker logs "$NAME" 2>&1 | grep -q '!!!! DDC' && { echo "::error::DDC module step reported a failure"; exit 1; }

docker exec "$NAME" php artisan module:list | tee /dev/stderr | grep -Eq '\[Enabled\][[:space:]]+DroneDataCommand' || {
  echo "::error::DroneDataCommand is not enabled"
  exit 1
}

docker exec "$NAME" sh -c 'test -s Modules/DroneDataCommand/dist/init.js && test -f Modules/DroneDataCommand/bundle/classmap.php' || {
  echo "::error::Module assets or PDF parser bundle missing"
  exit 1
}

echo "== An install that began on an older version still keeps the module"
docker exec "$NAME" php artisan tinker --execute='App\Platform\Operations\Models\Setting::setSetting("version", "2.4.7");' >/dev/null
docker restart "$NAME" >/dev/null
wait_ready
docker exec "$NAME" php artisan module:list | grep -Eq '\[Enabled\][[:space:]]+DroneDataCommand' || {
  echo "::error::DroneDataCommand was switched off on a start after an upgrade"
  exit 1
}
docker exec "$NAME" php artisan tinker --execute='echo App\Platform\Operations\Models\Setting::getSetting("version");' | grep -q "$(docker exec "$NAME" head -n 1 version.md)" || {
  echo "::error::The stored InvoiceShelf version was not brought up to date"
  exit 1
}

docker exec "$NAME" sh -c 'test -s storage/app/templates/pdf/invoice/ddc.blade.php' || {
  echo "::error::The ddc invoice template was not installed"
  exit 1
}

# The template must render against this InvoiceShelf version's PDF data.
docker exec "$NAME" php artisan tinker --execute='echo view()->exists("pdf_templates::invoice.ddc") ? "template ok" : "template missing";' | grep -q 'template ok' || {
  echo "::error::The ddc template is not visible to InvoiceShelf"
  exit 1
}

echo "== Branding: the shell, the icon set and the seeded settings"
BRAND="${BRAND_NAME:-Air Reel Technologies}"
LOGIN_HTML="$(docker exec "$NAME" curl -fsS http://127.0.0.1:8080/login)"

printf '%s' "$LOGIN_HTML" | grep -qF "<title>${BRAND}</title>" || {
  echo "::error::<title> is not the brand"; printf '%s' "$LOGIN_HTML" | grep -o '<title>[^<]*</title>' || true; exit 1
}
printf '%s' "$LOGIN_HTML" | grep -qF '/brand/logo-on-dark.png' || {
  echo "::error::the sign-in page does not carry the brand logo"; exit 1
}
# The page legitimately keeps identifiers and URLs that contain the word: the JS
# entry point (window.InvoiceShelf), the module SDK namespace, and this fork's own
# repository address. What must be gone is copy a person reads.
for phrase in "<title>InvoiceShelf" "Self Hosted Invoicing Platform" "Powered by InvoiceShelf" 'alt="InvoiceShelf"'; do
  if printf '%s' "$LOGIN_HTML" | grep -qF "$phrase"; then
    echo "::error::the sign-in page still shows: $phrase"; exit 1
  fi
done
docker exec "$NAME" sh -c 'grep -q "Air Reel" public/favicons/site.webmanifest' || {
  echo "::error::the web manifest was not branded"; exit 1
}
docker exec "$NAME" sh -c 'grep -q "#02befe" public/favicons/browserconfig.xml' || {
  echo "::error::the tile colour was not branded"; exit 1
}
docker exec "$NAME" test -s storage/app/public/branding/logo-tile.png || {
  echo "::error::the sidebar logo was not seeded into storage"; exit 1
}
docker exec "$NAME" php artisan tinker --execute='echo App\Platform\Operations\Models\Setting::getSetting("admin_portal_logo");' \
  | grep -q 'branding/logo-tile.png' || {
  echo "::error::admin_portal_logo was not seeded"; exit 1
}
docker exec "$NAME" php artisan tinker --execute='echo config("invoiceshelf.source_url");' \
  | grep -q 'bmanwithab/InvoiceShelf_v3' || {
  echo "::error::the AGPL source link does not point at this fork"; exit 1
}

echo "Smoke test passed for $IMAGE"
