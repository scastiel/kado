# Building and testing Kadō from the command line.
#
#   make build   build the app for the simulator
#   make test    the unit suite (KadoTests)
#   make e2e     the UI suite (KadoUITests) — drives the app in a simulator
#   make run     install and launch the app on this worktree's simulator
#   make shot    screenshot that simulator
#   make sim-clean  delete this worktree's simulator and any leftover clones
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

.DEFAULT_GOAL := help
.PHONY: help build test e2e run shot sim sim-clean clean

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

clean: ## Remove build output
	@rm -rf $(DERIVED)
