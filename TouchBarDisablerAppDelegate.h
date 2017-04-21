#import <Cocoa/Cocoa.h>

@interface TouchBarDisablerAppDelegate : NSObject /*<NSApplicationDelegate>*/
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (assign) IBOutlet NSWindow *window;

- (void) addOutput:(NSString *)newOutput;


@end
