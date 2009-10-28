SDKVER=2.0
SDK=/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(SDKVER).sdk

CC=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/arm-apple-darwin9-gcc-4.2.1
CPP=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/arm-apple-darwin9-g++-4.2.1

LD=$(CC)

LDFLAGS += -framework CoreFoundation
LDFLAGS += -framework Foundation
LDFLAGS += -framework UIKit
LDFLAGS += -framework CoreGraphics
//LDFLAGS += -framework AddressBookUI
//LDFLAGS += -framework AddressBook
//LDFLAGS += -framework QuartzCore
LDFLAGS += -framework GraphicsServices
LDFLAGS += -framework CoreSurface
//LDFLAGS += -framework CoreAudio
//LDFLAGS += -framework Celestial
//LDFLAGS += -framework AudioToolbox
//LDFLAGS += -framework WebCore
//LDFLAGS += -framework WebKit
//LDFLAGS += -framework SystemConfiguration
//LDFLAGS += -framework CFNetwork
//LDFLAGS += -framework MediaPlayer
//LDFLAGS += -framework OpenGLES
//LDFLAGS += -framework OpenAL

LDFLAGS += -lsqlite3

LDFLAGS += -L"$(SDK)/usr/lib"
LDFLAGS += -F"$(SDK)/System/Library/Frameworks"
LDFLAGS += -F"$(SDK)/System/Library/PrivateFrameworks"

# Make a bundle
# Comment this out to make a runnable executable
LDFLAGS += -bundle


CFLAGS += -I"/Developer/Platforms/iPhoneOS.platform/Developer/usr/lib/gcc/arm-apple-darwin9/4.2.1/include/"
CFLAGS += -I"$(SDK)/usr/include"
CFLAGS += -I"$(SDK)/usr/include"
CFLAGS += -I"/Developer/Platforms/iPhoneOS.platform/Developer/usr/include/"
CFLAGS += -I"/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator$(SDKVER).sdk/usr/include"
CFLAGS += -DDEBUG -std=c99
CFLAGS += -Diphoneos_version_min=2.0
CFLAGS += -F"$(SDK)/System/Library/Frameworks"
CFLAGS += -F"$(SDK)/System/Library/PrivateFrameworks"
CFLAGS += -Wall

LDFLAGS += -framework GraphicsServices


CPPFLAGS=$CFLAGS



BUNDLE=TodoPlugin.bundle
THEME=TodoLockInfo.theme
ID=cx.ath.the-kenny.TodoPlugin

IP=192.168.2.111

TodoPlugin: TodoPlugin.o
	$(LD) $(LDFLAGS) -o TodoPlugin TodoPlugin.o

TodoPlugin.o: TodoPlugin.m
	$(CPP) -c $(CFLAGS) -o TodoPlugin.o TodoPlugin.m 

$(BUNDLE): 
	mkdir $(BUNDLE)

$(THEME):
	mkdir $(THEME)
	mkdir $(THEME)/Bundles/
	mkdir $(THEME)/Bundles/$(ID)

install: TodoPlugin $(BUNDLE) $(THEME)
	cp Info.plist $(BUNDLE)/
	cp Preferences.plist $(BUNDLE)/
	export CODESIGN_ALLOCATE=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/codesign_allocate; ./ldid_intel -S TodoPlugin
	cp TodoPlugin $(BUNDLE)/
	cp icon.png $(BUNDLE)/section_icon.png

	cp plugin.js $(THEME)/Bundles/$(ID)/
	cp plugin.css $(THEME)/Bundles/$(ID)/
	cp things.png $(THEME)/Bundles/$(ID)/

deviceinstall: install
	scp -r $(BUNDLE) root@$(IP):/Library/LockInfo/Plugins/
	#scp -r $(THEME) root@$(IP):/Library/Themes/

clean: 
	rm *.o TodoPlugin $(BUNDLE)/*
	rmdir $(BUNDLE)
	rm -r $(THEME)