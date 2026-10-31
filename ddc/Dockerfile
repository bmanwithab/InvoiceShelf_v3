# Drone Data Command build of InvoiceShelf.
#
# A thin layer over the upstream image, so an InvoiceShelf update is a new
# INVOICESHELF_VERSION and a rebuild. It adds:
#   - poppler-utils, whose `pdftotext -layout` reads bank statement columns;
#   - the DroneDataCommand module, installed and enabled on every start.
#
# Build with the module repository next to this one. The build context is
# this ddc/ directory, never the whole checkout:
#   docker build -f ddc/Dockerfile \
#     --build-context ddc_module=../invoiceshelf-module-ddc \
#     -t invoiceshelf-ddc ddc
#
# To ship a patched core instead of the upstream image, build the fork's
# docker/production/Dockerfile first and pass its tag as BASE_IMAGE.

ARG INVOICESHELF_VERSION=3.0.0-alpha.15
ARG BASE_IMAGE=invoiceshelf/invoiceshelf:${INVOICESHELF_VERSION}

FROM ${BASE_IMAGE}

# The brand this image paints. Override at build time for another install;
# the values also reach the runtime step that seeds the app's own settings.
ARG BRAND_NAME="Air Reel Technologies"
ARG BRAND_URL="https://airreeltech.com"
ENV BRAND_NAME="${BRAND_NAME}" \
    BRAND_URL="${BRAND_URL}"

USER root
RUN apk add --no-cache poppler-utils

# The brand layer: lockups, favicons and the anchor-asserted patch script.
# apply.sh fails the build if an upstream release moves a line it edits, so a
# new INVOICESHELF_VERSION is reviewed rather than silently half-branded.
COPY branding /opt/ddc/branding
RUN sh /opt/ddc/branding/apply.sh

# Only what the module ships: never its vendor/ or node_modules/.
COPY --from=ddc_module --chown=www-data:www-data module.json composer.json LICENSE /opt/ddc/modules/DroneDataCommand/
COPY --from=ddc_module --chown=www-data:www-data app /opt/ddc/modules/DroneDataCommand/app
COPY --from=ddc_module --chown=www-data:www-data bundle /opt/ddc/modules/DroneDataCommand/bundle
COPY --from=ddc_module --chown=www-data:www-data database /opt/ddc/modules/DroneDataCommand/database
COPY --from=ddc_module --chown=www-data:www-data dist /opt/ddc/modules/DroneDataCommand/dist
COPY --from=ddc_module --chown=www-data:www-data lang /opt/ddc/modules/DroneDataCommand/lang
COPY --from=ddc_module --chown=www-data:www-data routes /opt/ddc/modules/DroneDataCommand/routes
COPY --from=ddc_module --chown=www-data:www-data resources/pdf /opt/ddc/modules/DroneDataCommand/resources/pdf
COPY --chmod=755 entrypoint.d/50-ddc-module.sh /etc/entrypoint.d/50-ddc-module.sh
COPY --chmod=755 entrypoint.d/51-ddc-branding.sh /etc/entrypoint.d/51-ddc-branding.sh

USER www-data
