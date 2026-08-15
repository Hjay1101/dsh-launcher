// ============================================================
//  DeepSeek Harness — native macOS launcher (Objective-C)
//  https://github.com/Hjay1101/dsh-launcher (MIT)
//
//  A bare bash script as CFBundleExecutable has no NSApplication
//  run loop, so the Dock icon bounces forever. This native binary
//  runs a real Cocoa event loop (stable Dock icon).
//
//  Lifecycle:
//    - launch: NSTask runs start-dsh.sh (boots dsh web)
//    - run:    NSApplication event loop (Dock icon lit = running)
//    - quit:   applicationWillTerminate -> terminate the task
//              (SIGTERM to start-dsh.sh -> it kills dsh -> service stops)
//
//  NOTE: uses NSTask (NOT fork) — fork in a GUI app's main() can
//  wedge AppKit's state machine, making Finder report "not responding".
// ============================================================
#import <Cocoa/Cocoa.h>

static NSTask *g_task = nil;

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Locate the boot script inside the bundle
    NSString *resPath = [[NSBundle mainBundle] resourcePath];
    NSString *bootPath = [resPath stringByAppendingPathComponent:@"start-dsh.sh"];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/bash";
    task.arguments = @[ bootPath ];
    // inherit stdout/stderr so start-dsh.sh's log writes work
    [task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
    [task launch];
    g_task = task;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // terminate the boot script; its trap kills dsh before exiting
    if (g_task && g_task.isRunning) {
        [g_task terminate];  // sends SIGTERM to start-dsh.sh
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return NO;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
