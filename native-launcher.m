// ============================================================
//  DeepSeek Harness — native macOS launcher (Objective-C)
//  https://github.com/Hjay1101/dsh-launcher (MIT)
//
//  Why native: a bare bash script as CFBundleExecutable has no
//  NSApplication run loop, so macOS keeps the Dock icon bouncing
//  ("launching…" forever). This tiny native binary runs a real
//  Cocoa event loop, keeping the Dock icon stable.
//
//  Lifecycle:
//    - launch: fork+exec the shell boot script (starts dsh web)
//    - run:    NSApplication event loop (Dock icon lit = running)
//    - quit:   SIGTERM (Dock right-click → Quit / Cmd+Q) →
//              kill the dsh child first, then exit
// ============================================================
#import <Cocoa/Cocoa.h>
#import <signal.h>
#import <sys/wait.h>
#import <unistd.h>

static pid_t g_child = -1;

static void kill_child(void) {
    if (g_child > 0) {
        kill(g_child, SIGTERM);
    }
}

static void handle_signal(int sig) {
    kill_child();
    // graceful exit: the run loop unwinds, applicationWillTerminate fires
    exit(0);
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate
- (void)applicationWillTerminate:(NSNotification *)notification {
    kill_child();
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return NO;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // Locate the boot script inside the bundle
        NSString *resPath = [[NSBundle mainBundle] resourcePath];
        NSString *bootPath = [resPath stringByAppendingPathComponent:@"start-dsh.sh"];

        // Spawn the boot script in the background; it starts dsh web and
        // stays alive (wait) so the child relationship is preserved.
        g_child = fork();
        if (g_child == 0) {
            // child: exec the boot script
            execl("/bin/bash", "/bin/bash", [bootPath UTF8String], (char *)NULL);
            _exit(127);  // execl failed
        }

        // Parent: install signal handlers, then run the Cocoa event loop.
        signal(SIGTERM, handle_signal);
        signal(SIGINT,  handle_signal);
        signal(SIGHUP,  handle_signal);

        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    kill_child();
    return 0;
}
