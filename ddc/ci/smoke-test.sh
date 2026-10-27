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

echo "Smoke test passed for $IMAGE"
