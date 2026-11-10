#!/bin/sh
# Runs before Sources in Xcode. Never print configured URLs (they may contain credentials).
set -eu
fail() { echo "error: $*" >&2; exit 1; }
case "${CONFIGURATION:-}:${APP_ENVIRONMENT:-}:${PRODUCT_BUNDLE_IDENTIFIER:-}" in
    Debug:local:com.ds.FlashcardApp.dev|Staging:staging:com.ds.FlashcardApp.staging|Release:production:com.ds.FlashcardApp) ;;
    *) fail 'Configuration, APP_ENVIRONMENT and bundle identifier do not match the supported environment.' ;;
esac
[ -n "${PRODUCT_BASE_URL:-}" ] || fail "Set PRODUCT_BASE_URL in FlashcardApp/Environments/${APP_ENVIRONMENT}.local.xcconfig before building."
/usr/bin/awk 'BEGIN {
    url = ENVIRON["PRODUCT_BASE_URL"]
    if (url !~ /^https?:\/\// || url ~ /[[:space:]\\@?#]/) exit 1
    scheme = url; sub(/:.*/, "", scheme)
    rest = url; sub(/^https?:\/\//, "", rest)
    authority = rest; sub(/\/.*/, "", authority)
    if (split(authority, parts, ":") > 2) exit 1
    host = parts[1]
    if (authority ~ /:/ && (parts[2] !~ /^[0-9]+$/ || parts[2] < 1 || parts[2] > 65535)) exit 1
    if (host == "" || length(host) > 253) exit 1
    count = split(host, labels, ".")
    for (i = 1; i <= count; i++) {
        if (labels[i] !~ /^[A-Za-z0-9-]+$/ || labels[i] ~ /^-|-$/ || length(labels[i]) > 63) exit 1
    }
    path = substr(rest, length(authority) + 1)
    if (path ~ /[^A-Za-z0-9._~!$&()*+,;=:\/%-]/) exit 1
    gsub(/%[0-9A-Fa-f][0-9A-Fa-f]/, "", path)
    if (path ~ /%/) exit 1
    loopback = (host == "localhost" || host == "127.0.0.1")
    if (ENVIRON["APP_ENVIRONMENT"] == "local") exit !loopback
    if (scheme != "https" || loopback || count < 2) exit 1
    if (host ~ /(^|\.)(example\.(com|org|net)|invalid|example|test|localhost)$/) exit 1
    exit 0
}' || fail 'PRODUCT_BASE_URL must be a valid HTTPS API URL; local allows only localhost or 127.0.0.1. Credentials, query strings and placeholder domains are forbidden.'

# Google sign-in client IDs are public identifiers, but a swapped or malformed one only fails later on a device.
# Never echo the values.
client_id='^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$'
prefix='^[0-9]+-[a-z0-9]+$'
printf '%s\n' "${GOOGLE_SERVER_CLIENT_ID:-}" | /usr/bin/grep -Eq "$client_id" \
    || fail 'GOOGLE_SERVER_CLIENT_ID must be the Web OAuth client ID (NNN-xxx.apps.googleusercontent.com).'
if [ -n "${GOOGLE_IOS_CLIENT_ID_PREFIX:-}" ]; then
    printf '%s\n' "$GOOGLE_IOS_CLIENT_ID_PREFIX" | /usr/bin/grep -Eq "$prefix" \
        || fail 'GOOGLE_IOS_CLIENT_ID_PREFIX must be the iOS OAuth client ID without .apps.googleusercontent.com.'
    [ "$GOOGLE_IOS_CLIENT_ID_PREFIX.apps.googleusercontent.com" != "$GOOGLE_SERVER_CLIENT_ID" ] \
        || fail 'GOOGLE_IOS_CLIENT_ID_PREFIX is the Web client; use the iOS client created for this bundle ID.'
elif [ "${CONFIGURATION:-}" = Release ]; then
    echo 'warning: GOOGLE_IOS_CLIENT_ID_PREFIX is empty; this Release build has no Google sign-in button.'
fi
