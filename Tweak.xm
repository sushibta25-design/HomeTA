// HomeTA 0.3.10 — scene-bound, display-only battery window experiment.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface SBIconImageView : UIImageView @end
@interface DBIconLabelBackdropView : UIView @end

static BOOL HTDidLogStyle=NO;
static BOOL HTDidLogLabel=NO;
// A display-only window must never become key or consume a CarPlay touch.
@interface HTBatteryWindow : UIWindow
@end
@implementation HTBatteryWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
@end

static HTBatteryWindow *HTBatteryWindowInstance=nil;
static __weak UIWindow *HTBatterySourceWindow=nil;
static __weak UIView *HTBatteryContainer=nil;
static id HTSceneDisconnectObserver=nil;
static id HTSceneDeactivateObserver=nil;
static id HTSceneActivateObserver=nil;
static id HTBatteryLevelObserver=nil;
static id HTBatteryStateObserver=nil;

static const NSInteger HTBatteryContainerTag=27003701;
static const NSInteger HTBatteryImageTag=27003702;

static void HTLog(NSString *message) {
    NSString *path=@"/var/mobile/HomeTA.log";
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA 0.3.10] %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (__unused NSException *exception) {}
    @finally { [handle closeFile]; }
}

static void HTUpdateBatteryIndicator(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *container=HTBatteryContainer;
        if (!container) return;
        UIDevice *device=UIDevice.currentDevice;
        CGFloat level=device.batteryLevel;
        NSInteger percent=level < 0 ? -1 : (NSInteger)(level*100.0+0.5);
        container.hidden=percent<0;
        if (percent<0) return;
        NSString *symbol=@"battery.100";
        if (percent >= 0 && percent < 13) symbol=@"battery.0";
        else if (percent >= 0 && percent < 38) symbol=@"battery.25";
        else if (percent >= 0 && percent < 63) symbol=@"battery.50";
        else if (percent >= 0 && percent < 88) symbol=@"battery.75";
        UIImageView *image=(UIImageView *)[container viewWithTag:HTBatteryImageTag];
        BOOL charging=device.batteryState==UIDeviceBatteryStateCharging || device.batteryState==UIDeviceBatteryStateFull;
        if (charging) symbol=@"battery.100.bolt";
        UIImageSymbolConfiguration *config=[UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
        UIImage *symbolImage=[UIImage systemImageNamed:symbol withConfiguration:config];
        if (!symbolImage && charging) symbolImage=[UIImage systemImageNamed:@"battery.100" withConfiguration:config];
        image.image=[symbolImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIColor *color=charging ? [UIColor colorWithRed:0.20 green:1.0 blue:0.48 alpha:1.0] : UIColor.whiteColor;
        image.tintColor=color;
    });
}

static void HTInstallBatteryIndicator(SBIconImageView *icon) {
    UIWindow *window=icon.window;
    if (!window || !window.windowScene || window.hidden) return;

    // Derive the sidebar from the Home content inset. Do not guess a side
    // when the native layout has not yet produced a usable inset.
    UIView *ancestor=icon;
    while (ancestor && ![NSStringFromClass(ancestor.class) isEqualToString:@"DBAnimationView"])
        ancestor=ancestor.superview;
    if (!ancestor) return;
    CGRect bounds=window.bounds;
    CGRect contentFrame=[ancestor convertRect:ancestor.bounds toView:window];
    CGFloat left=CGRectGetMinX(contentFrame)-CGRectGetMinX(bounds);
    CGFloat right=CGRectGetMaxX(bounds)-CGRectGetMaxX(contentFrame);
    BOOL sidebarOnLeft=left>=right;
    CGFloat sidebarWidth=MAX(left,right);
    if (sidebarWidth<24.0 || sidebarWidth>CGRectGetWidth(bounds)*0.3) {
        static BOOL loggedInvalidInset=NO;
        if (!loggedInvalidInset) {
            loggedInvalidInset=YES;
            HTLog([NSString stringWithFormat:@"WAIT sidebar inset window=%@ content=%@",NSStringFromCGRect(bounds),NSStringFromCGRect(contentFrame)]);
        }
        return;
    }
    BOOL created=NO;

    if (HTBatterySourceWindow!=window || !HTBatteryWindowInstance) {
        HTBatteryWindowInstance.hidden=YES;
        HTBatteryWindowInstance=nil;
        HTBatteryWindow *overlay=[[HTBatteryWindow alloc] initWithWindowScene:window.windowScene];
        overlay.backgroundColor=UIColor.clearColor;
        overlay.userInteractionEnabled=NO;
        UIViewController *controller=[UIViewController new];
        controller.view.backgroundColor=UIColor.clearColor;
        controller.view.userInteractionEnabled=NO;
        overlay.rootViewController=controller;
        UIView *container=[[UIView alloc] initWithFrame:CGRectZero];
        container.tag=HTBatteryContainerTag;
        container.userInteractionEnabled=NO;
        UIImageView *image=[[UIImageView alloc] initWithFrame:CGRectZero];
        image.tag=HTBatteryImageTag;
        image.contentMode=UIViewContentModeScaleAspectFit;
        image.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [container addSubview:image];
        [controller.view addSubview:container];
        HTBatteryWindowInstance=overlay;
        created=YES;
        HTBatterySourceWindow=window;
        HTBatteryContainer=container;
        HTLog([NSString stringWithFormat:@"CREATED battery window scene=%@ sourceLevel=%.1f",
            window.windowScene.session.persistentIdentifier,(double)window.windowLevel]);
    }

    HTBatteryWindow *overlay=HTBatteryWindowInstance;
    if (!CGRectEqualToRect(overlay.frame,window.frame)) overlay.frame=window.frame;
    if (overlay.windowLevel!=window.windowLevel+1.0) overlay.windowLevel=window.windowLevel+1.0;
    CGFloat scale=MIN(MAX(CGRectGetHeight(bounds)/240.0,0.9),1.4);
    CGFloat width=22.0*scale, height=12.0*scale;
    CGFloat start=sidebarOnLeft ? CGRectGetMinX(bounds) : CGRectGetMaxX(contentFrame);
    CGRect sourceFrame=CGRectMake(start+(sidebarWidth-width)*0.5,
        CGRectGetMinY(bounds)+CGRectGetHeight(bounds)*0.19,width,height);
    CGRect frame=[window convertRect:sourceFrame toView:overlay.rootViewController.view];
    if (!CGRectEqualToRect(HTBatteryContainer.frame,frame)) {
        HTBatteryContainer.frame=frame;
        [HTBatteryContainer viewWithTag:HTBatteryImageTag].frame=HTBatteryContainer.bounds;
        HTLog([NSString stringWithFormat:@"POSITION battery=%@ source=%@ sidebar=%.1f left=%d",
            NSStringFromCGRect(frame),NSStringFromCGRect(bounds),(double)sidebarWidth,sidebarOnLeft]);
    }
    BOOL hidden=window.windowScene.activationState!=UISceneActivationStateForegroundActive;
    if (overlay.hidden!=hidden) overlay.hidden=hidden;
    if (created) HTUpdateBatteryIndicator();
}

static void HTStyleLabelBackdrop(DBIconLabelBackdropView *label) {
    label.backgroundColor=[UIColor colorWithRed:0.015 green:0.040 blue:0.085 alpha:0.72];
    label.layer.borderWidth=0.75;
    label.layer.borderColor=[UIColor colorWithRed:0.08 green:0.84 blue:1.0 alpha:0.50].CGColor;
    label.layer.cornerRadius=8.5;
    if (@available(iOS 13.0,*)) label.layer.cornerCurve=kCACornerCurveContinuous;
    label.layer.masksToBounds=YES;
    for (UIView *child in label.subviews) {
        if ([NSStringFromClass(child.class) containsString:@"DBDashboardPlatterView"]) child.alpha=0.38;
    }
    if (!HTDidLogLabel) {
        HTDidLogLabel=YES;
        HTLog([NSString stringWithFormat:@"STYLED DBIconLabelBackdropView frame=%@",NSStringFromCGRect(label.frame)]);
    }
}

static void HTStyleIconImage(SBIconImageView *image) {
    image.layer.borderWidth=1.5;
    image.layer.borderColor=[UIColor colorWithRed:0.08 green:0.84 blue:1.0 alpha:0.92].CGColor;
    image.layer.cornerRadius=MIN(CGRectGetWidth(image.bounds),CGRectGetHeight(image.bounds))*0.18;
    if (@available(iOS 13.0,*)) image.layer.cornerCurve=kCACornerCurveContinuous;
    HTInstallBatteryIndicator(image);
    if (!HTDidLogStyle) {
        HTDidLogStyle=YES;
        HTLog([NSString stringWithFormat:@"STYLED SBIconImageView frame=%@",NSStringFromCGRect(image.frame)]);
    }
}

%hook SBIconImageView
- (void)layoutSubviews {
    %orig;
    HTStyleIconImage(self);
}
%end

%hook DBIconLabelBackdropView
- (void)layoutSubviews {
    %orig;
    HTStyleLabelBackdrop(self);
}
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.CarPlayApp"]) return;
        UIDevice.currentDevice.batteryMonitoringEnabled=YES;
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        HTBatteryLevelObserver=[center addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { HTUpdateBatteryIndicator(); }];
        HTBatteryStateObserver=[center addObserverForName:UIDeviceBatteryStateDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { HTUpdateBatteryIndicator(); }];
        Class pageClass=NSClassFromString(@"DBIconListPageControl");
        if (pageClass && [pageClass respondsToSelector:@selector(appearance)]) {
            UIPageControl *pageAppearance=[pageClass appearance];
            pageAppearance.pageIndicatorTintColor=[UIColor colorWithWhite:1.0 alpha:0.28];
            pageAppearance.currentPageIndicatorTintColor=[UIColor colorWithRed:0.08 green:0.84 blue:1.0 alpha:1.0];
        }
        HTSceneDisconnectObserver=[center addObserverForName:UISceneDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (note.object!=HTBatteryWindowInstance.windowScene) return;
            HTBatteryWindowInstance.hidden=YES;
            HTBatteryWindowInstance=nil;
            HTBatterySourceWindow=nil;
            HTBatteryContainer=nil;
        }];
        HTSceneDeactivateObserver=[center addObserverForName:UISceneWillDeactivateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (note.object==HTBatteryWindowInstance.windowScene) HTBatteryWindowInstance.hidden=YES;
        }];
        HTSceneActivateObserver=[center addObserverForName:UISceneDidActivateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (note.object==HTBatteryWindowInstance.windowScene && HTBatterySourceWindow && !HTBatterySourceWindow.hidden) {
                HTBatteryWindowInstance.hidden=NO;
                HTUpdateBatteryIndicator();
            }
        }];
        HTLog(@"LOADED scene battery window test; touch passthrough; timer=NO");
        %init;
    }
}
