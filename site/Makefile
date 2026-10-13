# Makefile for the Kadō marketing site.
#
# Run from the `site/` directory with `make <target>`, or from the repo
# root with `make -C site <target>`. The GitHub Pages workflow calls
# `make -C site build` before uploading the artifact.

SITE_DIR  := $(CURDIR)
REPO_ROOT := $(abspath $(SITE_DIR)/..)

BRANDING_SRC    := $(REPO_ROOT)/branding
SCREENSHOTS_SRC := $(REPO_ROOT)/docs/screenshots/site

ASSETS          := $(SITE_DIR)/assets
BRANDING_DST    := $(ASSETS)/branding
SCREENSHOTS_DST := $(ASSETS)/screenshots

PORT ?= 8000

.PHONY: build assets clean serve help
.DEFAULT_GOAL := help

build: assets ## Populate site/assets from branding/ and docs/screenshots/

assets:
	@mkdir -p $(BRANDING_DST)
	cp $(BRANDING_SRC)/*.svg $(BRANDING_DST)/
	@# One folder per device (iphone, iphone-duo, ipad), each with en/ and fr/.
	rm -rf $(SCREENSHOTS_DST)
	cp -R $(SCREENSHOTS_SRC) $(SCREENSHOTS_DST)

clean: ## Remove site/assets/
	rm -rf $(ASSETS)

serve: build ## Build and serve the site locally on PORT (default 8000)
	@echo "Kadō site → http://localhost:$(PORT)"
	@cd $(SITE_DIR) && python3 -m http.server $(PORT)

help: ## List available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[1m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
