#!/usr/bin/env bash
#
# Produces the App Store screenshots, one set per language and per device size.
#
#   Scripts/screenshots.sh                          # everything the listing needs
#   Scripts/screenshots.sh --languages en           # just English
#   Scripts/screenshots.sh --devices iphone-6.9     # just the iPhone set
#
# It drives `KadoUITests/ScreenshotTests` — the only suite `make e2e` skips — once per language
# and per device, with `-testLanguage` so the app and its seeded data are both in that language.
# The pictures come out of the result bundle and land in
# docs/app-store/screenshots/<locale>/<device>/, numbered in the order App Store Connect should
# show them, then get wrapped for the listing into docs/app-store/marketing/.
#
# Two passes per combination, because nothing inside a test can change the simulator's
# appearance: a light one for shots 01–05 and a dark one for 06.
#
# Before each pass the simulator is set to that language, booted, pinned to an appearance and
# given a 9:41 status bar, so two runs a week apart differ only where the app differs.
#
# The app never opens the developer's real store: `ScreenshotTests` launches with `-uiTestRun`,
# which redirects SwiftData to a throwaway file and drops CloudKit. A screenshot run cannot
# reach — let alone sync — anybody's actual habits.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CONFIG="docs/app-store/config.json"
OUTPUT="docs/app-store/screenshots"
# What the listing actually uploads: the same captures, wrapped in the paper ground, the
# headline and the device. The raw tree stays beside it as the source of truth, so restyling
# the set is `make frames` and a few seconds rather than a simulator per language per device.
FRAMED="docs/app-store/marketing"
CAPTIONS="docs/app-store/captions.json"
# Whether to also refresh the marketing site's copies on the way out. `--no-site` clears it,
# for a partial run whose captures shouldn't reach getkado.app yet.
SITE="yes"
PROJECT="Kado.xcodeproj"
SCHEME="Kado"
DERIVED="build"
# A name of its own, and one per worktree: `make e2e` in another worktree must not find itself
# sharing a device with a run that is busy pinning its clock to 9:41.
SIM_PREFIX="Kado Shots $(basename "$PWD")"

# Read a value out of config.json. One source of truth for the device canvases, shared with the
# uploader, which needs the same table to know which screenshot set a folder belongs in.
config() {
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))
for key in sys.argv[2:]: d = d[key]
print(d)' "$CONFIG" "$@"
}

# What a full run covers. Spelled out rather than read back out of the config, so this stays
# readable in `bash -x` output and works on the bash 3.2 macOS still ships as /bin/bash.
LANGUAGES=(en fr)
DEVICES=(iphone-6.9 ipad-13)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --languages) IFS=' ' read -r -a LANGUAGES <<< "$2"; shift 2 ;;
    --devices)   IFS=' ' read -r -a DEVICES <<< "$2"; shift 2 ;;
    --output)    OUTPUT="$2"; shift 2 ;;
    --framed)    FRAMED="$2"; shift 2 ;;
    --no-site)   SITE=""; shift ;;
    -h|--help)   sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

for device in "${DEVICES[@]}"; do
  type_name="$(config devices "$device" simulator)"
  expected_size="$(config devices "$device" size)"
  sim_name="$SIM_PREFIX $device"

  echo "==> $type_name"
  if ! xcrun simctl list devices | grep -qF "    $sim_name ("; then
    xcrun simctl create "$sim_name" "$type_name" > /dev/null
  fi
  udid="$(xcrun simctl list devices -j | python3 Scripts/find-simulator.py "$sim_name")"

  for language in "${LANGUAGES[@]}"; do
    locale="$(config languages "$language" locale)"
    region="$(config languages "$language" region)"
    destination="$OUTPUT/$locale/$device"

    echo "==> $locale on $device"

    # The *device's* language, not only the app's. `-testLanguage` covers everything the app
    # draws, but the status bar is drawn by the system — and on iPad it carries the date, which
    # would otherwise come out as "Lundi 24 août" over the English screenshots. Written while
    # the device is shut down, because the preference is read at boot.
    #
    # `plutil` rather than `defaults`: `defaults` goes through cfprefsd, which caches the file
    # and writes it back when it feels like it. CoreSimulator writes the same file when it
    # creates and boots a device, and between the two the language can quietly fail to take.
    # `plutil` edits the file on disk and nothing else touches it while the device is off.
    plist="$HOME/Library/Developer/CoreSimulator/Devices/$udid/data/Library/Preferences/.GlobalPreferences.plist"
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    plutil -replace AppleLanguages -json "[\"$language\"]" "$plist"
    plutil -replace AppleLocale -string "${language}_${region}" "$plist"

    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b > /dev/null

    # And check that it took, because the way this fails is a screenshot that looks right until
    # someone reads the status bar. A wrong language here is worth a stopped run.
    actual="$(xcrun simctl spawn "$udid" defaults read -g AppleLanguages | tr -d ' \n()\"')"
    if [[ "$actual" != "$language"* ]]; then
      echo "the simulator came up in '$actual', not '$language'" >&2
      exit 1
    fi

    # Everything else that would otherwise date the picture: the clock, the battery, the signal.
    xcrun simctl status_bar "$udid" override \
      --time "9:41" \
      --dataNetwork wifi --wifiMode active --wifiBars 3 \
      --cellularMode active --cellularBars 4 --operatorName "" \
      --batteryState charged --batteryLevel 100

    # Emptied once, before both passes, because each pass writes only its own shots into it.
    rm -rf "$destination"

    for appearance in light dark; do
      case "$appearance" in
        light) test_case="ScreenshotTests/testCaptureLightScreenshots" ;;
        dark)  test_case="ScreenshotTests/testCaptureDarkScreenshots" ;;
      esac
      bundle="$DERIVED/screenshots-$device-$language-$appearance.xcresult"
      exported="$DERIVED/attachments-$device-$language-$appearance"

      echo "--> $appearance"
      xcrun simctl ui "$udid" appearance "$appearance" > /dev/null

      rm -rf "$bundle" "$exported"

      # Serial, not parallel: parallel testing clones the simulator, and a clone is not the
      # device the status bar and the appearance were pinned on.
      #
      # Deliberately *not* CODE_SIGNING_ALLOWED=NO. Kadō's app target carries the iCloud and
      # App Group entitlements, and an unsigned build has neither, so `CKContainer(identifier:)`
      # traps on the first line of `KadoApp.init()` and every capture "fails" at launch.
      xcodebuild test \
        -project "$PROJECT" -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$udid" \
        -derivedDataPath "$DERIVED" \
        -only-testing:"KadoUITests/$test_case" \
        -testLanguage "$language" -testRegion "$region" \
        -parallel-testing-enabled NO \
        -resultBundlePath "$bundle" \
        -quiet

      xcrun xcresulttool export attachments \
        --path "$bundle" \
        --output-path "$exported" > /dev/null

      # The export names files after the attachment's UUID and records the name the test gave it
      # in a manifest. The name is the whole point — it is what orders the set in App Store
      # Connect — so the manifest is what decides the file names here.
      python3 Scripts/name-screenshots.py "$exported" "$destination" "$expected_size"
    done

    xcrun simctl status_bar "$udid" clear
  done

  # Left behind only by a run that failed, where having the device to look at is the point.
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  xcrun simctl delete "$udid"
done

echo
echo "==> Framing for the listing"
swift Scripts/frame-screenshots.swift "$OUTPUT" "$FRAMED" "$CAPTIONS"

# The site wants the bare captures, not the framed ones, at the canvas its CSS was written
# against. Always regenerated from the committed captures, which are the source of truth for
# both — that is the whole point of doing it here rather than keeping a second set by hand.
if [[ -n "$SITE" ]]; then
  echo
  echo "==> Marketing site captures"
  Scripts/site-screenshots.sh
fi

echo
echo "Captures in $OUTPUT, and the images to upload in $FRAMED."
echo "Next: make listing-check, then make listing (needs ASC_KEY_ID and ASC_ISSUER_ID)."
