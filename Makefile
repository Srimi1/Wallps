APP := Wallps
SCHEME := Wallps
CONFIG ?= Release
# Kept outside the repo: codesign rejects the extended attributes that iCloud
# Drive and other synced folders attach to build products.
DERIVED ?= $(HOME)/Library/Developer/Xcode/DerivedData/Wallps-build

.PHONY: bootstrap generate build run test dmg clean

bootstrap:
	@command -v xcodegen >/dev/null || brew install xcodegen
	xcodegen generate

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(DERIVED) build

test: generate
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) test

run: build
	open "$(DERIVED)/Build/Products/$(CONFIG)/$(APP).app"

dmg: build
	./scripts/build_dmg.sh

clean:
	rm -rf $(DERIVED) $(APP).xcodeproj build

