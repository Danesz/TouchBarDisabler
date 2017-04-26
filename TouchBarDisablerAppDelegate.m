#import "TouchBarDisablerAppDelegate.h"
#import "DDHotKeyCenter.h"
#import <Carbon/Carbon.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <ApplicationServices/ApplicationServices.h>
#include <IOKit/i2c/IOI2CInterface.h>
#include <CoreFoundation/CoreFoundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioServices.h>
#import "LaunchAtLoginController.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
@import CoreMedia;

const int kMaxDisplays = 16;
const CFStringRef kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);
@interface TouchBarDisablerAppDelegate() {
    BOOL hasSeenHelperOnce;
    BOOL touchBarDisabled;
    NSMenu *menu;
    NSMenuItem *toggler;
    NSMenuItem *showHelp;
    NSMenuItem *quit;
    NSMenuItem *onboardHelp;

    AVPlayer *player;
    __weak IBOutlet NSWindow *emptyWindow;
    __weak IBOutlet NSTextField *hintLabel;
    __weak IBOutlet NSTextField *hintContent;
    __weak IBOutlet NSButton *dismissButton;
    __weak IBOutlet NSWindow *noSIPWindow;
    __weak IBOutlet AVPlayerView *onboardVideo;
}
@end
@implementation TouchBarDisablerAppDelegate

@synthesize window;

- (IBAction)hasSeenHelperOnce:(NSButton *)sender {
    [window setIsVisible:NO];
    hasSeenHelperOnce = YES;
    [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"hasSeenHelperOnce"];
}

- (void)detectSIP {
    [self launch];
}

- (void)launch {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/csrutil"];
    [task setArguments:[NSArray arrayWithObjects:@"status", nil]];
    NSPipe *outputPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readCompleted:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[outputPipe fileHandleForReading]];
    [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [task launch];
}

//
//- (void)applicationDidBecomeActive:(NSNotification *)notification {
//}

- (void)readCompleted:(NSNotification *)notification {
//    NSLog(@"Read data: %@", [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem]);
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSString *strOutput = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    NSLog(@"string value %@", strOutput);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:[notification object]];
    if ([strOutput containsString:@"disabled"]) {
//        NSLog(@"SIP is disabled!");
        [self setupAppWhenSIPIsOff];
    } else {
//        NSLog(@"SIP on, showing onboard help!");
        [self showOnboardHelp];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == noSIPWindow) {
        NSLog(@"%@ window will close", notification.object);
        player = nil;
        [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
    }
}

- (void)showOnboardHelp {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"SIP_ALERT_TITLE", nil)];
    [alert setInformativeText:NSLocalizedString(@"SIP_ALERT_TEXT", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert runModal];
    noSIPWindow.delegate = self;
    noSIPWindow.titleVisibility = NSWindowTitleHidden;
    noSIPWindow.styleMask |= NSWindowStyleMaskFullSizeContentView;
    [noSIPWindow setIsVisible:YES];
    
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"disable_sip_guide" withExtension:@"mp4"];
    player = [[AVPlayer alloc] initWithURL:url];
    onboardVideo.player = player;
    onboardVideo.controlsStyle = AVPlayerViewControlsStyleNone;
    
    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[player currentItem]];
//    showOnboardForThisRun = YES;
    [player play];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}


- (void)setupAppWhenSIPIsOff {
    [hintLabel setStringValue:NSLocalizedString(@"HINT_LABEL", nil)];
    [hintContent setStringValue:NSLocalizedString(@"HINT_CONTENT", nil)];
    [dismissButton setTitle:NSLocalizedString(@"OK", nil)];
    [window setLevel:NSFloatingWindowLevel];
    [self registerHotkeys];
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.title = @"T";
    
    // The image that will be shown in the menu bar, a 16x16 black png works best
    //    _statusItem.image = [NSImage imageNamed:@"bar-logo"];
    
    // The highlighted image, use a white version of the normal image
    //    _statusItem.alternateImage = [NSImage imageNamed:@"bar-logo-alt"];
    _statusItem.highlightMode = YES;
    
    menu = [[NSMenu alloc] init];
    NSString *disable = NSLocalizedString(@"DISABLE_TOUCH_BAR", nil);
    NSString *shortcut = NSLocalizedString(@"SHORTCUT_HELP", nil);
    
    toggler = [[NSMenuItem alloc] initWithTitle:disable action:@selector(toggleTouchBar:) keyEquivalent:@""];
    showHelp = [[NSMenuItem alloc] initWithTitle:shortcut action:@selector(displayHUD:) keyEquivalent:@""];
//    onboardHelp = [[NSMenuItem alloc] initWithTitle:@"Onboard Help" action:@selector(showOnboardHelp) keyEquivalent:@""];

    [menu addItem:toggler];
//    [menu addItem:onboardHelp];
    
    NSNumber *num = [[NSUserDefaults standardUserDefaults] objectForKey:@"touchBarDisabled"];
    NSNumber *helper = [[NSUserDefaults standardUserDefaults] objectForKey:@"hasSeenHelperOnce"];
    
    if (helper != nil) {
        hasSeenHelperOnce = [helper boolValue];
    }
    
    if (num != nil) {
        touchBarDisabled = [num boolValue];
        if (touchBarDisabled) {
            [self disableTouchBar];
        } else {
        }
    }
    //    [menu addItemWithTitle:@"Advanced Preferences" action:@selector(showPreferencesPane:) keyEquivalent:@""];
    
    [menu addItem:[NSMenuItem separatorItem]]; // A thin grey line
    quit = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"QUIT_TOUCH_BAR_DISABLER", nil) action:@selector(terminate:) keyEquivalent:@""];
    
    [menu addItem:quit];
    _statusItem.menu = menu;
    
    LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
    [launchController setLaunchAtLogin:YES];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self detectSIP];
}

- (void)displayHUD:(id)sender {
    [window setIsVisible:YES];
}

- (void)enableTouchBar {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[ @"-c", @"defaults delete com.apple.touchbar.agent PresentationModeGlobal;defaults write com.apple.touchbar.agent PresentationModeFnModes '<dict><key>app</key><string>fullControlStrip</string><key>appWithControlStrip</key><string>fullControlStrip</string><key>fullControlStrip</key><string>app</string></dict>';launchctl load /System/Library/LaunchAgents/com.apple.controlstrip.plist;launchctl load /System/Library/LaunchAgents/com.apple.touchbar.agent.plist;launchctl unload /System/Library/LaunchAgents/com.apple.touchbar.agent.plist;launchctl load /System/Library/LaunchAgents/com.apple.touchbar.agent.plist;pkill \"Touch Bar agent\";killall Dock"]];
    task.terminationHandler = ^(NSTask *task){
        [menu removeItem:showHelp];
    };
    [task launch];
    touchBarDisabled = NO;
    toggler.title = NSLocalizedString(@"DISABLE_TOUCH_BAR", nil);
    [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:@"touchBarDisabled"];
}

- (void)disableTouchBar {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [emptyWindow makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
    [task setArguments:@[ @"-c", @"defaults write com.apple.touchbar.agent PresentationModeGlobal -string fullControlStrip;launchctl unload /System/Library/LaunchAgents/com.apple.controlstrip.plist;killall ControlStrip;launchctl unload /System/Library/LaunchAgents/com.apple.touchbar.agent.plist;launchctl unload /System/Library/LaunchDaemons/com.apple.touchbar.user-device.plist;pkill \"Touch Bar agent\""]];
    task.terminationHandler = ^(NSTask *task){
        [emptyWindow setIsVisible:NO];
        [menu addItem:showHelp];
    };
    if (hasSeenHelperOnce) {
        [emptyWindow setIsVisible:YES];
    } else {
        [window setIsVisible:YES];
    }
    [task launch];
    touchBarDisabled = YES;
    NSString *enable = NSLocalizedString(@"ENABLE_TOUCH_BAR", nil);
    toggler.title = enable;
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
            [self muteVolume];
            break;
        case kVK_ANSI_9:
            [self decreaseVolume];
            break;
        case kVK_ANSI_0:
            [self increaseVolume];
            break;
        default:
            break;
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
