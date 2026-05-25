# Klck — metronome for macOS
# Requires: Swift 6+ toolchain (Xcode or Command Line Tools). No full Xcode needed.

APP      := Klck.app
BIN_REL  := .build/release/Klck
BIN_DBG  := .build/debug/Klck

.DEFAULT_GOAL := app

# Android targets — use the Gradle wrapper checked in under android/. The
# Android Studio bundled JDK at /Applications/Android Studio.app/... is used
# automatically; override JAVA_HOME on the command line to point elsewhere.
ANDROID_DIR     := android
ANDROID_JAVA    ?= /Applications/Android Studio.app/Contents/jbr/Contents/Home
ANDROID_GRADLE  := JAVA_HOME="$(ANDROID_JAVA)" $(ANDROID_DIR)/gradlew
ANDROID_APK_DBG := $(ANDROID_DIR)/app/build/outputs/apk/debug/app-debug.apk
ANDROID_APK_REL := $(ANDROID_DIR)/app/build/outputs/apk/release/app-release-unsigned.apk
ANDROID_PKG     := com.klck.metronome

.PHONY: help build debug app run run-console release clean rebuild check test version ios-project
.PHONY: android-debug android-release android-install android-uninstall android-launch android-logcat android-emulator android-clean

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

test: ## Run the layout smoke test suite
	swift test

ios-project: ## Generate Klck.xcodeproj for the iOS app (needs Xcode + xcodegen)
	@command -v xcodegen >/dev/null || { echo "xcodegen not found — run: brew install xcodegen"; exit 1; }
	xcodegen generate
	@echo "Generated Klck.xcodeproj — open it in Xcode to build/run on iOS."

# ---- Android ----------------------------------------------------------------

android-debug: ## Build the Android debug APK
	$(ANDROID_GRADLE) :app:assembleDebug
	@echo "Debug APK: $(ANDROID_APK_DBG)"

android-release: ## Build the (unsigned) Android release APK
	$(ANDROID_GRADLE) :app:assembleRelease
	@echo "Unsigned release APK: $(ANDROID_APK_REL)"

android-install: android-debug ## Install the debug APK on a connected device or running emulator
	~/Library/Android/sdk/platform-tools/adb install -r $(ANDROID_APK_DBG)

android-uninstall: ## Remove Klck from a connected device or emulator
	~/Library/Android/sdk/platform-tools/adb uninstall $(ANDROID_PKG)

android-launch: ## Force-stop and (re)launch Klck on the connected device
	~/Library/Android/sdk/platform-tools/adb shell am force-stop $(ANDROID_PKG)
	~/Library/Android/sdk/platform-tools/adb shell am start -n $(ANDROID_PKG)/.MainActivity

android-logcat: ## Tail logcat filtered to Klck
	~/Library/Android/sdk/platform-tools/adb logcat --pid=$$(~/Library/Android/sdk/platform-tools/adb shell pidof $(ANDROID_PKG))

android-emulator: ## Boot the first AVD (use `emulator -list-avds` to see what's available)
	@AVD=$$(~/Library/Android/sdk/emulator/emulator -list-avds | head -1); \
	if [ -z "$$AVD" ]; then echo "No AVD configured — create one in Android Studio first"; exit 1; fi; \
	echo "Booting $$AVD"; \
	~/Library/Android/sdk/emulator/emulator @$$AVD -no-snapshot-save -netdelay none -netspeed full &

android-clean: ## Clean Android build artifacts
	$(ANDROID_GRADLE) :app:clean

# ---- Misc -------------------------------------------------------------------

version: ## Print the Swift toolchain version
	@swift --version

clean: ## Remove build artifacts and the app bundle
	swift package clean
	rm -rf .build $(APP)

rebuild: clean app ## Clean and rebuild the app bundle
