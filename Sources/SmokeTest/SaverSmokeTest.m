#import <AppKit/AppKit.h>
#import <ScreenSaver/ScreenSaver.h>

static int fail(NSString *message) {
    fprintf(stderr, "SMOKE FAIL: %s\n", message.UTF8String);
    return 1;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            return fail(@"expected path to .saver");
        }

        [NSApplication sharedApplication];
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        if (!bundle) {
            return fail(@"NSBundle could not open saver");
        }

        NSError *loadError = nil;
        if (![bundle loadAndReturnError:&loadError]) {
            return fail([NSString stringWithFormat:@"bundle load failed: %@", loadError]);
        }

        Class principal = bundle.principalClass;
        if (!principal || ![principal isSubclassOfClass:ScreenSaverView.class]) {
            return fail(@"principal class is not a ScreenSaverView subclass");
        }

        NSArray<NSNumber *> *previewModes = @[@YES, @NO];
        for (NSNumber *previewNumber in previewModes) {
            BOOL preview = previewNumber.boolValue;
            NSRect frame = preview
                ? NSMakeRect(0, 0, 480, 300)
                : NSMakeRect(0, 0, 1280, 720);

            ScreenSaverView *view = [[principal alloc] initWithFrame:frame isPreview:preview];
            if (!view) {
                return fail(@"ScreenSaverView init returned nil");
            }

            NSWindow *window = [[NSWindow alloc]
                initWithContentRect:NSMakeRect(-3000, -3000, frame.size.width, frame.size.height)
                styleMask:NSWindowStyleMaskBorderless
                backing:NSBackingStoreBuffered
                defer:NO];
            window.contentView = view;

            [view startAnimation];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.75]];
            [view stopAnimation];
            [window orderOut:nil];
        }

        fprintf(stdout, "SMOKE PASS: bundle loaded, principal class instantiated, preview/full start-stop completed\n");
        return 0;
    }
}
