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


const int kMaxDisplays = 16;
const CFStringRef kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);

@implementation DDHotKeyAppDelegate

@synthesize window, output;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self registerHotkeys];
	// Insert code here to initialize your application
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
    NSLog(@"%f", [self get_brightness]);
    short keyCode = hkEvent.keyCode;
    if (hkEvent.keyCode == kVK_ANSI_1) {
        [self set_brightness:curr - 0.1];
    } else if (hkEvent.keyCode == kVK_ANSI_2) {
        [self set_brightness:curr + 0.1];
    } else if (hkEvent.keyCode == kVK_ANSI_8) {
        [self muteVolume];
    } else if (keyCode == kVK_ANSI_9) {
        [self decreaseVolume];
    } else if (keyCode == kVK_ANSI_0) {
        [self increaseVolume];
    } else {
        
    }
    
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
        
        NSLog(@"currentVolume is: %f", currentVolume);
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
    DDHotKey* res3 = [c registerHotKeyWithKeyCode:kVK_ANSI_8 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res4 = [c registerHotKeyWithKeyCode:kVK_ANSI_9 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];
    DDHotKey* res5 = [c registerHotKeyWithKeyCode:kVK_ANSI_0 modifierFlags:NSEventModifierFlagControl target:self action:@selector(hotkeyWithEvent:) object:nil];

    if (!res1 || !res2 ||!res3 ||!res4 ||!res5) {
        [self addOutput:@"Unable to register hotkeys"];
    } else {
        [self addOutput:@"Registered hotkeys"];
        [self addOutput:[NSString stringWithFormat:@"Registered: %@", [c registeredHotKeys]]];
	}
}

- (IBAction)disableTouchbar:(NSButton *)sender {
    
}

- (IBAction)enableTouchBar:(NSButton *)sender {
}

@end
