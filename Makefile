# Klck — metronome for macOS
# Requires: Swift 6+ toolchain (Xcode or Command Line Tools). No full Xcode needed.

APP      := Klck.app
BIN_REL  := .build/release/Klck
BIN_DBG  := .build/debug/Klck

.DEFAULT_GOAL := app

.PHONY: help build debug app run run-console release clean rebuild check version ios-project

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

build: ## Compile a release binary
	swift build -c release

debug: ## Compile a debug binary
	swift build -c debug

app: build ## Build and assemble Klck.app (default)
	@./build_app.sh release

run: app ## Build the app and launch it
	open $(APP)

run-console: app ## Launch the app with console output in this terminal
	./$(APP)/Contents/MacOS/Klck

release: clean app ## Clean, then produce a fresh Klck.app
	@echo "Release bundle ready: $(APP)"

check: ## Type-check / build without bundling
	swift build -c debug

ios-project: ## Generate Klck.xcodeproj for the iOS app (needs Xcode + xcodegen)
	@command -v xcodegen >/dev/null || { echo "xcodegen not found — run: brew install xcodegen"; exit 1; }
	xcodegen generate
	@echo "Generated Klck.xcodeproj — open it in Xcode to build/run on iOS."

version: ## Print the Swift toolchain version
	@swift --version

clean: ## Remove build artifacts and the app bundle
	swift package clean
	rm -rf .build $(APP)

rebuild: clean app ## Clean and rebuild the app bundle
