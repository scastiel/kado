# Makefile for the Kadō marketing site.
#
# Run from the `site/` directory with `make <target>`, or from the repo
# root with `make -C site <target>`. The GitHub Pages workflow calls
# `make -C site build` before uploading the artifact.

SITE_DIR  := $(CURDIR)
REPO_ROOT := $(abspath $(SITE_DIR)/..)

BRANDING_SRC    := $(REPO_ROOT)/branding
SCREENSHOTS_SRC := $(REPO_ROOT)/docs/screenshots/iphone-67-appstore

ASSETS             := $(SITE_DIR)/assets
BRANDING_DST       := $(ASSETS)/branding
SCREENSHOTS_EN_DST := $(ASSETS)/screenshots/en
SCREENSHOTS_FR_DST := $(ASSETS)/screenshots/fr

PORT ?= 8000

.PHONY: build assets clean serve help
.DEFAULT_GOAL := help

build: assets ## Populate site/assets from branding/ and docs/screenshots/

assets:
	@mkdir -p $(BRANDING_DST) $(SCREENSHOTS_EN_DST) $(SCREENSHOTS_FR_DST)
	cp $(BRANDING_SRC)/*.svg $(BRANDING_DST)/
	cp $(SCREENSHOTS_SRC)/en/*.png $(SCREENSHOTS_EN_DST)/
	cp $(SCREENSHOTS_SRC)/fr/*.png $(SCREENSHOTS_FR_DST)/

clean: ## Remove site/assets/
	rm -rf $(ASSETS)

serve: build ## Build and serve the site locally on PORT (default 8000)
	@echo "Kadō site → http://localhost:$(PORT)"
	@cd $(SITE_DIR) && python3 -m http.server $(PORT)

help: ## List available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[1m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
