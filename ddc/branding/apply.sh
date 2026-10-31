#!/bin/sh
# Bake the Air Reel Technologies brand into the InvoiceShelf image.
#
# Runs at BUILD time (ddc/Dockerfile) as root, before USER www-data, inside the
# Alpine image — so: busybox sed/awk/grep only, no python, no GNU extensions.
#
# Every edit is anchor-asserted: when an upstream release moves or rewords a
# line this script fails the build instead of shipping a half-branded app.
# Re-check the anchors on every INVOICESHELF_VERSION bump.
#
# Touched:
#   public/brand/*                       lockups and tile (theme-aware logo)
#   public/favicons/*                    tab icon, home-screen icons, manifests
#   resources/views/app.blade.php        logo picker, browser chrome colours
#   app/Platform/Operations/helpers.php  <title> fallback
#   config/invoiceshelf.php              "Powered by" fallback name and address
#   resources/views/emails/test.blade.php, resources/views/mcp/consent.blade.php
#   public/build/assets/en-*.js          the English UI dictionary
#   public/build/assets/{branding,PoweredBy,AuthLayout,MainLogo,InstallationLayout}-*.js
#
# Deliberately left alone: the module SDK namespace (InvoiceShelf\...), the
# INVOICESHELF_* environment names, `window.InvoiceShelf` and the inlined
# wordmark artwork in MainLogo. See README.md.

set -eu

APP=/var/www/html
BRAND_NAME="${BRAND_NAME:-Air Reel Technologies}"
BRAND_URL="${BRAND_URL:-https://airreeltech.com}"
BRAND_INK="${BRAND_INK:-#0d0d16}"
BRAND_ACCENT="${BRAND_ACCENT:-#02befe}"
# The fork's own source, not upstream's: AGPL section 13 wants what is running.
BRAND_SOURCE_URL="${BRAND_SOURCE_URL:-https://github.com/bmanwithab/InvoiceShelf_v3/tree/{version}}"
HERE="$(cd "$(dirname "$0")" && pwd)"

say() { printf '  branding: %s\n' "$*"; }
die() { printf '  branding: FAILED — %s\n' "$*" >&2; exit 1; }
need() { grep -qF -- "$2" "$1" || die "$3 not found in $1 (upstream changed; re-check the anchor)"; }

# ── assets ─────────────────────────────────────────────────────────────────
mkdir -p "$APP/public/brand"
cp "$HERE/assets/logo-on-dark.png" "$APP/public/brand/logo-on-dark.png"
cp "$HERE/assets/logo-on-light.png" "$APP/public/brand/logo-on-light.png"
cp "$HERE/assets/tile-512.png" "$APP/public/brand/tile-512.png"
say "lockups and tile copied to public/brand"

for f in favicon-16x16.png favicon-32x32.png favicon.ico favicon.svg \
         apple-touch-icon.png android-chrome-192x192.png \
         android-chrome-512x512.png mstile-150x150.png safari-pinned-tab.svg; do
    [ -d "$APP/public/favicons" ] || die "public/favicons missing"
    cp "$HERE/assets/$f" "$APP/public/favicons/$f"
done
say "favicon set replaced"

# ── manifests ──────────────────────────────────────────────────────────────
if [ -f "$APP/public/favicons/site.webmanifest" ]; then
    sed -i \
        -e "s|\"name\": *\"[^\"]*\"|\"name\": \"$BRAND_NAME\"|" \
        -e "s|\"short_name\": *\"[^\"]*\"|\"short_name\": \"$BRAND_NAME\"|" \
        -e "s|\"theme_color\": *\"[^\"]*\"|\"theme_color\": \"$BRAND_INK\"|" \
        "$APP/public/favicons/site.webmanifest"
    grep -qF "$BRAND_NAME" "$APP/public/favicons/site.webmanifest" || die "manifest not branded"
fi
if [ -f "$APP/public/favicons/browserconfig.xml" ]; then
    sed -i -e "s|<TileColor>[^<]*</TileColor>|<TileColor>$BRAND_ACCENT</TileColor>|" \
        "$APP/public/favicons/browserconfig.xml"
fi
say "manifests branded"

# ── blade shell: theme-aware logo + browser chrome colours ─────────────────
BLADE="$APP/resources/views/app.blade.php"
need "$BLADE" "var theme = localStorage.getItem('theme') || 'system';" 'theme bootstrap script'
need "$BLADE" '<meta name="theme-color" content="#1c1845">' 'theme-color meta'
need "$BLADE" 'href="/favicons/safari-pinned-tab.svg" color="#4c3cd6"' 'mask-icon colour'
need "$BLADE" '</head>' 'head close'

sed -i -e "s|content=\"#1c1845\"|content=\"$BRAND_INK\"|" "$BLADE"
sed -i -e "s|color=\"#4c3cd6\"|color=\"$BRAND_ACCENT\"|" "$BLADE"

if ! grep -qF 'window.brand_login_logo' "$BLADE"; then
    SNIPPET="$(sed -e "s|__BRAND_NAME__|$BRAND_NAME|g" "$HERE/login-logo.html")"
    printf '%s\n' "$SNIPPET" > /tmp/brand-snippet.html
    awk 'BEGIN{done=0} /^<\/head>[[:space:]]*$/ && done==0 { while ((getline line < "/tmp/brand-snippet.html") > 0) print line; done=1 } {print}' \
        "$BLADE" > /tmp/app.blade.php
    [ -s /tmp/app.blade.php ] || die "blade rewrite produced an empty file"
    grep -qF 'window.brand_login_logo' /tmp/app.blade.php || die "blade insertion did not land"
    mv /tmp/app.blade.php "$BLADE"
    rm -f /tmp/brand-snippet.html
fi
say "blade shell: theme-aware logo, application-name, chrome colours"

# ── <title> fallback ───────────────────────────────────────────────────────
HELPERS="$APP/app/Platform/Operations/helpers.php"
need "$HELPERS" "return \$configured ?: 'InvoiceShelf - Self Hosted Invoicing Platform';" '<title> fallback'
sed -i "s|return \$configured ?: 'InvoiceShelf - Self Hosted Invoicing Platform';|return \$configured ?: '$BRAND_NAME';|" "$HELPERS"
say "<title> fallback -> $BRAND_NAME"

# ── "Powered by" fallback ──────────────────────────────────────────────────
CFG="$APP/config/invoiceshelf.php"
need "$CFG" "env('INVOICESHELF_POWERED_BY_NAME', 'InvoiceShelf')" 'powered-by name default'
need "$CFG" "env('INVOICESHELF_POWERED_BY_URL', 'https://invoiceshelf.com')" 'powered-by url default'
sed -i "s|env('INVOICESHELF_POWERED_BY_NAME', 'InvoiceShelf')|env('INVOICESHELF_POWERED_BY_NAME', '$BRAND_NAME')|" "$CFG"
sed -i "s|env('INVOICESHELF_POWERED_BY_URL', 'https://invoiceshelf.com')|env('INVOICESHELF_POWERED_BY_URL', '$BRAND_URL')|" "$CFG"
say "powered-by defaults -> $BRAND_NAME"

# AGPL section 13 wants the source of the version actually running. This is a
# fork, so upstream's address is the wrong answer — it must point at our branch.
need "$CFG" "env('INVOICESHELF_SOURCE_URL', 'https://github.com/InvoiceShelf/InvoiceShelf/tree/{version}')" 'source-url default'
sed -i "s|env('INVOICESHELF_SOURCE_URL', 'https://github.com/InvoiceShelf/InvoiceShelf/tree/{version}')|env('INVOICESHELF_SOURCE_URL', '$BRAND_SOURCE_URL')|" "$CFG"
say "source-url default -> $BRAND_SOURCE_URL"

# ── visible copy in blade partials ─────────────────────────────────────────
for f in "$APP/resources/views/emails/test.blade.php" "$APP/resources/views/mcp/consent.blade.php"; do
    [ -f "$f" ] || continue
    sed -i "s|InvoiceShelf|$BRAND_NAME|g" "$f"
done
say "email test + MCP consent copy"

# ── built assets: the English UI dictionary ────────────────────────────────
# A locale file is pure user-facing copy, so a blanket swap is safe there — but
# assert first: a dotted or capitalised identifier inside it would mean upstream
# moved code into the dictionary, and the swap has to be re-thought by hand.
en_found=0
for f in "$APP"/public/build/assets/en-*.js; do
    [ -f "$f" ] || continue
    en_found=1
    # A sentence-ending full stop is prose, not code; an identifier continuation
    # (InvoiceShelfServer, window.InvoiceShelf) is code and must not be touched.
    if grep -qE 'InvoiceShelf[A-Za-z_$]|window\.InvoiceShelf|\\InvoiceShelf\\' "$f"; then
        die "code identifiers found in $(basename "$f") — refusing the blanket swap"
    fi
    sed -i "s|InvoiceShelf|$BRAND_NAME|g" "$f"
    say "UI dictionary $(basename "$f") rebranded"
done
[ "$en_found" = 1 ] || die "no en-*.js dictionary found in public/build/assets"

# Chunks whose brand string sits in a literal we can name exactly. A chunk that
# does not carry it is skipped: upstream may have inlined or moved the literal.
patch_literal() { # patch_literal <glob> <exact-from> <to>
    for f in "$APP"/public/build/assets/$1; do
        [ -f "$f" ] || continue
        grep -qF -- "$2" "$f" || continue
        sed -i "s|$2|$3|g" "$f"
        say "$(basename "$f"): $(printf '%.40s' "$2") -> patched"
    done
}
patch_literal 'branding-*.js' '`InvoiceShelf`' "\`$BRAND_NAME\`"
patch_literal 'branding-*.js' 'https://invoiceshelf.com' "$BRAND_URL"
patch_literal 'PoweredBy-*.js' '`InvoiceShelf`' "\`$BRAND_NAME\`"
patch_literal 'AuthLayout-*.js' 'alt:`InvoiceShelf`' "alt:\`$BRAND_NAME\`"
patch_literal 'MainLogo-*.js' '"aria-label":`InvoiceShelf`' "\"aria-label\":\`$BRAND_NAME\`"
patch_literal 'CompanyLayout-*.js' '"aria-label":`InvoiceShelf`' "\"aria-label\":\`$BRAND_NAME\`"
patch_literal 'install-*.js' '"aria-label":`InvoiceShelf`' "\"aria-label\":\`$BRAND_NAME\`"

# ── report ─────────────────────────────────────────────────────────────────
count_brand() { # count_brand <file> — 0 when the string is gone or the file is absent
    [ -f "$1" ] || { echo 0; return 0; }
    grep -o InvoiceShelf "$1" 2>/dev/null | wc -l | tr -d ' ' || true
}

echo "  branding: summary"
for f in "$APP"/public/build/assets/en-*.js "$APP"/public/build/assets/branding-*.js "$BLADE" "$HELPERS"; do
    [ -f "$f" ] || continue
    printf '    %-34s remaining "InvoiceShelf": %s\n' "$(basename "$f")" "$(count_brand "$f")"
done
echo "  branding: done — $BRAND_NAME"
