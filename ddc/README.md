# InvoiceShelf: Drone Data Command build

This fork's `ddc` branch is upstream InvoiceShelf plus this `ddc/` directory,
and nothing else. All DDC features live in the separate module repository
**invoiceshelf-module-ddc** (bank statement intake, invoice matching, expense
rules, the DDC theme). Keeping upstream files untouched is what lets upstream
updates merge without conflicts.

| Piece | Where | Changes upstream files? |
| --- | --- | --- |
| DDC theme, bank statements, rules | `invoiceshelf-module-ddc` repo | No |
| Docker layer (poppler + module install) | `ddc/Dockerfile`, `ddc/entrypoint.d/` | No |
| Example stack | `ddc/docker-compose.yml` | No |

## Build

Clone both repositories next to each other:

```text
src/
  InvoiceShelf/               <- this fork, branch ddc
  invoiceshelf-module-ddc/    <- the module
```

```bash
cd InvoiceShelf
docker build -f ddc/Dockerfile \
  --build-context ddc_module=../invoiceshelf-module-ddc \
  --build-arg INVOICESHELF_VERSION=3.0.0-alpha.15 \
  -t invoiceshelf-ddc:3.0.0-alpha.15 ddc
```

Or use the example stack: `docker compose -f ddc/docker-compose.yml up -d --build`.

On each start the container copies the module into the `Modules` volume and
runs `install:module`, which migrates and enables it. On a brand new install
the module is installed on the second start, after the setup wizard has run.

Branding beyond colours (company logo, invoice templates, app name) is set in
InvoiceShelf itself: *Settings → Company* for the logo, `APP_NAME` for the
app name. Leave the "Powered by InvoiceShelf" source link in place: the
AGPL-3.0 licence requires that people using the app can get its source.

## Updating to a new InvoiceShelf release

The image is built *from* the upstream image, so most updates are:

1. Bump `INVOICESHELF_VERSION` (build arg or `ddc/docker-compose.yml`).
2. Check the module still declares a compatible range in its `module.json`
   (`compatibility.invoiceshelf`). Rebuild the module's `bundle/` against
   the new release's `composer.lock` if its PHP packages changed.
3. Rebuild and restart. On start, upstream's `modules:reconcile` disables a
   module that does not fit the new version instead of crashing.

To keep this fork's branches in step with upstream:

```bash
git remote add upstream https://github.com/InvoiceShelf/InvoiceShelf.git   # once
git fetch upstream --tags
git checkout ddc
git merge 3.0.0-alpha.16        # the new release tag
git push origin ddc
```

Because `ddc` only adds the `ddc/` directory, this merge does not conflict.

## If the core ever needs a patch

Prefer a module, since modules survive updates. If a change truly has to go
into InvoiceShelf's own code, make it on `ddc` as a small, separate commit,
then build the full image from source and layer the DDC build on it:

```bash
docker build -f docker/production/Dockerfile -t invoiceshelf-core-ddc .
docker build -f ddc/Dockerfile --build-arg BASE_IMAGE=invoiceshelf-core-ddc \
  --build-context ddc_module=../invoiceshelf-module-ddc -t invoiceshelf-ddc ddc
```

Better still, offer the patch upstream as a pull request, so the fork can
drop it.

## Moving from InvoiceShelf 2.x

3.0 is still an alpha. Before switching a live 2.x install:

1. Back up the database and the `storage` volume.
2. Restore that backup into a separate test container running this image and
   check invoices, payments and PDFs.
3. Switch only once the test copy looks right, and keep the 2.x backup.
