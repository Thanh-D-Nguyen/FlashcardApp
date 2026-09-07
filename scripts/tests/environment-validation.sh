#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
check() {
    expected=$1 configuration=$2 environment=$3 bundle=$4 url=$5
    if CONFIGURATION="$configuration" APP_ENVIRONMENT="$environment" PRODUCT_BUNDLE_IDENTIFIER="$bundle" PRODUCT_BASE_URL="$url" \
        /bin/sh "$root/scripts/validate-environment.sh" >/dev/null 2>&1; then actual=pass; else actual=fail; fi
    [ "$actual" = "$expected" ] || { echo "FAIL: $configuration $environment ($expected expected)" >&2; exit 1; }
}
check pass Debug local com.ds.FlashcardApp.dev http://localhost:4000/api
check pass Debug local com.ds.FlashcardApp.dev http://127.0.0.1:4000/api
check pass Staging staging com.ds.FlashcardApp.staging https://staging.company.org/api
check pass Release production com.ds.FlashcardApp https://api.company.org/api
check fail Release production com.ds.FlashcardApp ''
check fail Staging staging com.ds.FlashcardApp.staging http://staging.company.org/api
check fail Release production com.ds.FlashcardApp http://localhost:4000/api
check fail Debug local com.ds.FlashcardApp.dev http://192.168.1.5:4000/api
check fail Debug local com.ds.FlashcardApp.dev http://localhost.attacker.com/api
check fail Release production com.ds.FlashcardApp https://api.example.com/api
check fail Release production com.ds.FlashcardApp https://user:pass@api.company.org/api
check fail Release production com.ds.FlashcardApp 'https://api.company.org/api?token=secret'
check fail Release production com.ds.FlashcardApp https://api.company.org:99999/api
check fail Release production com.ds.FlashcardApp 'https://api.company.org/a path'
check fail Release production com.ds.FlashcardApp 'https://api.company.org/%zz'
check fail Release production com.ds.FlashcardApp 'https:///api'
check fail Release local com.ds.FlashcardApp http://localhost:4000/api
check fail Debug local com.ds.FlashcardApp http://localhost:4000/api
echo 'Environment validation: 18 cases passed.'
