#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
web=112477118682-4b6pb2ph8i2lrbao13l90rvn5qitra4g.apps.googleusercontent.com
cases=0
check() {
    expected=$1 configuration=$2 environment=$3 bundle=$4 url=$5 ios_prefix=${6:-} server=${7-$web}
    cases=$((cases + 1))
    if CONFIGURATION="$configuration" APP_ENVIRONMENT="$environment" PRODUCT_BUNDLE_IDENTIFIER="$bundle" PRODUCT_BASE_URL="$url" \
        GOOGLE_IOS_CLIENT_ID_PREFIX="$ios_prefix" GOOGLE_SERVER_CLIENT_ID="$server" \
        /bin/sh "$root/scripts/validate-environment.sh" >/dev/null 2>&1; then actual=pass; else actual=fail; fi
    [ "$actual" = "$expected" ] || { echo "FAIL: $configuration $environment ($expected expected)" >&2; exit 1; }
}
check pass Debug local com.ds.FlashcardApp.dev http://localhost:18081/api
check pass Debug local com.ds.FlashcardApp.dev http://127.0.0.1:18081/api
check pass Staging staging com.ds.FlashcardApp.staging https://staging.company.org/api
check pass Release production com.ds.FlashcardApp https://api.company.org/api
check fail Release production com.ds.FlashcardApp ''
check fail Staging staging com.ds.FlashcardApp.staging http://staging.company.org/api
check fail Release production com.ds.FlashcardApp http://localhost:18081/api
check fail Debug local com.ds.FlashcardApp.dev http://192.168.1.5:18081/api
check fail Debug local com.ds.FlashcardApp.dev http://localhost.attacker.com/api
check fail Release production com.ds.FlashcardApp https://api.example.com/api
check fail Release production com.ds.FlashcardApp https://user:pass@api.company.org/api
check fail Release production com.ds.FlashcardApp 'https://api.company.org/api?token=secret'
check fail Release production com.ds.FlashcardApp https://api.company.org:99999/api
check fail Release production com.ds.FlashcardApp 'https://api.company.org/a path'
check fail Release production com.ds.FlashcardApp 'https://api.company.org/%zz'
check fail Release production com.ds.FlashcardApp 'https:///api'
check fail Release local com.ds.FlashcardApp http://localhost:18081/api
check fail Debug local com.ds.FlashcardApp http://localhost:18081/api
# Google sign-in clients: the iOS client is optional (button hidden) but must never be the Web client or malformed.
check pass Release production com.ds.FlashcardApp https://kiokoto.com/api
check pass Release production com.ds.FlashcardApp https://kiokoto.com/api 987654321098-abcdef0123456789abcdef0123456789
check pass Debug local com.ds.FlashcardApp.dev http://localhost:18081/api 987654321098-abcdef0123456789abcdef0123456789
check fail Release production com.ds.FlashcardApp https://kiokoto.com/api 112477118682-4b6pb2ph8i2lrbao13l90rvn5qitra4g
check fail Release production com.ds.FlashcardApp https://kiokoto.com/api 'not an id'
check fail Release production com.ds.FlashcardApp https://kiokoto.com/api 987654321098-abc.apps.googleusercontent.com
check fail Release production com.ds.FlashcardApp https://kiokoto.com/api '' ''
check fail Release production com.ds.FlashcardApp https://kiokoto.com/api '' 'web-client'
echo "Environment validation: $cases cases passed."
