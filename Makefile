PROJECT := Breathlet.xcodeproj
SCHEME := Breathlet
CONFIGURATION := Release
APP_NAME := Breathlet.app
PROCESS_NAME := Breathlet
DERIVED_DATA := $(HOME)/Library/Developer/Xcode/DerivedData
INSTALL_DIR := /Applications
INSTALLED_APP := $(INSTALL_DIR)/$(APP_NAME)
DIST_DIR := dist
DMG_NAME := Breathlet.dmg
DMG_PATH := $(DIST_DIR)/$(DMG_NAME)
DMG_STAGING := $(DIST_DIR)/dmg-root

.PHONY: build install dmg clean

build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" build

install: build
	@APP_PATH="$$(xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -showBuildSettings 2>/dev/null | sed -n 's/^[[:space:]]*TARGET_BUILD_DIR = //p' | tail -1)/$(APP_NAME)"; \
	if [ -z "$$APP_PATH" ]; then \
		echo "Could not determine built app path"; \
		exit 1; \
	fi; \
	if [ ! -d "$$APP_PATH" ]; then \
		echo "Could not find built app at $$APP_PATH"; \
		exit 1; \
	fi; \
	osascript -e 'tell application "$(PROCESS_NAME)" to quit' 2>/dev/null || true; \
	sleep 1; \
	pkill -x "$(PROCESS_NAME)" 2>/dev/null || true; \
	rm -rf "$(INSTALLED_APP)"; \
	cp -R "$$APP_PATH" "$(INSTALLED_APP)"; \
	xattr -dr com.apple.quarantine "$(INSTALLED_APP)" 2>/dev/null || true; \
	open "$(INSTALLED_APP)"; \
	echo "Installed and launched $(INSTALLED_APP)"

dmg: build
	@APP_PATH="$$(xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -showBuildSettings 2>/dev/null | sed -n 's/^[[:space:]]*TARGET_BUILD_DIR = //p' | tail -1)/$(APP_NAME)"; \
	if [ -z "$$APP_PATH" ]; then \
		echo "Could not determine built app path"; \
		exit 1; \
	fi; \
	if [ ! -d "$$APP_PATH" ]; then \
		echo "Could not find built app at $$APP_PATH"; \
		exit 1; \
	fi; \
	rm -rf "$(DMG_STAGING)" "$(DMG_PATH)"; \
	mkdir -p "$(DMG_STAGING)"; \
	ditto "$$APP_PATH" "$(DMG_STAGING)/$(APP_NAME)"; \
	ln -s /Applications "$(DMG_STAGING)/Applications"; \
	hdiutil create -volname "$(PROCESS_NAME)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_PATH)"; \
	rm -rf "$(DMG_STAGING)"; \
	echo "Created $(DMG_PATH)"

clean:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" clean
	rm -rf "$(DIST_DIR)"
