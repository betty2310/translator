# All commands agents/humans need. The .xcodeproj is generated; never edit it by hand.
DD := build
XCB := xcodebuild -project Translator.xcodeproj -scheme Translator -destination 'platform=macOS' -derivedDataPath $(DD)
# Release version: `make release VERSION=1.2.0` (CI sets it from the tag). The build number defaults to
# the version, so Sparkle (which compares CFBundleVersion) orders releases by their tags (D21).
VERSION ?=
BUILD ?= $(VERSION)
VERSION_FLAGS := $(if $(VERSION),MARKETING_VERSION=$(VERSION)) $(if $(BUILD),CURRENT_PROJECT_VERSION=$(BUILD))
APP := $(DD)/Build/Products/Release/Translator.app
# Release builds are re-signed with this self-signed certificate (D16): a stable code identity, so macOS keeps
# the Accessibility grant across updates. `SIGN_ID=-` signs ad-hoc (e.g. without the certificate).
SIGN_ID ?= Translator Self-Signed
ENTITLEMENTS := Translator/Resources/Translator.entitlements
INSTALL_DIR ?= /Applications

.PHONY: gen build test run release install clean
gen:
	xcodegen generate
build: gen
	$(XCB) build
test: gen
	$(XCB) test
run: build
	open $(DD)/Build/Products/Debug/Translator.app
# Release build signed with $(SIGN_ID), zipped with ditto (keeps the signature and bundle metadata intact).
release: gen
	$(XCB) -configuration Release build $(VERSION_FLAGS)
	codesign --force --options runtime --entitlements $(ENTITLEMENTS) --sign "$(SIGN_ID)" $(APP)
	codesign --verify --deep --strict $(APP)
	ditto -c -k --keepParent $(APP) $(DD)/Translator$(if $(VERSION),-$(VERSION)).zip
install: release
	-osascript -e 'quit app "Translator"' 2>/dev/null
	rm -rf $(INSTALL_DIR)/Translator.app
	ditto $(APP) $(INSTALL_DIR)/Translator.app
	-xattr -dr com.apple.quarantine $(INSTALL_DIR)/Translator.app 2>/dev/null
	open $(INSTALL_DIR)/Translator.app
clean:
	rm -rf $(DD) Translator.xcodeproj
