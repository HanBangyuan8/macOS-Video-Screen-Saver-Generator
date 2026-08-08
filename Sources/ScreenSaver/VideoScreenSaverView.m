#import "VideoScreenSaverView.h"

#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <os/log.h>
#import <stdlib.h>

static NSString * const SFSaverWillStopNotification = @"com.apple.screensaver.willstop";

static os_log_t SFLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("local.saverforge.videosaver", "screensaver");
    });
    return log;
}

@interface VideoScreenSaverView ()
@property (nonatomic, strong) AVQueuePlayer *queuePlayer;
@property (nonatomic, strong) AVPlayerLooper *playerLooper;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) id manualLoopObserver;
@property (nonatomic, strong) AVURLAsset *loadingAsset;
@property (nonatomic, assign) BOOL tearingDown;
@property (nonatomic, assign) BOOL observersInstalled;
@property (nonatomic, strong) NSDictionary *configuration;
@end

@implementation VideoScreenSaverView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.animationTimeInterval = 1.0 / 30.0;
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.blackColor.CGColor;
    self.layer.masksToBounds = YES;
    self.configuration = [self loadConfiguration];
    [self installLifecycleObservers];
    [self configurePlayerIfNeeded];
}

- (NSDictionary *)loadConfiguration {
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSURL *url = [bundle URLForResource:@"SaverConfig" withExtension:@"plist"];
    NSDictionary *dictionary = url ? [NSDictionary dictionaryWithContentsOfURL:url] : nil;
    return dictionary ?: @{};
}

- (NSURL *)embeddedVideoURL {
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSURL *resourceURL = bundle.resourceURL;
    if (!resourceURL) {
        return nil;
    }

    NSError *error = nil;
    NSArray<NSURL *> *files = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:resourceURL
        includingPropertiesForKeys:nil
        options:NSDirectoryEnumerationSkipsHiddenFiles
        error:&error];

    if (!files) {
        os_log_error(SFLog(), "Unable to enumerate Resources: %{public}@", error.localizedDescription);
        return nil;
    }

    NSArray<NSURL *> *sorted = [files sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        return [a.lastPathComponent compare:b.lastPathComponent options:NSCaseInsensitiveSearch];
    }];

    for (NSURL *url in sorted) {
        if ([url.lastPathComponent.lowercaseString hasPrefix:@"video."]) {
            return url;
        }
    }
    return nil;
}

- (void)configurePlayerIfNeeded {
    if (self.queuePlayer || self.loadingAsset || self.tearingDown) {
        return;
    }

    NSURL *videoURL = [self embeddedVideoURL];
    if (!videoURL) {
        os_log(SFLog(), "No embedded video found; rendering black instead of crashing.");
        return;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:@{
        AVURLAssetPreferPreciseDurationAndTimingKey: @NO
    }];
    self.loadingAsset = asset;

    __weak typeof(self) weakSelf = self;
    [asset loadValuesAsynchronouslyForKeys:@[@"duration", @"playable"] completionHandler:^{
        NSError *durationError = nil;
        NSError *playableError = nil;
        AVKeyValueStatus durationStatus = [asset statusOfValueForKey:@"duration" error:&durationError];
        AVKeyValueStatus playableStatus = [asset statusOfValueForKey:@"playable" error:&playableError];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.tearingDown || self.loadingAsset != asset) {
                return;
            }
            self.loadingAsset = nil;

            BOOL validDuration = CMTIME_IS_VALID(asset.duration) &&
                                 !CMTIME_IS_INDEFINITE(asset.duration) &&
                                 CMTimeCompare(asset.duration, kCMTimeZero) > 0;

            if (durationStatus != AVKeyValueStatusLoaded ||
                playableStatus != AVKeyValueStatusLoaded ||
                !asset.playable ||
                !validDuration) {
                NSError *error = durationError ?: playableError;
                os_log_error(SFLog(), "Video cannot be loaded: %{public}@", error.localizedDescription ?: @"invalid asset");
                return;
            }

            [self installPlayerForAsset:asset];
            if (self.isAnimating) {
                [self.queuePlayer play];
            }
        });
    }];
}

- (void)installPlayerForAsset:(AVAsset *)asset {
    if (self.tearingDown || self.queuePlayer) {
        return;
    }

    AVPlayerItem *templateItem = [AVPlayerItem playerItemWithAsset:asset];
    BOOL useManualLoop = CMTimeGetSeconds(asset.duration) < 2.0;
    AVQueuePlayer *player = [AVQueuePlayer queuePlayerWithItems:useManualLoop ? @[templateItem] : @[]];
    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    player.appliesMediaSelectionCriteriaAutomatically = NO;
    player.automaticallyWaitsToMinimizeStalling = YES;
    player.preventsDisplaySleepDuringVideoPlayback = NO;
    player.muted = [self.configuration[@"Muted"] boolValue];

    AVPlayerLooper *looper = nil;
    if (useManualLoop) {
        // AVPlayerLooper can crash inside CoreMedia media-selection callbacks
        // for very short clips on macOS 15. Keep the v3.1 looper for normal
        // content, but use the same queue player with an explicit end reset
        // for this verified short-asset edge case.
        __weak typeof(self) weakSelf = self;
        __weak AVQueuePlayer *weakPlayer = player;
        self.manualLoopObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
            object:templateItem
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *notification) {
                (void)notification;
                __strong typeof(weakSelf) self = weakSelf;
                AVQueuePlayer *strongPlayer = weakPlayer;
                if (!self || self.tearingDown || !strongPlayer || !self.isAnimating) {
                    return;
                }
                [strongPlayer seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                    if (finished && self.isAnimating && !self.tearingDown) {
                        [strongPlayer play];
                    }
                }];
            }];
    } else {
        looper = [AVPlayerLooper playerLooperWithPlayer:player templateItem:templateItem];
        if (looper.status == AVPlayerLooperStatusFailed) {
            os_log_error(SFLog(), "AVPlayerLooper failed: %{public}@", looper.error.localizedDescription ?: @"unknown error");
            return;
        }
    }

    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
    NSString *contentMode = self.configuration[@"ContentMode"];
    layer.videoGravity = [contentMode isEqualToString:@"fit"]
        ? AVLayerVideoGravityResizeAspect
        : AVLayerVideoGravityResizeAspectFill;
    layer.backgroundColor = NSColor.blackColor.CGColor;
    layer.frame = self.bounds;
    layer.needsDisplayOnBoundsChange = YES;

    [self.layer addSublayer:layer];
    self.queuePlayer = player;
    self.playerLooper = looper;
    self.playerLayer = layer;
}

- (void)startAnimation {
    [super startAnimation];
    [self configurePlayerIfNeeded];
    [self.queuePlayer play];
    os_log(SFLog(), "startAnimation");
}

- (void)stopAnimation {
    [self teardownPlayer];
    [super stopAnimation];
    os_log(SFLog(), "stopAnimation");
}

- (void)animateOneFrame {
    // AVPlayerLayer drives rendering. ScreenSaverView's animation timer is intentionally idle.
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    self.playerLayer.frame = self.bounds;
}

- (BOOL)hasConfigureSheet {
    return NO;
}

- (NSWindow *)configureSheet {
    return nil;
}

- (void)installLifecycleObservers {
    if (self.observersInstalled) {
        return;
    }
    self.observersInstalled = YES;

    [[NSDistributedNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(screenSaverWillStop:)
        name:SFSaverWillStopNotification
        object:nil
        suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(applicationWillTerminate:)
        name:NSApplicationWillTerminateNotification
        object:nil];
}

- (void)removeLifecycleObservers {
    if (!self.observersInstalled) {
        return;
    }
    self.observersInstalled = NO;
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)screenSaverWillStop:(NSNotification *)notification {
    (void)notification;
    os_log(SFLog(), "received screensaver willstop notification");
    [self teardownPlayer];

    BOOL aggressive = self.configuration[@"AggressiveLegacyCleanup"] == nil
        ? YES
        : [self.configuration[@"AggressiveLegacyCleanup"] boolValue];

    if (aggressive && [self isDedicatedLegacyHost] && ![self isLikelyPreview]) {
        // Snoopy's field-tested workaround: legacyScreenSaver has historically failed
        // to tear down media reliably. Only terminate when we can identify the dedicated
        // legacy host process; never terminate System Settings or our smoke-test host.
        dispatch_async(dispatch_get_main_queue(), ^{
            exit(EXIT_SUCCESS);
        });
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self teardownPlayer];
}

- (BOOL)isDedicatedLegacyHost {
    NSString *name = NSProcessInfo.processInfo.processName.lowercaseString;
    return [name containsString:@"legacyscreensaver"];
}

- (BOOL)isLikelyPreview {
    if (self.isPreview) {
        return YES;
    }

    // macOS 15/26 have had reports of incorrect isPreview values in the legacy host.
    // A small embedded view is therefore treated as preview as an additional guard.
    NSSize size = self.bounds.size;
    return size.width < 900.0 && size.height < 700.0;
}

- (void)teardownPlayer {
    if (self.tearingDown) {
        return;
    }
    self.tearingDown = YES;

    self.loadingAsset = nil; // Async completion checks identity and becomes a no-op.

    AVQueuePlayer *player = self.queuePlayer;
    AVPlayerLooper *looper = self.playerLooper;
    AVPlayerLayer *layer = self.playerLayer;

    if (self.manualLoopObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.manualLoopObserver];
        self.manualLoopObserver = nil;
    }

    [player pause];
    [looper disableLooping];
    // AVPlayerLooper owns asynchronously replicated items. Removing the queue
    // synchronously here can race CoreMedia media-selection callbacks on macOS 15.
    // Detach the layer now, then drain the disabled queue on the next run-loop turn
    // while these local references keep the player graph alive.
    layer.player = nil;
    [layer removeFromSuperlayer];
    dispatch_async(dispatch_get_main_queue(), ^{
        [looper disableLooping];
        [player removeAllItems];
    });

    self.playerLayer = nil;
    self.playerLooper = nil;
    self.queuePlayer = nil;

    self.tearingDown = NO;
}

- (void)dealloc {
    [self removeLifecycleObservers];
    [self teardownPlayer];
}

@end
