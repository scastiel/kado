#!/usr/bin/env bash
#
# Re-signs a simulator build so the app and its widget extension carry a team identifier.
#
#   Scripts/resign-simulator.sh build/Build/Products/Debug-iphonesimulator/Kado.app
#   Scripts/resign-simulator.sh path/to/Kado.app "Apple Development: Jane Doe (ABCDE12345)"
#
# Why: Xcode signs simulator builds ad hoc — `codesign -dvv` says `Signature=adhoc`,
# `TeamIdentifier=not set` — and refuses to do otherwise (`AD_HOC_CODE_SIGNING_ALLOWED=NO` fails
# with "Ad Hoc code signing is not allowed with SDK 'Simulator'"). On iOS 26.x simulators, `linkd`
# will not serve AppIntents metadata to a client it cannot attribute to a team:
#
#     Failed to generate bundleIdentity: -Not a platform binary, checking teamId...
#     Rejecting invalid client due to requiresValidBundle
#
# so every entity-typed intent parameter — a widget's picked habits, a Shortcut's habit — silently
# decodes to nil or empty, in the extension and in the app. A TestFlight or App Store build is
# team-signed and never sees this; an iOS 27 simulator accepts the ad-hoc client. This is what cost
# #76 its feature (see docs/plans/2026-09/widget-habit-selection/research.md).
#
# With no identity given, the first "Apple Development" one in the keychain is used. With none at
# all this is a no-op that says so, so a checkout without a certificate still builds and runs —
# only AppIntents fidelity on iOS 26.x simulators is lost.
set -euo pipefail

app="${1:?usage: $0 <path/to/Kado.app> [identity]}"
identity="${2:-${SIGN_IDENTITY:-}}"

if [[ -z "$identity" ]]; then
  identity="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)"
fi
if [[ -z "$identity" ]]; then
  echo "resign-simulator: no Apple Development identity in the keychain; leaving $app ad hoc." >&2
  echo "resign-simulator: AppIntents entity parameters will not decode on iOS 26.x simulators." >&2
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Signs one bundle or binary, keeping any entitlements its ad-hoc signature carries. On the
# simulator Xcode compiles entitlements into the executable's `__TEXT,__entitlements` section
# rather than the signature, and re-signing leaves that section alone — so the App Group and
# iCloud entitlements survive either way.
sign() {
  local target="$1"
  local entitlements="$tmp/$(basename "$target").entitlements"
  if codesign -d --entitlements "$entitlements" --xml "$target" 2>/dev/null \
     && grep -q "<key>" "$entitlements" 2>/dev/null; then
    codesign --force --sign "$identity" --entitlements "$entitlements" "$target"
  else
    codesign --force --sign "$identity" "$target"
  fi
}

# Innermost first: a bundle's signature seals what it contains.
for nested in "$app"/PlugIns/* "$app"/Frameworks/*; do
  [[ -e "$nested" ]] || continue
  for dylib in "$nested"/*.debug.dylib; do
    [[ -e "$dylib" ]] && sign "$dylib"
  done
  sign "$nested"
done
for dylib in "$app"/*.debug.dylib; do
  [[ -e "$dylib" ]] && sign "$dylib"
done
sign "$app"

team="$(codesign -dvv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
echo "resign-simulator: signed $(basename "$app") and its extensions as $identity (team $team)."
