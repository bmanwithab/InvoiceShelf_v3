# Air Reel Technologies brand layer

The image is upstream InvoiceShelf plus the DroneDataCommand module. This
directory makes it *look* like Air Reel Technologies instead of upstream, and
keeps the two halves of that job apart:

| Layer | Where | Lives in |
| --- | --- | --- |
| Pixels: lockups, favicons, manifests, `<title>` fallback, UI copy | `apply.sh`, build time | the image (immutable) |
| Settings the app owns: tab title, sidebar logo | `seed.php`, every start | the database (editable in the UI) |

`apply.sh` is anchor-asserted. Upstream moving a line it edits fails the build
instead of shipping a half-branded app — that is the review gate on every
`INVOICESHELF_VERSION` bump.

## Assets

Derived from `Invoicelogo_Air Reel Logo2026-with_Tagline.png` (Brian's own 2026
lockup, 1908×886). Nothing here is redrawn by hand:

- `logo-on-dark.png` — the lockup with the wordmark in white, for dark UI. Made by
  lifting the black pixels of the source to white and leaving the cyan drone alone.
- `logo-on-light.png` — the source lockup as-is (black wordmark, transparent ground).
- `tile-512.png` and the favicon set — the source drone glyph and rule, white, on a
  rounded square of the brand cyan sampled from the logo (`#02befe`).
- `favicon-16x16.png` — a simplified cut: at 16 px the glyph's hairlines collapse, so
  the body and the rule are all that is left.

## Two logos, because one image cannot serve both themes

The sign-in page takes its logo from `window.login_page_logo`, which the shell sets
from the stored `login_page_logo` setting — one image, no theme awareness. The shell
now falls back to `logo-on-dark.png` or `logo-on-light.png` depending on the theme
already applied by the theme bootstrap, and a stored logo still wins because the
body script sets the same variable afterwards.

The sidebar is a single file either way, so `seed.php` seeds it with the square tile,
which reads on both themes.

## What is deliberately still upstream wording

- The module SDK namespace and PHP symbols (`InvoiceShelf\...`) — renaming them
  breaks autoloading.
- `INVOICESHELF_*` environment variable names.
- `window.InvoiceShelf` (the SPA entry point).
- The inlined wordmark artwork in `MainLogo-*.js` — a vector lockup, not a string.
  It only shows where neither a stored logo nor the sign-in fallback applies, e.g.
  the installer and the thin-client lock screen.
- The non-English locale files. They are Crowdin-sourced upstream translations.

## Changing the brand

`BRAND_NAME` / `BRAND_URL` are build args on `ddc/Dockerfile`. Bump
`ddc/branding/VERSION` with any asset or copy change so the published tag moves
and a pinned deploy does not silently get new pixels.
