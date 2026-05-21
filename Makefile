PROJECT := TakeABreak.xcodeproj
SCHEME := TakeABreak
CONFIGURATION := Release
APP_NAME := TakeABreak.app
DERIVED_DATA := $(HOME)/Library/Developer/Xcode/DerivedData
INSTALL_DIR := /Applications
INSTALLED_APP := $(INSTALL_DIR)/$(APP_NAME)

.PHONY: build install clean

build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" build

install: build
	@APP_PATH="$$(find "$(DERIVED_DATA)" -path "*/Build/Products/$(CONFIGURATION)/$(APP_NAME)" -maxdepth 8 -print 2>/dev/null | tail -1)"; \
	if [ -z "$$APP_PATH" ]; then \
		echo "Could not find built app in $(DERIVED_DATA)"; \
		exit 1; \
	fi; \
	osascript -e 'tell application "$(SCHEME)" to quit' 2>/dev/null || true; \
	sleep 1; \
	pkill -x "$(SCHEME)" 2>/dev/null || true; \
	rm -rf "$(INSTALLED_APP)"; \
	cp -R "$$APP_PATH" "$(INSTALLED_APP)"; \
	xattr -dr com.apple.quarantine "$(INSTALLED_APP)" 2>/dev/null || true; \
	open "$(INSTALLED_APP)"; \
	echo "Installed and launched $(INSTALLED_APP)"

clean:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" clean
