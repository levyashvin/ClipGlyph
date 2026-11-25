APP      := ClipGlyph.app
BUILD    := .build/release/ClipGlyph
PREFIX   ?= $(HOME)/Applications
LABEL    := io.github.levyashvin.clipglyph
AGENT    := $(HOME)/Library/LaunchAgents/$(LABEL).plist

.PHONY: build app install uninstall clean

build:
	swift build -c release --disable-sandbox

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp $(BUILD) $(APP)/Contents/MacOS/ClipGlyph
	codesign --force -s - --identifier $(LABEL) $(APP)

# Manual install (without Homebrew): copies to ~/Applications and starts at login.
install: app
	mkdir -p $(PREFIX) $(dir $(AGENT))
	rm -rf $(PREFIX)/$(APP) && cp -R $(APP) $(PREFIX)/
	sed "s|@APP@|$(PREFIX)/$(APP)|" Resources/launchagent.plist > $(AGENT)
	-launchctl bootout gui/$$(id -u)/$(LABEL) 2>/dev/null
	launchctl bootstrap gui/$$(id -u) $(AGENT)

uninstall:
	-launchctl bootout gui/$$(id -u)/$(LABEL) 2>/dev/null
	rm -f $(AGENT)
	rm -rf $(PREFIX)/$(APP)

clean:
	rm -rf .build $(APP)
