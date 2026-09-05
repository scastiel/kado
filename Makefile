# Building and testing Kadō from the command line.
#
#   make build   build the app for the simulator
#   make test    the unit suite (KadoTests)
#   make e2e     the UI suite (KadoUITests) — drives the app in a simulator
#   make run     install and launch the app on this worktree's simulator
#   make shot    screenshot that simulator
#   make sim-clean  delete this worktree's simulator and any leftover clones
#
#   make screenshots   regenerate the App Store screenshots, in every language
#   make frames        re-wrap those captures for the listing, without recapturing
#   make site-shots    refresh the marketing site's copies from the same captures
#   make listing-check the listing's copy and images, checked without the network
#   make listing-info  what App Store Connect currently holds
#   make listing       upload the copy and the screenshots (needs ASC_ISSUER_ID)
#
#   make archive       build a signed App Store archive
#   make ipa           export that archive as an .ipa
#   make testflight    archive, export and upload a build
#
# XcodeBuildMCP remains the tool of choice from inside Claude Code (see
# CLAUDE.md). This exists for the cases it can't cover: pinning an OS
# version when `OS:latest` won't resolve, and giving each worktree a
# simulator of its own.

# The device *type* each worktree's simulator is created from.
SIMULATOR ?= iPhone 17 Pro

# One simulator per worktree, named after its directory. Two runs must
# never share a device: they would install over each other's app
# container, and XCUITest's parallel clones are named after the device
# they came from, so even the clones would collide. This repo is worked
# on from parallel `.claude/worktrees/` checkouts, so that is the normal
# case rather than the exotic one.
SIM_NAME  ?= Kado $(notdir $(CURDIR))

# XCUITest parallelises by test *class*, cloning a simulator per worker.
# Keep suites small and similar in size, or one long class becomes a pole
# no worker count can shorten. More workers than cores makes things
# slower, not faster — override with WORKERS=n, and lower it when several
# worktrees are running at once, because each run boots WORKERS clones of
# its own.
WORKERS   ?= 3
PARALLEL  := -parallel-testing-enabled YES -maximum-parallel-testing-workers $(WORKERS)

SCHEME      := Kado
PROJECT     := Kado.xcodeproj
BUNDLE_ID   := dev.scastiel.kado
DERIVED     := build
DESTINATION := platform=iOS Simulator,name=$(SIM_NAME)

# Deliberately *not* CODE_SIGNING_ALLOWED=NO, tempting as it is for a
# simulator build. Kadō's app target carries entitlements — iCloud and
# the App Group — and an unsigned build has none of them, so
# `CKContainer(identifier:)` traps on the first line of `KadoApp.init()`
# with EXC_BREAKPOINT and every UI test "fails" at launch for a reason
# that has nothing to do with what it was testing. Simulator builds are
# signed to run locally, which costs nothing and needs no device.

# `ScreenshotTests` lives in the UI bundle but is not a test: it photographs the
# app for the App Store listing, and it asserts nothing a suite would miss.
# `make screenshots` runs it, on devices of its own with a pinned clock, a pinned
# appearance and a pinned language; every other run leaves it alone.
SKIP_SCREENSHOTS := -skip-testing:KadoUITests/ScreenshotTests

# The App Store Connect API key. `Scripts/appstore.py` finds the .p8 itself, by
# key ID, in ~/.appstoreconnect/private_keys — the issuer is the half that can't
# be derived from it, so it comes from the environment: export ASC_ISSUER_ID, or
# pass it on the command line.
ASC_KEY_ID    ?=
ASC_ISSUER_ID ?=

.DEFAULT_GOAL := help
.PHONY: help build test e2e run shot sim sim-clean clean \
	screenshots frames site-shots listing-check listing-info listing \
	archive ipa testflight

help:
	@grep -E '^[a-z0-9-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

# The device is only created, never booted, so this costs nothing on a
# run that already has it. The four leading spaces in the pattern are
# load-bearing: `simctl` indents device names by exactly that much, and a
# leftover clone reads as "Clone 1 of $(SIM_NAME)" — without the indent,
# one of those would pass for the device itself and the real one would
# never be made.
sim: ## Create this worktree's simulator if it doesn't exist yet
	@xcrun simctl list devices | grep -qF '    $(SIM_NAME) (' \
		|| xcrun simctl create '$(SIM_NAME)' '$(SIMULATOR)' >/dev/null

sim-clean: ## Delete this worktree's simulator, and any clones a run left behind
	@for udid in $$(xcrun simctl list devices | grep -F '$(SIM_NAME) (' \
		| sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'); do \
		xcrun simctl shutdown $$udid 2>/dev/null || true; \
		xcrun simctl delete $$udid; \
	done
	@echo "Removed any simulator named $(SIM_NAME)."

build: sim ## Build the app for the simulator
	@xcodebuild build \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		-quiet

# `-only-testing:` rather than `-skip-testing:`, because both bundles in
# this scheme are real suites and each target runs one of them. Splitting
# them keeps `make test` at the couple of seconds it has always been —
# a UI run boots simulators and takes minutes.
test: sim ## Run the unit suite (KadoTests)
	@xcodebuild test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		-only-testing:KadoTests \
		-quiet

e2e: sim ## Run the UI suite (KadoUITests) against the simulator
	@xcodebuild test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		$(PARALLEL) \
		-only-testing:KadoUITests \
		$(SKIP_SCREENSHOTS) \
		-test-timeouts-enabled YES \
		-maximum-test-execution-time-allowance 180 \
		-quiet

# Named rather than `booted`, which is a coin toss the moment anything
# else is running: a test run has clones of its own booted, and `booted`
# would happily install into one of those.
run: build ## Install and launch the app on this worktree's simulator
	@xcrun simctl boot '$(SIM_NAME)' 2>/dev/null || true
	@open -a Simulator
	@xcrun simctl install '$(SIM_NAME)' \
		"$$(find $(DERIVED)/Build/Products -name 'Kado.app' -maxdepth 3 | head -1)"
	@xcrun simctl launch --console-pty '$(SIM_NAME)' $(BUNDLE_ID)

shot: ## Screenshot this worktree's simulator to build/screenshot.png
	@mkdir -p $(DERIVED)
	@xcrun simctl io '$(SIM_NAME)' screenshot $(DERIVED)/screenshot.png
	@echo "$(DERIVED)/screenshot.png"

# The App Store listing.
#
# Two halves that meet in docs/app-store/: `screenshots` photographs the app into
# marketing/, and `listing` sends that plus the copy in metadata/ to App Store
# Connect. Neither needs Xcode open, and neither touches the developer's own
# habits — the screenshot run redirects SwiftData to a throwaway file.

screenshots: ## Regenerate the App Store screenshots, in every language
	@Scripts/screenshots.sh

# The framing is a second pass over the captures, so a headline or a colour can be
# changed without photographing the app again — seconds instead of half an hour.
frames: ## Re-wrap the existing captures for the listing
	@swift Scripts/frame-screenshots.swift \
		docs/app-store/screenshots docs/app-store/marketing docs/app-store/captions.json
	@Scripts/site-screenshots.sh

# Only the site's copies, when the captures haven't changed and the frames don't need redrawing.
site-shots: ## Refresh the marketing site's screenshots from the captures
	@Scripts/site-screenshots.sh

listing-check: ## Check the listing's copy and images without the network
	@python3 Scripts/appstore.py check

listing-info: ## Show what App Store Connect currently holds
	@$(MAKE) --no-print-directory asc-credentials
	@ASC_KEY_ID=$(ASC_KEY_ID) ASC_ISSUER_ID=$(ASC_ISSUER_ID) python3 Scripts/appstore.py info

# The local check runs first, so a subtitle one character over costs a second
# rather than a round trip and a rejection days later. `--dry-run` on the same
# command prints exactly what would change and sends nothing.
listing: listing-check ## Upload the copy and the screenshots to App Store Connect
	@$(MAKE) --no-print-directory asc-credentials
	@ASC_KEY_ID=$(ASC_KEY_ID) ASC_ISSUER_ID=$(ASC_ISSUER_ID) python3 Scripts/appstore.py all $(ARGS)

.PHONY: asc-credentials
asc-credentials:
	@test -n "$(ASC_KEY_ID)" -a -n "$(ASC_ISSUER_ID)" || { \
		echo "ASC_KEY_ID and ASC_ISSUER_ID must both be set. The issuer is shown above"; \
		echo "the key list at https://appstoreconnect.apple.com/access/integrations/api,"; \
		echo "and the key's .p8 belongs in ~/.appstoreconnect/private_keys/."; \
		echo "Re-run as: make listing ASC_KEY_ID=<id> ASC_ISSUER_ID=<uuid>"; \
		exit 1; }

# Release. The archive and the .ipa are separate steps so a rejected upload can be retried
# without rebuilding — an archive is minutes, an upload is seconds.
ARCHIVE := $(DERIVED)/Kado.xcarchive
EXPORT  := $(DERIVED)/export
IPA     := $(EXPORT)/Kado.ipa

# Signing assets are issued on demand through the same API key the listing uses, so a machine
# without a distribution certificate can still archive. That *creates* account-level assets the
# first time — see docs/app-store/README.md before running it on a fresh machine.
AUTH := -allowProvisioningUpdates \
	-authenticationKeyPath $(HOME)/.appstoreconnect/private_keys/AuthKey_$(ASC_KEY_ID).p8 \
	-authenticationKeyID $(ASC_KEY_ID) \
	-authenticationKeyIssuerID $(ASC_ISSUER_ID)

archive: ## Build a signed App Store archive
	@$(MAKE) --no-print-directory asc-credentials
	@xcodebuild archive \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE) \
		$(AUTH) \
		-quiet
	@echo "Archived $$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' $(ARCHIVE)/Info.plist)" \
		"($$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' $(ARCHIVE)/Info.plist)) to $(ARCHIVE)."

ipa: archive ## Export that archive as an App Store .ipa
	@rm -rf $(EXPORT)
	@xcodebuild -exportArchive \
		-archivePath $(ARCHIVE) \
		-exportOptionsPlist ExportOptions.plist \
		-exportPath $(EXPORT) \
		$(AUTH) \
		-quiet
	@echo "$(IPA)"

# The credential check comes before the build rather than after it, so a missing issuer costs
# a second instead of the minutes an archive takes. The build number must exceed everything
# App Store Connect has already seen — it rejects a duplicate after the upload, not before.
testflight: ## Archive, export and upload a build (needs ASC_KEY_ID and ASC_ISSUER_ID)
	@$(MAKE) --no-print-directory asc-credentials
	@$(MAKE) ipa
	@xcrun altool --upload-app --type ios --file "$(IPA)" \
		--apiKey $(ASC_KEY_ID) --apiIssuer $(ASC_ISSUER_ID)
	@echo "Uploaded. App Store Connect takes a few minutes to finish processing the build."

clean: ## Remove build output
	@rm -rf $(DERIVED)
