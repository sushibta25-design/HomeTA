// HomeTA 0.4.1 — reference-inspired Home and scene-bound dock battery.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface SBIconImageView : UIImageView @end
@interface DBIconLabelBackdropView : UIView @end

static void HTLog(NSString *message) {
    NSString *path=@"/var/mobile/HomeTA.log";
    NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attrs fileSize]>256*1024) {
        [NSFileManager.defaultManager removeItemAtPath:[path stringByAppendingString:@".1"] error:nil];
        [NSFileManager.defaultManager moveItemAtPath:path toPath:[path stringByAppendingString:@".1"] error:nil];
    }
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA 0.4.1] %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (__unused NSException *e) {}
    @finally { [handle closeFile]; }
}

@interface HTWallpaper : UIView @end
@implementation HTWallpaper
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();
    CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    CGFloat colors[]={0.025,0.075,0.13,1, 0.08,0.19,0.26,1, 0.025,0.045,0.09,1};
    CGFloat locations[]={0,0.52,1};
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient=CGGradientCreateWithColorComponents(space,colors,locations,3);
    CGContextDrawLinearGradient(c,gradient,CGPointZero,CGPointMake(w,h),0);
    CGGradientRelease(gradient); CGColorSpaceRelease(space);
    for (NSUInteger i=0;i<4;i++) {
        CGFloat offset=(CGFloat)i*0.19*w;
        UIBezierPath *p=[UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(-0.15*w+offset,h)];
        [p addCurveToPoint:CGPointMake(0.72*w+offset,-0.1*h)
             controlPoint1:CGPointMake(0.05*w+offset,0.30*h)
             controlPoint2:CGPointMake(0.9*w+offset,0.72*h)];
        p.lineWidth=i==1 ? 1.2 : 0.6;
        [[UIColor colorWithRed:0.65 green:0.84 blue:0.92 alpha:i==1 ? 0.44 : 0.17] setStroke];
        [p stroke];
    }
}
@end

@interface HTBatteryView : UIView
@property(nonatomic) float level;
@property(nonatomic) UIDeviceBatteryState state;
@property(nonatomic) BOOL lowPower;
@end
@implementation HTBatteryView
- (void)drawRect:(CGRect)rect {
    CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    CGFloat bodyW=w-3,bodyH=h-2;
    CGRect body=CGRectMake(0.7,1,bodyW-1.4,bodyH);
    UIColor *color=self.lowPower ? UIColor.systemYellowColor :
        ((self.state==UIDeviceBatteryStateCharging || self.state==UIDeviceBatteryStateFull) ?
         UIColor.systemGreenColor : (self.level>=0 && self.level<=0.2 ? UIColor.systemRedColor : UIColor.whiteColor));
    UIBezierPath *outline=[UIBezierPath bezierPathWithRoundedRect:body cornerRadius:2.3];
    outline.lineWidth=1; [[color colorWithAlphaComponent:0.8] setStroke]; [outline stroke];
    [color setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(w-2,0.36*h,2,0.28*h) cornerRadius:0.8] fill];
    if (self.level>=0) {
        CGRect fill=CGRectInset(body,1.8,1.8);
        fill.size.width*=MIN(1,MAX(0,self.level));
        if (fill.size.width>0) [[UIBezierPath bezierPathWithRoundedRect:fill cornerRadius:1] fill];
    } else {
        NSDictionary *attrs=@{NSFontAttributeName:[UIFont boldSystemFontOfSize:8],NSForegroundColorAttributeName:color};
        [@"?" drawAtPoint:CGPointMake(w*0.40,0) withAttributes:attrs];
    }
    if (self.state==UIDeviceBatteryStateCharging) {
        UIBezierPath *bolt=[UIBezierPath bezierPath];
        [bolt moveToPoint:CGPointMake(w*.55,0)];
        [bolt addLineToPoint:CGPointMake(w*.34,h*.57)];
        [bolt addLineToPoint:CGPointMake(w*.47,h*.57)];
        [bolt addLineToPoint:CGPointMake(w*.39,h)];
        [bolt addLineToPoint:CGPointMake(w*.65,h*.40)];
        [bolt addLineToPoint:CGPointMake(w*.51,h*.40)];
        [bolt closePath];
        [[UIColor colorWithWhite:0.08 alpha:1] setFill]; [bolt fill];
        bolt.lineWidth=0.45; [UIColor.whiteColor setStroke]; [bolt stroke];
    }
}
@end

// The battery is a bitmap CALayer in the existing window, never a UIWindow.
// HTBattery is an offscreen drawing helper and is not added to any view tree.
static CALayer *HTBatteryLayer;
static HTBatteryView *HTBattery;
static __weak UIWindowScene *HTBatteryScene;
static CGSize HTRenderedSize;
static CGFloat HTRenderedScale;
static __weak UIView *HTHome;
static __weak UIWindow *HTSource;
static BOOL HTScheduled=NO;
static char HTWallpaperKey;
static NSMutableArray *HTObservers;
static NSInteger HTLoggedLevel=-999;
static NSInteger HTLoggedState=-999;

static BOOL HTSceneVisible(UIWindowScene *scene) {
    return scene && (scene.activationState==UISceneActivationStateForegroundActive ||
                     scene.activationState==UISceneActivationStateForegroundInactive);
}
static void HTUpdateBattery(void) {
    if (!HTBattery || !HTBatteryLayer || CGRectIsEmpty(HTBatteryLayer.bounds)) return;
    UIDevice *device=UIDevice.currentDevice;
    float level=device.batteryLevel;
    UIDeviceBatteryState state=device.batteryState;
    BOOL low=NSProcessInfo.processInfo.lowPowerModeEnabled;
    CGSize size=HTBatteryLayer.bounds.size;
    CGFloat scale=MAX(1,HTSource.screen.scale);
    if (HTBattery.level!=level || HTBattery.state!=state || HTBattery.lowPower!=low ||
        !CGSizeEqualToSize(size,HTRenderedSize) || scale!=HTRenderedScale || !HTBatteryLayer.contents) {
        HTBattery.level=level; HTBattery.state=state; HTBattery.lowPower=low;
        HTBattery.bounds=(CGRect){CGPointZero,size};
        UIGraphicsBeginImageContextWithOptions(size,NO,scale);
        [HTBattery drawRect:HTBattery.bounds];
        UIImage *image=UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        HTBatteryLayer.contentsScale=scale;
        HTBatteryLayer.contents=(__bridge id)image.CGImage;
        [CATransaction commit];
        HTRenderedSize=size; HTRenderedScale=scale;
    }
    NSInteger percent=level<0 ? -1 : (NSInteger)(level*100+0.5);
    if (percent!=HTLoggedLevel || state!=HTLoggedState) {
        HTLoggedLevel=percent; HTLoggedState=state;
        HTLog([NSString stringWithFormat:@"BATTERY percent=%ld state=%ld",(long)percent,(long)state]);
    }
}
static void HTReleaseBatteryLayer(void) {
    [HTBatteryLayer removeFromSuperlayer];
    HTBatteryLayer=nil; HTBattery=nil; HTBatteryScene=nil;
    HTRenderedSize=CGSizeZero; HTRenderedScale=0;
}
static void HTLayoutBatteryLayer(void) {
    UIWindow *source=HTSource;
    UIView *home=HTHome;
    UIWindowScene *scene=source.windowScene;
    if (!source || !home || home.window!=source || !scene) return;
    CGRect bounds=source.bounds;
    CGRect content=[home convertRect:home.bounds toView:source];
    CGFloat left=CGRectGetMinX(content)-CGRectGetMinX(bounds);
    CGFloat right=CGRectGetMaxX(bounds)-CGRectGetMaxX(content);
    BOOL onLeft=left>=right;
    CGFloat width=MAX(left,right);
    if (width<24 || width>bounds.size.width*0.3) {
        static BOOL reported=NO;
        if (!reported) { reported=YES; HTLog([NSString stringWithFormat:@"WAIT inset bounds=%@ home=%@",NSStringFromCGRect(bounds),NSStringFromCGRect(content)]); }
        HTBatteryLayer.hidden=YES;
        return;
    }
    BOOL created=NO;
    if (!HTBatteryLayer || HTBatteryLayer.superlayer!=source.layer) {
        HTReleaseBatteryLayer();
        HTBatteryLayer=[CALayer layer];
        HTBatteryLayer.name=@"HomeTA.DockBattery";
        HTBatteryLayer.zPosition=10000;
        HTBatteryLayer.contentsGravity=kCAGravityResizeAspect;
        HTBatteryLayer.actions=@{@"contents":NSNull.null,@"position":NSNull.null,
            @"bounds":NSNull.null,@"hidden":NSNull.null};
        [source.layer addSublayer:HTBatteryLayer];
        HTBattery=[HTBatteryView new]; HTBattery.level=-2;
        HTBatteryScene=scene;
        created=YES;
    }
    CGFloat scale=MIN(MAX(bounds.size.height/240.0,0.8),1.6);
    CGFloat start=onLeft ? CGRectGetMinX(bounds) : CGRectGetMaxX(content);
    CGFloat bw=MIN(22*scale,width-12),bh=11*scale;
    CGRect battery=CGRectMake(start+(width-bw)/2,CGRectGetMinY(bounds)+bounds.size.height*0.19,bw,bh);
    BOOL changed=!CGRectEqualToRect(HTBatteryLayer.frame,battery);
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    HTBatteryLayer.frame=battery;
    HTBatteryLayer.hidden=!HTSceneVisible(scene);
    [CATransaction commit];
    HTUpdateBattery();
    if (created || changed) {
        HTLog([NSString stringWithFormat:@"DOCK LAYER battery=%@ source=%@ active=%ld hidden=%d newWindow=NO",
            NSStringFromCGRect(battery),NSStringFromCGRect(bounds),
            (long)scene.activationState,HTBatteryLayer.hidden]);
    }
}
static void HTScheduleLayout(void) {
    if (HTScheduled) return;
    HTScheduled=YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        HTScheduled=NO; HTLayoutBatteryLayer();
    });
}
static void HTAttachHome(UIView *icon) {
    UIWindow *window=icon.window;
    if (!window) return;
    UIView *home=icon;
    while (home && ![NSStringFromClass(home.class) isEqualToString:@"DBAnimationView"]) home=home.superview;
    if (!home) return;
    HTWallpaper *wall=objc_getAssociatedObject(home,&HTWallpaperKey);
    if (!wall) {
        wall=[[HTWallpaper alloc] initWithFrame:home.bounds];
        wall.userInteractionEnabled=NO; wall.opaque=YES;
        wall.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        wall.contentMode=UIViewContentModeRedraw;
        [home insertSubview:wall atIndex:0];
        objc_setAssociatedObject(home,&HTWallpaperKey,wall,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        HTLog([NSString stringWithFormat:@"HOME theme attached frame=%@",NSStringFromCGRect(home.bounds)]);
    }
    if (!CGRectEqualToRect(wall.frame,home.bounds)) wall.frame=home.bounds;
    BOOL newSource=HTSource!=window || HTHome!=home;
    HTSource=window; HTHome=home;
    HTScheduleLayout();
    if (newSource) {
        // Finite readiness retries, not a repeating scene scan or render loop.
        __weak UIWindow *expected=window;
        for (NSNumber *delay in @[@0.3,@1.0,@2.0]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                if (expected && HTSource==expected) HTLayoutBatteryLayer();
            });
        }
    }
}
%hook SBIconImageView
- (void)layoutSubviews {
    %orig;
    self.layer.borderWidth=0.5;
    self.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.18].CGColor;
    self.layer.cornerRadius=MIN(self.bounds.size.width,self.bounds.size.height)*0.20;
    self.layer.cornerCurve=kCACornerCurveContinuous;
    HTAttachHome(self);
}
%end
%hook DBIconLabelBackdropView
- (void)layoutSubviews {
    %orig;
    self.backgroundColor=[UIColor colorWithWhite:0.025 alpha:0.42];
    self.layer.borderWidth=0;
    self.layer.cornerRadius=5;
    self.layer.cornerCurve=kCACornerCurveContinuous;
    self.layer.masksToBounds=YES;
    for (UIView *child in self.subviews) {
        if ([NSStringFromClass(child.class) containsString:@"DBDashboardPlatterView"]) child.alpha=0.20;
    }
}
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.CarPlayApp"]) return;
        UIDevice.currentDevice.batteryMonitoringEnabled=YES;
        HTObservers=[NSMutableArray new];
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        for (NSString *name in @[UIDeviceBatteryLevelDidChangeNotification,UIDeviceBatteryStateDidChangeNotification,NSProcessInfoPowerStateDidChangeNotification]) {
            [HTObservers addObject:[center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *n){ HTUpdateBattery(); }]];
        }
        for (NSString *name in @[UISceneDidActivateNotification,UISceneWillEnterForegroundNotification]) {
            [HTObservers addObject:[center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){
                if (n.object==HTSource.windowScene) HTScheduleLayout();
            }]];
        }
        [HTObservers addObject:[center addObserverForName:UISceneDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){
            if (n.object==HTBatteryScene) HTBatteryLayer.hidden=YES;
        }]];
        [HTObservers addObject:[center addObserverForName:UISceneDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){
            if (n.object==HTSource.windowScene || n.object==HTBatteryScene) {
                HTReleaseBatteryLayer(); HTSource=nil; HTHome=nil;
            }
        }]];
        HTLog(@"LOADED reference Home + battery CALayer; no overlay UIWindow; no recurring timer");
        %init;
    }
}
