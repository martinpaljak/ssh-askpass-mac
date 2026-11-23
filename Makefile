# SPDX-FileCopyrightText: 2026 Martin Paljak
# SPDX-License-Identifier: BSD-2-Clause
#
# make          build build/Release/ssh-askpass.app, signed with the
#               Developer ID Application certificate of TEAMID: hardened
#               runtime and a secure timestamp, as notarization needs
# make TEAMID=XXXXXXXXXX   the same with another team's certificate
# make TEAMID=-            signed ad hoc, no certificate needed
# make install  copy the app to /Applications (same TEAMID rules)
# make verify   check the signature and show the designated requirement
# make reuse    check SPDX license and copyright information (reuse lint)
# make clean

TEAMID ?= 727L5NLWT4
APP = build/Release/ssh-askpass.app
DEST = /Applications

# The keychain remembers "Always Allow" by the designated requirement. Ad hoc,
# that is the hash of this build; signed, it is the bundle ID and the team ID,
# so it lasts across rebuilds.
ifneq ($(TEAMID),-)
SIGNING = CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=$(TEAMID) \
	CODE_SIGN_IDENTITY="Developer ID Application" \
	ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS=--timestamp
endif

# xcodebuild needs full Xcode, also when xcode-select points to the CLT.
ifneq (,$(findstring CommandLineTools,$(shell xcode-select -p 2>/dev/null)))
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
endif

.PHONY: all build install verify reuse clean

all: build

build:
	xcodebuild -project ssh-askpass.xcodeproj -configuration Release SYMROOT=build $(SIGNING)

install: build
	rm -rf "$(DEST)/ssh-askpass.app"
	ditto "$(APP)" "$(DEST)/ssh-askpass.app"

verify:
	codesign --verify --strict --verbose=2 "$(APP)"
	codesign --display --verbose=2 "$(APP)" 2>&1 | grep -E '^(Authority|TeamIdentifier|Timestamp|Signature|CodeDirectory)'
	codesign --display --requirements - "$(APP)" 2>&1 | grep designated

reuse:
	reuse --no-multiprocessing lint

clean:
	rm -rf build
