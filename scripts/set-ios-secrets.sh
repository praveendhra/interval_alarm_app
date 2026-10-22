#!/usr/bin/env bash
# Adds the four GitHub Actions secrets the "iOS release" workflow needs.
# Run on your Mac:  ./scripts/set-ios-secrets.sh  [path/to/AuthKey_XXXX.p8]
#
# - API key: the AuthKey_*.p8 you pass, or the newest one in ~/Downloads
# - Key ID:  read from the .p8 file name
# - Issuer ID: you paste it (App Store Connect → Users and Access →
#   Integrations → App Store Connect API, shown above the keys list)
# - Certificate key: ~/ios_cert_key (created for Task Tracker); a new one is
#   generated if it's missing
set -euo pipefail

REPO="praveendhra/interval_alarm_app"

command -v gh >/dev/null || { echo "Install the GitHub CLI first: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || gh auth login

P8="${1:-$(ls -t "$HOME"/Downloads/AuthKey_*.p8 2>/dev/null | head -1 || true)}"
[ -f "$P8" ] || { echo "No AuthKey_*.p8 found. Pass its path: $0 /path/to/AuthKey_XXXX.p8"; exit 1; }
KEY_ID="$(basename "$P8" .p8)"; KEY_ID="${KEY_ID#AuthKey_}"
echo "Using API key $P8 (Key ID $KEY_ID)"

CERT_KEY="$HOME/ios_cert_key"
if [ ! -f "$CERT_KEY" ]; then
  echo "No $CERT_KEY found, creating one"
  ssh-keygen -t rsa -b 2048 -m PEM -f "$CERT_KEY" -q -N ""
fi

read -r -p "Paste your App Store Connect Issuer ID: " ISSUER_ID
[ -n "$ISSUER_ID" ] || { echo "Issuer ID is required"; exit 1; }

gh secret set APP_STORE_CONNECT_PRIVATE_KEY    -R "$REPO" < "$P8"
gh secret set APP_STORE_CONNECT_KEY_IDENTIFIER -R "$REPO" --body "$KEY_ID"
gh secret set APP_STORE_CONNECT_ISSUER_ID      -R "$REPO" --body "$ISSUER_ID"
gh secret set IOS_CERTIFICATE_PRIVATE_KEY      -R "$REPO" < "$CERT_KEY"

echo
gh secret list -R "$REPO"
echo
read -r -p "Start a TestFlight build from the ios-app-store branch now? [y/N] " GO
if [[ "$GO" =~ ^[Yy] ]]; then
  SHA="$(gh api "repos/$REPO/commits/ios-app-store" --jq .sha)"
  TAG="ios-v1.0.0-$(date +%Y%m%d%H%M)"
  gh api "repos/$REPO/git/refs" -f ref="refs/tags/$TAG" -f sha="$SHA" >/dev/null
  echo "Pushed tag $TAG. Follow it at https://github.com/$REPO/actions/workflows/ios-release.yml"
fi
