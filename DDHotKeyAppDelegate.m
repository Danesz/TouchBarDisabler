/*
 DDHotKey -- DDHotKeyAppDelegate.m
 
 Copyright (c) Dave DeLong <http://www.davedelong.com>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the author(s) or copyright holder(s) be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.
 */

#import "DDHotKeyAppDelegate.h"
#import "DDHotKeyCenter.h"
#import <Carbon/Carbon.h>
//#import "ddc.c"
#include <IOKit/IOKitLib.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <ApplicationServices/ApplicationServices.h>
#include <IOKit/i2c/IOI2CInterface.h>
#include <CoreFoundation/CoreFoundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioServices.h>
#import "LaunchAtLoginController.h"

const int kMaxDisplays = 16;
const CFStringRef kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);
@interface DDHotKeyAppDelegate() {
    BOOL touchBarDisabled;
    NSMenu *menu;
    NSMenuItem *toggler;
}
@end
@implementation DDHotKeyAppDelegate

@synthesize window, output;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self registerHotkeys];
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.title = @"T";
    
    // The image that will be shown in the menu bar, a 16x16 black png works best
//    _statusItem.image = [NSImage imageNamed:@"bar-logo"];
    
    // The highlighted image, use a white version of the normal image
//    _statusItem.alternateImage = [NSImage imageNamed:@"bar-logo-alt"];
    _statusItem.highlightMode = YES;
    
    menu = [[NSMenu alloc] init];
    toggler = [[NSMenuItem alloc] initWithTitle:@"Disable Touch Bar" action:@selector(toggleTouchBar:) keyEquivalent:@""];
    [menu addItem:toggler];

    NSNumber *num = [[NSUserDefaults standardUserDefaults] objectForKey:@"touchBarDisabled"];
    if (num != nil) {
        touchBarDisabled = [num boolValue];
        if (touchBarDisabled) {
            [self disableTouchBar];
        } else {
//            [self enableTouchBar];
        }
    }
    
//    [menu addItemWithTitle:@"Advanced Preferences" action:@selector(showPreferencesPane:) keyEquivalent:@""];
    
    [menu addItem:[NSMenuItem separatorItem]]; // A thin grey line
    [menu addItemWithTitle:@"Quit Touch Bar Disabler" action:@selector(terminate:) keyEquivalent:@""];
    _statusItem.menu = menu;
    
    LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
    [launchController setLaunchAtLogin:YES];
}

- (void)enableTouchBar {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[ @"-c", @"defaults write com.apple.touchbar.agent PresentationModeGlobal -string app;launchctl load /System/Library/LaunchAgents/com.apple.controlstrip.plist;launchctl load /System/Library/LaunchAgents/com.apple.touchbar.agent.plist;launchctl unload /System/Library/LaunchAgents/com.apple.touchbar.agent.plist;launchctl load /System/Library/LaunchAgents/com.apple.touchbar.agent.plist;pkill \"Touch Bar agent\";killall Dock"]];
    [task launch];
    touchBarDisabled = NO;
    toggler.title = @"Disable Touch Bar";
    [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:@"touchBarDisabled"];
}

- (void)disableTouchBar {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [window makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
    [task setArguments:@[ @"-c", @"defaults write com.apple.touchbar.agent PresentationModeGlobal -string fullControlStrip;launchctl unload /System/Library/LaunchAgents/com.apple.controlstrip.plist;killall ControlStrip;launchctl unload /System/Library/LaunchAgents/com.apple.touchbar.agent.plist;launchctl unload /System/Library/LaunchDaemons/com.apple.touchbar.user-device.plist;pkill \"Touch Bar agent\""]];
    [task launch];
    task.terminationHandler = ^(NSTask *task){
        [window setIsVisible:NO];
    };
    touchBarDisabled = YES;
    toggler.title = @"Enable Touch Bar";
    [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"touchBarDisabled"];

}

- (void)toggleTouchBar:(id)sender {
    if (touchBarDisabled) {
        [self enableTouchBar];
    } else {
        [self disableTouchBar];
    }
}


- (void)showPreferencesPane:(id)sender {
    
}

- (void) addOutput:(NSString *)newOutput {
//	NSString * current = [output string];
//	[output setString:[current stringByAppendingFormat:@"%@\n", newOutput]];
//	[output scrollRangeToVisible:NSMakeRange([[output string] length], 0)];
}

- (void) hotkeyWithEvent:(NSEvent *)hkEvent {
	[self addOutput:[NSString stringWithFormat:@"Firing -[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
	[self addOutput:[NSString stringWithFormat:@"Hotkey event: %@", hkEvent]];
    float curr = [self get_brightness];
//    NSLog(@"%f", [self get_brightness]);
    short keyCode = hkEvent.keyCode;
    switch (keyCode) {
        case kVK_ANSI_1:
            [self set_brightness:curr - 0.1];
            break;
        case kVK_ANSI_2:
            [self set_brightness:curr + 0.1];
            break;
        case kVK_ANSI_3:
            [self toggleExpose];
            break;
        case kVK_ANSI_4:
            [self toggleDashboard];
            break;
        case kVK_ANSI_5:
            break;
        case kVK_ANSI_6:
            break;
        case kVK_ANSI_7:
            break;
        case kVK_ANSI_8:
            break;
        case kVK_ANSI_9:
            break;
        case kVK_ANSI_0:
            break;
        default:
            break;
    }
    if (hkEvent.keyCode == kVK_ANSI_1) {
        
    } else if (hkEvent.keyCode == kVK_ANSI_2) {
        
    } else if (hkEvent.keyCode == kVK_ANSI_8) {
        [self muteVolume];
    } else if (keyCode == kVK_ANSI_9) {
        [self decreaseVolume];
    } else if (keyCode == kVK_ANSI_0) {
        [self increaseVolume];
    } else {
        
    }
}

- (void)toggleExpose {
    if(![[NSWorkspace sharedWorkspace] launchApplication:@"Mission Control"])
        NSLog(@"Mission Control failed to launch");
}

- (void)toggleDashboard {
    if(![[NSWorkspace sharedWorkspace] launchApplication:@"Dashboard"])
        NSLog(@"Dashboard failed to launch");
}


- (void) hotkeyWithEvent:(NSEvent *)hkEvent object:(id)anObject {
	[self addOutput:[NSString stringWithFormat:@"Firing -[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
	[self addOutput:[NSString stringWithFormat:@"Hotkey event: %@", hkEvent]];
	[self addOutput:[NSString stringWithFormat:@"Object: %@", anObject]];
}

- (void)decreaseVolume {
    AudioDeviceID deviceID = GetDefaultAudioDevice();
    if (GetMute(deviceID) == YES) {
        SetMute(deviceID, NO);
    } else {
        Float32 currentVolume = getCurrentVolume(deviceID);
        Float32 targetVolume = currentVolume - 0.1;
        
//        NSLog(@"currentVolume is: %f", currentVolume);
        setVolume(deviceID, targetVolume);
    }
}


- (void)increaseVolume {
    AudioDeviceID deviceID = GetDefaultAudioDevice();
    if (GetMute(deviceID) == YES) {
        SetMute(deviceID, NO);
    } else {
        Float32 currentVolume = getCurrentVolume(deviceID);
        Float32 targetVolume = currentVolume + 0.1;
        NSLog(@"currentVolume is: %f", currentVolume);
        setVolume(deviceID, targetVolume);
    }
}

- (void)muteVolume {
    AudioDeviceID deviceID = GetDefaultAudioDevice();
    SetMute(deviceID, 1);
}

void setVolume(AudioDeviceID device, Float32 volume) {
    Float32 newVolume = volume;
    
    AudioObjectPropertyAddress addressLeft = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        1 /*LEFT_CHANNEL*/
    };
    
    OSStatus err;
    err = AudioObjectSetPropertyData(device, &addressLeft, 0, NULL, sizeof(volume), &newVolume);
    if (err) {
        NSLog(@"something went wrong on the left side! %d", err);
    }
    
    AudioObjectPropertyAddress addressRight = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        2 /*RIGHT_CHANNEL*/
    };
    err = AudioObjectSetPropertyData(device, &addressRight, 0, NULL, sizeof(volume), &newVolume);
    if (err) {
        NSLog(@"something went wrong on the right side! %d", err);
    }
}


void SetMute(AudioDeviceID device, UInt32 mute) {
    UInt32 muteVal = (UInt32)mute;
    
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyMute,
        kAudioDevicePropertyScopeOutput,
        0
    };
    
    OSStatus err;
    err = AudioObjectSetPropertyData(device, &address, 0, NULL, sizeof(UInt32), &muteVal);
    if (err)
    {
        NSString * message;
        NSLog(@"error while %@muting: %@", (mute ? @"" : @"un"), message);
    }
}

AudioDeviceID GetDefaultAudioDevice()
{
    OSStatus err;
    AudioDeviceID device = 0;
    UInt32 size = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    
    err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &device);
    if (err)
    {
        NSLog(@"could not get default audio output device");
    }
    
    return device;
}

Float32 getCurrentVolume(AudioDeviceID device)
{
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
    
    if(!AudioHardwareServiceHasProperty(device, &propertyAddress)) {
        // An error occurred
    }
    Float32 volume;
    UInt32 dataSize = sizeof(volume);
    OSStatus result = AudioHardwareServiceGetPropertyData(device, &propertyAddress, 0, NULL, &dataSize, &volume);
    
    if(kAudioHardwareNoError != result) {
        
    }
    return volume;
}

BOOL GetMute(AudioDeviceID device)
{
    UInt32 size = sizeof(UInt32);
    UInt32 muteVal;
    
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyMute,
        kAudioDevicePropertyScopeOutput,
        0
    };
    
    OSStatus err;
    err = AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &muteVal);
    if (err)
    {
        NSString * message;
        /* big switch to set message */
        NSLog(@"error while getting mute status: %@", message);
    }
    
    return (BOOL)muteVal;
}


- (float) get_brightness {
    CGDirectDisplayID display[kMaxDisplays];
    CGDisplayCount numDisplays;
    CGDisplayErr err;
    err = CGGetActiveDisplayList(kMaxDisplays, display, &numDisplays);
    
    if (err != CGDisplayNoErr)
        printf("cannot get list of displays (error %d)\n",err);
    for (CGDisplayCount i = 0; i < numDisplays; ++i) {
        
        
        CGDirectDisplayID dspy = display[i];
        CFDictionaryRef originalMode = CGDisplayCurrentMode(dspy);
        if (originalMode == NULL)
            continue;
        io_service_t service = CGDisplayIOServicePort(dspy);
        
        float brightness;

        err = IODisplayGetFloatParameter(service, kNilOptions, kDisplayBrightness, &brightness);
        if (err != kIOReturnSuccess) {
            fprintf(stderr,
                    "failed to get brightness of display 0x%x (error %d)",
                    (unsigned int)dspy, err);
            continue;
        }
        return brightness;
    }
    return -1.0;//couldn't get brightness for any display
}

- (void) set_brightness:(float) new_brightness {
    CGDirectDisplayID display[kMaxDisplays];
    CGDisplayCount numDisplays;
    CGDisplayErr err;
    err = CGGetActiveDisplayList(kMaxDisplays, display, &numDisplays);
    
    if (err != CGDisplayNoErr)
        printf("cannot get list of displays (error %d)\n",err);
    for (CGDisplayCount i = 0; i < numDisplays; ++i) {
        
        
        CGDirectDisplayID dspy = display[i];
        CFDictionaryRef originalMode = CGDisplayCurrentMode(dspy);
        if (originalMode == NULL)
            continue;
        io_service_t service = CGDisplayIOServicePort(dspy);
        
        float brightness;
        err= IODisplayGetFloatParameter(service, kNilOptions, kDisplayBrightness,
                                        &brightness);
        if (err != kIOReturnSuccess) {
            fprintf(stderr,
                    "failed to get brightness of display 0x%x (error %d)",
                    (unsigned int)dspy, err);
            continue;
        }
        
        err = IODisplaySetFloatParameter(service, kNilOptions, kDisplayBrightness,
                                         new_brightness);
        if (err != kIOReturnSuccess) {
            fprintf(stderr,
                    "Failed to set brightness of display 0x%x (error %d)",
                    (unsigned int)dspy, err);
            continue;
        }
        
        if(brightness > 0.0){
        } else {
        }
    }
}

- (void) registerHotkeys {
	[self addOutput:@"Attempting to register hotkey for example 1"];
	DDHotKeyCenter *c = [DDHotKeyCenter sharedHotKeyCenter];
    DDHotKey* res1 = [c registerHotKeyWithKeyCode:kVK_ANSI_1 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res2 = [c registerHotKeyWithKeyCode:kVK_ANSI_2 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res3 = [c registerHotKeyWithKeyCode:kVK_ANSI_3 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res4 = [c registerHotKeyWithKeyCode:kVK_ANSI_4 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res5 = [c registerHotKeyWithKeyCode:kVK_ANSI_5 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res6 = [c registerHotKeyWithKeyCode:kVK_ANSI_6 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res7 = [c registerHotKeyWithKeyCode:kVK_ANSI_7 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res8 = [c registerHotKeyWithKeyCode:kVK_ANSI_8 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res9 = [c registerHotKeyWithKeyCode:kVK_ANSI_9 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res0 = [c registerHotKeyWithKeyCode:kVK_ANSI_0 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];

    if (!res1 || !res2 ||!res3 ||!res4 ||!res5 ||!res6 ||!res7 ||!res8||!res9 || !res0) {
        [self addOutput:@"Unable to register hotkeys"];
    } else {
        [self addOutput:@"Registered hotkeys"];
        [self addOutput:[NSString stringWithFormat:@"Registered: %@", [c registeredHotKeys]]];
	}
}

@end
