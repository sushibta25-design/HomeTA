// HomeTA 0.3.7 Battery Indicator Test — event-driven, no timer.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface SBIconImageView : UIImageView @end
@interface DBIconLabelBackdropView : UIView @end

static BOOL HTDidLogStyle=NO;
static BOOL HTDidLogLabel=NO;
static __weak UIView *HTBatteryContainer=nil;
static id HTBatteryLevelObserver=nil;
static id HTBatteryStateObserver=nil;

static const NSInteger HTBatteryContainerTag=27003701;
static const NSInteger HTBatteryImageTag=27003702;
static const NSInteger HTBatteryLabelTag=27003703;

static void HTLog(NSString *message) {
    NSString *path=@"/var/mobile/HomeTA.log";
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA 0.3.7] %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
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
        NSString *symbol=@"battery.100";
        if (percent >= 0 && percent < 13) symbol=@"battery.0";
        else if (percent >= 0 && percent < 38) symbol=@"battery.25";
        else if (percent >= 0 && percent < 63) symbol=@"battery.50";
        else if (percent >= 0 && percent < 88) symbol=@"battery.75";
        UIImageView *image=(UIImageView *)[container viewWithTag:HTBatteryImageTag];
        UILabel *label=(UILabel *)[container viewWithTag:HTBatteryLabelTag];
        UIImageSymbolConfiguration *config=[UIImageSymbolConfiguration configurationWithPointSize:9.0 weight:UIImageSymbolWeightSemibold];
        image.image=[[UIImage systemImageNamed:symbol withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        BOOL charging=device.batteryState==UIDeviceBatteryStateCharging || device.batteryState==UIDeviceBatteryStateFull;
        UIColor *color=charging ? [UIColor colorWithRed:0.20 green:1.0 blue:0.48 alpha:1.0] : UIColor.whiteColor;
        image.tintColor=color;
        label.textColor=color;
        label.text=percent < 0 ? @"--" : [NSString stringWithFormat:@"%ld",(long)percent];
    });
}

static void HTInstallBatteryIndicator(SBIconImageView *icon) {
    UIWindow *window=icon.window;
    if (!window) return;
    UIView *existing=[window viewWithTag:HTBatteryContainerTag];
    if (existing) { HTBatteryContainer=existing; return; }

    CGRect contentFrame=window.bounds;
    UIView *ancestor=icon;
    while (ancestor) {
        if ([NSStringFromClass(ancestor.class) isEqualToString:@"DBAnimationView"]) {
            contentFrame=[ancestor convertRect:ancestor.bounds toView:window];
            break;
        }
        ancestor=ancestor.superview;
    }
    BOOL sidebarOnLeft=CGRectGetMinX(contentFrame)>1.0;
    CGFloat x=sidebarOnLeft ? CGRectGetMinX(contentFrame)+3.0 : CGRectGetMaxX(contentFrame)-41.0;
    UIView *container=[[UIView alloc] initWithFrame:CGRectMake(x,4.0,38.0,14.0)];
    container.tag=HTBatteryContainerTag;
    container.userInteractionEnabled=NO;
    container.backgroundColor=[UIColor colorWithRed:0.015 green:0.040 blue:0.085 alpha:0.68];
    container.layer.cornerRadius=7.0;
    if (@available(iOS 13.0,*)) container.layer.cornerCurve=kCACornerCurveContinuous;
    container.layer.zPosition=1000.0;

    UIImageView *image=[[UIImageView alloc] initWithFrame:CGRectMake(3.0,1.5,17.0,11.0)];
    image.tag=HTBatteryImageTag;
    image.contentMode=UIViewContentModeScaleAspectFit;
    [container addSubview:image];

    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(20.0,0,16.0,14.0)];
    label.tag=HTBatteryLabelTag;
    label.font=[UIFont monospacedDigitSystemFontOfSize:8.0 weight:UIFontWeightSemibold];
    label.textAlignment=NSTextAlignmentCenter;
    [container addSubview:label];

    [window addSubview:container];
    HTBatteryContainer=container;
    HTUpdateBatteryIndicator();
    HTLog([NSString stringWithFormat:@"INSTALLED battery frame=%@ sidebarLeft=%d",NSStringFromCGRect(container.frame),sidebarOnLeft]);
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
        HTLog(@"LOADED battery-test hooks=SBIconImageView,DBIconLabelBackdropView timer=NO");
        %init;
    }
}
