#!/bin/sh
# Renders the Datadog RUM configuration from environment variables at boot.
set -eu

case "${DD_SITE:-datadoghq.com}" in
  datadoghq.com)     REGION=us1 ;;
  us3.datadoghq.com) REGION=us3 ;;
  us5.datadoghq.com) REGION=us5 ;;
  datadoghq.eu)      REGION=eu1 ;;
  ap1.datadoghq.com) REGION=ap1 ;;
  ap2.datadoghq.com) REGION=ap2 ;;
  ddog-gov.com)      REGION=us1-fed ;;
  *)                 REGION=us1 ;;
esac

cat > /usr/share/nginx/html/rum-config.js <<EOF
window.DEMO_RUM = {
  applicationId: "${DD_RUM_APPLICATION_ID:-}",
  clientToken:   "${DD_RUM_CLIENT_TOKEN:-}",
  site:          "${DD_SITE:-datadoghq.com}",
  cdn:           "https://www.datadoghq-browser-agent.com/${REGION}/v5/datadog-rum.js"
};
EOF

# Brand the storefront from the environment, so one image serves any demo.
BRAND="${DEMO_BRAND:-Demo Store}"
for page in /usr/share/nginx/html/index.html /usr/share/nginx/html/control.html; do
  [ -f "$page" ] && sed -i "s|__DEMO_BRAND__|${BRAND}|g" "$page"
done

echo "[web] RUM config rendered for site=${DD_SITE:-datadoghq.com} region=${REGION}"
echo "[web] storefront branded as '${BRAND}'"
