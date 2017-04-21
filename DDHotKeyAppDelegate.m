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


const int kMaxDisplays = 16;
const CFStringRef kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);

@implementation DDHotKeyAppDelegate

@synthesize window, output;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self registerExample1:nil];
	// Insert code here to initialize your application
}

- (void) addOutput:(NSString *)newOutput {
	NSString * current = [output string];
	[output setString:[current stringByAppendingFormat:@"%@\n", newOutput]];
	[output scrollRangeToVisible:NSMakeRange([[output string] length], 0)];
}

- (void) hotkeyWithEvent:(NSEvent *)hkEvent {
	[self addOutput:[NSString stringWithFormat:@"Firing -[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
	[self addOutput:[NSString stringWithFormat:@"Hotkey event: %@", hkEvent]];
    float curr = [self get_brightness];
    NSLog(@"%f", [self get_brightness]);
    if (hkEvent.keyCode == kVK_ANSI_1) {
        [self set_brightness:curr - 0.1];
    } else if (hkEvent.keyCode == kVK_ANSI_2) {
        [self set_brightness:curr + 0.1];
    } else if (hkEvent.keyCode == kVK_ANSI_8) {
        [self muteVolume];
    }
    
}

- (void) hotkeyWithEvent:(NSEvent *)hkEvent object:(id)anObject {
	[self addOutput:[NSString stringWithFormat:@"Firing -[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
	[self addOutput:[NSString stringWithFormat:@"Hotkey event: %@", hkEvent]];
	[self addOutput:[NSString stringWithFormat:@"Object: %@", anObject]];
}


- (void)muteVolume {
    AudioDeviceID deviceID = GetDefaultAudioDevice();
    SetMute(deviceID, YES);
}

void SetMute(AudioDeviceID device, BOOL mute)
{
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
        /* big switch statement on err to set message */
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
    err = AudioObjectGetPropertyData(device,
                                     &address,
                                     0,
                                     NULL,
                                     &size,
                                     &muteVal);
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

- (IBAction) registerExample1:(id)sender {
	[self addOutput:@"Attempting to register hotkey for example 1"];
	DDHotKeyCenter *c = [DDHotKeyCenter sharedHotKeyCenter];
    DDHotKey* res1 = [c registerHotKeyWithKeyCode:kVK_ANSI_1 modifierFlags:NSEventModifierFlagFunction target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res2 = [c registerHotKeyWithKeyCode:kVK_ANSI_2 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res3 = [c registerHotKeyWithKeyCode:kVK_ANSI_8 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];

	if (!res1 || !res2) {
		[self addOutput:@"Unable to register hotkey for example 1"];
	} else {
		[self addOutput:@"Registered hotkey for example 1"];
		[self addOutput:[NSString stringWithFormat:@"Registered: %@", [c registeredHotKeys]]];
	}
}
//- (IBAction) registerExample1:(id)sender {
//    [self addOutput:@"Attempting to register hotkey for example 1"];
//    DDHotKeyCenter *c = [DDHotKeyCenter sharedHotKeyCenter];
//    if (![c registerHotKeyWithKeyCode:kVK_ANSI_V modifierFlags:NSControlKeyMask target:self action:@selector(hotkeyWithEvent:) object:nil]) {
//        [self addOutput:@"Unable to register hotkey for example 1"];
//    } else {
//        [self addOutput:@"Registered hotkey for example 1"];
//        [self addOutput:[NSString stringWithFormat:@"Registered: %@", [c registeredHotKeys]]];
//    }
//}
- (IBAction) registerExample2:(id)sender {
	[self addOutput:@"Attempting to register hotkey for example 2"];
	DDHotKeyCenter *c = [DDHotKeyCenter sharedHotKeyCenter];
	if (![c registerHotKeyWithKeyCode:kVK_ANSI_V modifierFlags:(NSControlKeyMask | NSAlternateKeyMask) target:self action:@selector(hotkeyWithEvent:object:) object:@"hello, world!"]) {
		[self addOutput:@"Unable to register hotkey for example 2"];
	} else {
		[self addOutput:@"Registered hotkey for example 2"];
		[self addOutput:[NSString stringWithFormat:@"Registered: %@", [c registeredHotKeys]]];
	}
}

- (IBAction) registerExample3:(id)sender {
#if NS_BLOCKS_AVAILABLE
	[self addOutput:@"Attempting to register hotkey for example 3"];
	DDHotKeyCenter *c = [DDHotKeyCenter sharedHotKeyCenter];
	int theAnswer = 42;
	DDHotKeyTask task = ^(NSEvent *hkEvent) {
		[self addOutput:@"Firing block hotkey"];
		[self addOutput:[NSString stringWithFormat:@"Hotkey event: %@", hkEvent]];
		[self addOutput:[NSString stringWithFormat:@"the answer is: %d", theAnswer]];	
	};
	if (![c registerHotKeyWithKeyCode:kVK_ANSI_V modifierFlags:(NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask) task:task]) {
		[self addOutput:@"Unable to register hotkey for example 3"];
	} else {
		[self addOutput:@"Registered hotkey for example 3"];
		[self addOutput:[NSString stringWithFormat:@"Registered: %@", [c registeredHotKeys]]];
	}
#else
	NSRunAlertPanel(@"Blocks not available", @"This example requires the 10.6 SDK", @"OK", nil, nil);
#endif
}

- (IBAction) unregisterExample1:(id)sender {
	DDHotKeyCenter *c = [DDHotKeyCenter sharedHotKeyCenter];
	[c unregisterHotKeyWithKeyCode:kVK_ANSI_0 modifierFlags:NSFunctionKeyMask];
	[self addOutput:@"Unregistered hotkey for example 1"];
}

- (IBAction) unregisterExample2:(id)sender {
	DDHotKeyCenter *c = [DDHotKeyCenter sharedHotKeyCenter];
	[c unregisterHotKeyWithKeyCode:kVK_ANSI_V modifierFlags:(NSControlKeyMask | NSAlternateKeyMask)];
	[self addOutput:@"Unregistered hotkey for example 2"];
}

- (IBAction) unregisterExample3:(id)sender {
	DDHotKeyCenter *c = [DDHotKeyCenter sharedHotKeyCenter];
	[c unregisterHotKeyWithKeyCode:kVK_ANSI_V modifierFlags:(NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask)];
	[self addOutput:@"Unregistered hotkey for example 3"];
}

@end
