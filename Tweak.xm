// HomeTA 0.5.5 — based on 0.5.3; custom wallpaper pinned to the source window.
// The wallpaper is outside the Home/app animation and snapshot subtrees.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface SBIconImageView : UIImageView @end
@interface DBIconLabelBackdropView : UIView @end
@interface DBAnimationView : UIView @end
@interface CALayer (HTPrivate)
@property(nonatomic) BOOL allowsHitTesting; // private QuartzCore; guarded by respondsToSelector
@end

#define HT_VERSION @"0.5.5"

static void HTLog(NSString *message) {
    NSString *path=@"/var/mobile/HomeTA.log";
    NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attrs fileSize]>256*1024) {
        [NSFileManager.defaultManager removeItemAtPath:[path stringByAppendingString:@".1"] error:nil];
        [NSFileManager.defaultManager moveItemAtPath:path toPath:[path stringByAppendingString:@".1"] error:nil];
    }
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA %@] %@\n",NSDate.date,HT_VERSION,message] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (__unused NSException *e) {}
    @finally { [handle closeFile]; }
}

// Every layer HomeTA adds is excluded from render-server hit testing, so backboardd
// never routes a touch to our context/layer instead of the dock.
static void HTNoHit(CALayer *layer) {
    if ([layer respondsToSelector:@selector(setAllowsHitTesting:)]) layer.allowsHitTesting=NO;
}
static UIColor *HTRGB(uint32_t hex, CGFloat a) {
    return [UIColor colorWithRed:((hex>>16)&0xFF)/255.0 green:((hex>>8)&0xFF)/255.0 blue:(hex&0xFF)/255.0 alpha:a];
}
static NSString *HTChain(UIView *v) {
    NSMutableArray *parts=[NSMutableArray new];
    for (UIView *x=v; x && parts.count<10; x=x.superview)
        [parts addObject:[NSString stringWithFormat:@"%@%@%@",NSStringFromClass(x.class),
            x.userInteractionEnabled?@"":@"(noUI)",x.hidden?@"(hidden)":@""]];
    return parts.count ? [parts componentsJoinedByString:@" < "] : @"nil";
}

#pragma mark - Wallpaper (iOS 27 "Celosia"-inspired layered curves, light/dark)

@interface HTWallpaper : UIView
@property(nonatomic) NSInteger htStyle; // 0 auto, 1 light, 2 dark (offscreen rendering)
@end
@implementation HTWallpaper
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if (previous.userInterfaceStyle!=self.traitCollection.userInterfaceStyle) [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();
    CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    if (w<1 || h<1) return;
    BOOL dark=self.htStyle ? self.htStyle==2 : self.traitCollection.userInterfaceStyle!=UIUserInterfaceStyleLight;
    // base top, base bottom, then 4 layers x (top, bottom)
    static const uint32_t darkP[]={0x060A20,0x0D1440, 0x121D55,0x0B143C, 0x1C2E7E,0x121F58, 0x2B45AA,0x1C2F7C, 0x5271D6,0x3450AE};
    static const uint32_t lightP[]={0xEAF0FF,0xD3DEFF, 0xC4D3FF,0xAFC3FA, 0xA0B8FA,0x88A3F0, 0x7D99EE,0x6684E0, 0x5D7CDF,0x4867CC};
    const uint32_t *p=dark ? darkP : lightP;
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGFloat loc[]={0,1};

    CGGradientRef base=CGGradientCreateWithColors(space,(__bridge CFArrayRef)@[(id)HTRGB(p[0],1).CGColor,(id)HTRGB(p[1],1).CGColor],loc);
    CGContextDrawLinearGradient(c,base,CGPointMake(0,0),CGPointMake(w*0.3,h),kCGGradientDrawsBeforeStartLocation|kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(base);

    for (NSUInteger i=0;i<4;i++) {
        CGFloat x0=w*(0.06+0.19*i), x1=w*(0.46+0.15*i);
        UIBezierPath *edge=[UIBezierPath bezierPath];
        [edge moveToPoint:CGPointMake(x0,h+2)];
        [edge addCurveToPoint:CGPointMake(x1,-2)
                controlPoint1:CGPointMake(x0+w*0.32,h*0.66)
                controlPoint2:CGPointMake(x1-w*0.30,h*0.38)];
        UIBezierPath *region=[edge copy];
        [region addLineToPoint:CGPointMake(w+2,-2)];
        [region addLineToPoint:CGPointMake(w+2,h+2)];
        [region closePath];

        // Soft shadow cast back onto the previous layer ("folded paper" depth).
        CGContextSaveGState(c);
        CGContextSetShadowWithColor(c,CGSizeMake(-w*0.006,0),h*0.09,[UIColor colorWithWhite:0 alpha:dark?0.55:0.20].CGColor);
        [HTRGB(p[3+2*i],1) setFill];
        [region fill];
        CGContextRestoreGState(c);

        CGContextSaveGState(c);
        [region addClip];
        CGGradientRef g=CGGradientCreateWithColors(space,(__bridge CFArrayRef)@[(id)HTRGB(p[2+2*i],1).CGColor,(id)HTRGB(p[3+2*i],1).CGColor],loc);
        CGContextDrawLinearGradient(c,g,CGPointMake(x1,0),CGPointMake(x0,h),0);
        CGGradientRelease(g);
        CGContextRestoreGState(c);

        edge.lineWidth=1;
        [[UIColor colorWithWhite:1 alpha:dark?0.10:0.35] setStroke];
        [edge stroke];
    }
    CGColorSpaceRelease(space);
}
@end

#pragma mark - Battery (iOS 27 borderless style)

@interface HTBatteryView : UIView
@property(nonatomic) float level;
@property(nonatomic) UIDeviceBatteryState state;
@property(nonatomic) BOOL lowPower;
@end
@implementation HTBatteryView
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();
    CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    CGFloat nubW=MAX(1.5,h*0.13),gap=MAX(1,h*0.09);
    CGFloat bodyW=w-nubW-gap;
    CGRect body=CGRectMake(0,0,bodyW,h);
    UIBezierPath *shell=[UIBezierPath bezierPathWithRoundedRect:body cornerRadius:h*0.36];

    BOOL known=self.level>=0;
    NSInteger pct=known ? lroundf(self.level*100) : -1;
    BOOL charging=self.state==UIDeviceBatteryStateCharging;
    BOOL full=self.state==UIDeviceBatteryStateFull;
    BOOL critical=known && !charging && !full && pct<=20;
    UIColor *fillColor=nil; UIColor *ink=nil;
    if (self.lowPower)          { fillColor=UIColor.systemYellowColor; ink=[UIColor colorWithWhite:0 alpha:0.85]; }
    else if (charging || full)  { fillColor=UIColor.systemGreenColor;  ink=[UIColor colorWithWhite:0 alpha:0.85]; }
    else if (critical)          { fillColor=UIColor.systemRedColor;    ink=UIColor.whiteColor; }

    // Borderless: translucent track + solid fill, no outline stroke.
    [[UIColor colorWithWhite:1 alpha:0.32] setFill];
    [shell fill];
    [[UIColor colorWithWhite:1 alpha:0.40] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(bodyW+gap,h*0.32,nubW,h*0.36)
                           byRoundingCorners:UIRectCornerTopRight|UIRectCornerBottomRight
                                 cornerRadii:CGSizeMake(nubW,nubW)] fill];

    CGFloat fillW=known ? bodyW*MIN(1,MAX(0.02,self.level)) : 0;
    CGRect fillRect=CGRectMake(0,0,fillW,h);
    if (fillW>0) {
        CGContextSaveGState(c);
        [shell addClip];
        [(fillColor ?: UIColor.whiteColor) setFill];
        UIRectFill(fillRect);
        CGContextRestoreGState(c);
    }

    if (charging) {
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:h*0.74 weight:UIImageSymbolWeightBlack];
        UIImage *bolt=[[UIImage systemImageNamed:@"bolt.fill" withConfiguration:cfg] imageWithTintColor:ink renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (bolt) {
            CGSize s=bolt.size;
            [bolt drawInRect:CGRectMake((bodyW-s.width)/2,(h-s.height)/2,s.width,s.height)];
        }
        return;
    }

    BOOL hundred=pct>=100;
    CGFloat fs=h*(hundred ? 0.66 : 0.74);
    UIFont *font=hundred ? [UIFont systemFontOfSize:fs weight:UIFontWeightBold]
                         : [UIFont monospacedDigitSystemFontOfSize:fs weight:UIFontWeightBold];
    NSString *text=known ? [NSString stringWithFormat:@"%ld",(long)pct] : @"–";
    NSDictionary *measure=@{NSFontAttributeName:font};
    CGSize ts=[text sizeWithAttributes:measure];
    // Center on cap height, not line height, so digits sit optically in the middle.
    CGFloat baseline=(h+font.capHeight)/2;
    CGPoint at=CGPointMake((bodyW-ts.width)/2,baseline-font.ascender);

    if (fillColor) {
        // Colored states: solid fill, plain text (no cutout).
        [text drawAtPoint:at withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:ink}];
        return;
    }
    // Normal: digits punched through the white fill, white where they sit over the track.
    CGContextSaveGState(c);
    CGContextClipToRect(c,fillRect);
    CGContextSetBlendMode(c,kCGBlendModeDestinationOut);
    [text drawAtPoint:at withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:UIColor.blackColor}];
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    CGContextClipToRect(c,CGRectMake(fillW,0,bodyW-fillW,h));
    [text drawAtPoint:at withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:[UIColor colorWithWhite:1 alpha:0.95]}];
    CGContextRestoreGState(c);
}
@end

#pragma mark - State

// The battery is a bitmap CALayer in the existing window, never a UIWindow or UIView.
static CALayer *HTBatteryLayer;
static HTBatteryView *HTBattery;
static __weak UIWindowScene *HTBatteryScene;
static CGSize HTRenderedSize;
static CGFloat HTRenderedScale;
static __weak UIView *HTHome;
static __weak UIWindow *HTSource;
static __weak UIWindow *HTProbed;
static BOOL HTScheduled=NO;
static BOOL HTDockIconLogged=NO;
static char HTRimKey;
static NSMutableArray *HTObservers;
static NSInteger HTLoggedLevel=-999;
static NSInteger HTLoggedState=-999;

static BOOL HTSceneVisible(UIWindowScene *scene) {
    return scene && (scene.activationState==UISceneActivationStateForegroundActive ||
                     scene.activationState==UISceneActivationStateForegroundInactive);
}

// Left/right strip beside the Home content = native dock area.
static BOOL HTDockRect(UIWindow *source, UIView *home, CGRect *outDock, BOOL *outLeft) {
    if (!source || !home || home.window!=source) return NO;
    CGRect bounds=source.bounds;
    CGRect content=[home convertRect:home.bounds toView:source];
    CGFloat left=CGRectGetMinX(content)-CGRectGetMinX(bounds);
    CGFloat right=CGRectGetMaxX(bounds)-CGRectGetMaxX(content);
    BOOL onLeft=left>=right;
    CGFloat width=MAX(left,right);
    if (width<24 || width>bounds.size.width*0.3) return NO;
    CGFloat x=onLeft ? CGRectGetMinX(bounds) : CGRectGetMaxX(content);
    if (outDock) *outDock=CGRectMake(x,CGRectGetMinY(bounds),width,bounds.size.height);
    if (outLeft) *outLeft=onLeft;
    return YES;
}

// One-shot diagnostic: which view UIKit would deliver a dock touch to, plus every window in the scene.
static void HTProbeDock(void) {
    UIWindow *source=HTSource; UIView *home=HTHome;
    if (!source || HTProbed==source) return;
    CGRect dock;
    if (!HTDockRect(source,home,&dock,NULL)) return;
    HTProbed=source;
    for (NSNumber *f in @[@0.40,@0.55,@0.70,@0.92]) {
        CGPoint pt=CGPointMake(CGRectGetMidX(dock),CGRectGetMinY(dock)+dock.size.height*f.doubleValue);
        UIView *hit=[source hitTest:pt withEvent:nil];
        HTLog([NSString stringWithFormat:@"PROBE dock y=%.2f pt=%@ hit=%@",f.doubleValue,NSStringFromCGPoint(pt),HTChain(hit)]);
    }
    for (UIWindow *w in source.windowScene.windows) {
        HTLog([NSString stringWithFormat:@"WINDOW %@ level=%.0f frame=%@ hidden=%d alpha=%.2f ui=%d key=%d",
            NSStringFromClass(w.class),w.windowLevel,NSStringFromCGRect(w.frame),w.hidden,w.alpha,w.userInteractionEnabled,w.isKeyWindow]);
    }
}

// The dock/status bar lives in DBStatusBarHostWindow (level 5), above the Home window (level -2/-1),
// so the battery must be a sublayer of that window's layer tree to be visible.
static UIWindow *HTDockWindow(UIWindowScene *scene) {
    for (UIWindow *w in scene.windows)
        if ([NSStringFromClass(w.class) isEqualToString:@"DBStatusBarHostWindow"]) return w;
    return nil;
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
        HTLog([NSString stringWithFormat:@"BATTERY percent=%ld state=%ld lowPower=%d",(long)percent,(long)state,low]);
    }
}
static void HTReleaseBatteryLayer(void) {
    [HTBatteryLayer removeFromSuperlayer];
    HTBatteryLayer=nil; HTBattery=nil; HTBatteryScene=nil;
    HTRenderedSize=CGSizeZero; HTRenderedScale=0;
}

#pragma mark - Fixed wallpaper outside the animated Home subtree

static CALayer *HTWallLayer;
static __weak UIWindow *HTWallWindow;
static HTWallpaper *HTWallPainter;
static CGSize HTWallSize;
static CGFloat HTWallScale;
static NSInteger HTWallStyle;

static void HTReleaseWallpaper(void) {
    [HTWallLayer removeFromSuperlayer];
    HTWallLayer=nil; HTWallWindow=nil; HTWallPainter=nil;
    HTWallSize=CGSizeZero; HTWallScale=0; HTWallStyle=0;
}

static void HTUpdateFixedWallpaper(void) {
    UIWindow *window=HTSource;
    if (!window || !HTHome || HTHome.window!=window || CGRectIsEmpty(window.bounds)) return;
    BOOL created=HTWallWindow!=window || !HTWallLayer;
    if (created) {
        HTReleaseWallpaper();
        HTWallWindow=window;
        HTWallLayer=[CALayer layer];
        HTWallLayer.name=@"HomeTA.FixedWallpaper";
        HTWallLayer.contentsGravity=kCAGravityResize;
        HTWallLayer.opaque=YES;
        HTWallLayer.masksToBounds=YES;
        HTWallLayer.actions=@{@"contents":NSNull.null,@"position":NSNull.null,
            @"bounds":NSNull.null,@"transform":NSNull.null,@"opacity":NSNull.null,
            @"hidden":NSNull.null,@"zPosition":NSNull.null};
        HTNoHit(HTWallLayer);
        HTWallPainter=[HTWallpaper new];
    }
    // A direct source-window sublayer: above the stock background window,
    // below BOTH the remote app host and Home container. Never put the
    // wallpaper in DBAnimationView or its parent (which may also animate).
    CALayer *parent=window.layer;
    CGFloat bottomZ=0;
    for (CALayer *child in parent.sublayers)
        if (child!=HTWallLayer) bottomZ=MIN(bottomZ,child.zPosition);
    CGSize size=window.bounds.size;
    CGFloat scale=MAX(1,window.screen.scale);
    NSInteger style=window.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight ? 1 : 2;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (HTWallLayer.superlayer!=parent || parent.sublayers.firstObject!=HTWallLayer)
        [parent insertSublayer:HTWallLayer atIndex:0];
    HTWallLayer.zPosition=bottomZ-1;
    HTWallLayer.transform=CATransform3DIdentity;
    HTWallLayer.opacity=1;
    HTWallLayer.hidden=NO;
    HTWallLayer.frame=window.bounds;
    if (!CGSizeEqualToSize(size,HTWallSize) || scale!=HTWallScale || style!=HTWallStyle || !HTWallLayer.contents) {
        HTWallPainter.htStyle=style;
        HTWallPainter.bounds=(CGRect){CGPointZero,size};
        UIGraphicsBeginImageContextWithOptions(size,YES,scale);
        [HTWallPainter drawRect:HTWallPainter.bounds];
        UIImage *image=UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        HTWallLayer.contentsScale=scale;
        HTWallLayer.contents=(__bridge id)image.CGImage;
        HTWallSize=size; HTWallScale=scale; HTWallStyle=style;
        HTLog([NSString stringWithFormat:@"WALL FIXED sourceLevel=%.0f bounds=%@ style=%ld created=%d outsideHome=1 contents=%d",
            window.windowLevel,NSStringFromCGRect(window.bounds),(long)style,created,HTWallLayer.contents!=nil]);
    }
    [CATransaction commit];
}

static void HTLayoutBatteryLayer(void) {
    UIWindow *source=HTSource;
    UIView *home=HTHome;
    UIWindowScene *scene=source.windowScene;
    if (!scene) return;
    HTUpdateFixedWallpaper();
    CGRect dock; BOOL onLeft=YES;
    if (!HTDockRect(source,home,&dock,&onLeft)) {
        static BOOL reported=NO;
        if (!reported && source && home) { reported=YES; HTLog([NSString stringWithFormat:@"WAIT inset bounds=%@ home=%@",NSStringFromCGRect(source.bounds),NSStringFromCGRect([home convertRect:home.bounds toView:source])]); }
        HTBatteryLayer.hidden=YES;
        return;
    }
    UIWindow *host=HTDockWindow(scene);
    CALayer *parent=(host ?: source).layer;
    BOOL created=NO;
    if (!HTBatteryLayer || HTBatteryLayer.superlayer!=parent) {
        HTReleaseBatteryLayer();
        HTBatteryLayer=[CALayer layer];
        HTBatteryLayer.name=@"HomeTA.DockBattery";
        HTBatteryLayer.contentsGravity=kCAGravityResizeAspect;
        HTBatteryLayer.actions=@{@"contents":NSNull.null,@"position":NSNull.null,
            @"bounds":NSNull.null,@"hidden":NSNull.null};
        HTNoHit(HTBatteryLayer);
        [parent addSublayer:HTBatteryLayer];
        HTBattery=[HTBatteryView new]; HTBattery.level=-2;
        HTBatteryScene=scene;
        created=YES;
    }
    CGRect bounds=source.bounds;
    CGFloat scale=MIN(MAX(bounds.size.height/240.0,0.8),1.6);
    const CGFloat aspect=2.35;
    CGFloat bh=11*scale, bw=bh*aspect;
    if (bw>dock.size.width-12) { bw=dock.size.width-12; bh=bw/aspect; }
    CGRect battery=CGRectMake(CGRectGetMinX(dock)+(dock.size.width-bw)/2,CGRectGetMinY(bounds)+bounds.size.height*0.19,bw,bh);
    if (host) battery=[host convertRect:battery fromWindow:source];
    battery=CGRectIntegral(battery);
    BOOL changed=!CGRectEqualToRect(HTBatteryLayer.frame,battery);
    // Stay above every sibling layer (the native dock backdrop sits above zPosition 100 on some units).
    CGFloat topZ=0; NSUInteger siblings=0;
    for (CALayer *l in parent.sublayers) { if (l!=HTBatteryLayer) { topZ=MAX(topZ,l.zPosition); siblings++; } }
    CGFloat wantZ=MAX(10000,topZ+1);
    BOOL isLast=parent.sublayers.lastObject==HTBatteryLayer;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (!isLast) { [HTBatteryLayer removeFromSuperlayer]; [parent addSublayer:HTBatteryLayer]; changed=YES; }
    if (HTBatteryLayer.zPosition!=wantZ) { HTBatteryLayer.zPosition=wantZ; changed=YES; }
    HTBatteryLayer.frame=battery;
    HTBatteryLayer.hidden=!HTSceneVisible(scene);
    [CATransaction commit];
    HTUpdateBattery();
    if (created || changed) {
        HTLog([NSString stringWithFormat:@"DOCK LAYER host=%@ battery=%@ dock=%@ left=%d active=%ld hidden=%d z=%.0f siblingTopZ=%.0f siblings=%lu contents=%d hitTestOff=%d",
            host ? NSStringFromClass(host.class) : @"source(fallback)",NSStringFromCGRect(battery),NSStringFromCGRect(dock),onLeft,(long)scene.activationState,HTBatteryLayer.hidden,
            HTBatteryLayer.zPosition,topZ,(unsigned long)siblings,HTBatteryLayer.contents!=nil,
            [HTBatteryLayer respondsToSelector:@selector(allowsHitTesting)] ? !HTBatteryLayer.allowsHitTesting : -1]);
    }
}
static void HTScheduleLayout(void) {
    if (HTScheduled) return;
    HTScheduled=YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        HTScheduled=NO; HTLayoutBatteryLayer();
    });
}

#pragma mark - Home attach (dock-safe)

static BOOL HTInsideDock(UIView *v) {
    for (UIView *x=v; x; x=x.superview) {
        NSString *n=NSStringFromClass(x.class);
        if ([n rangeOfString:@"Dock"].location!=NSNotFound || [n rangeOfString:@"StatusBar"].location!=NSNotFound) return YES;
    }
    return NO;
}
static void HTAttachHome(UIView *icon) {
    UIWindow *window=icon.window;
    if (!window) return;
    if (HTInsideDock(icon)) {
        if (!HTDockIconLogged) { HTDockIconLogged=YES; HTLog([NSString stringWithFormat:@"DOCK icon chain=%@",HTChain(icon)]); }
        return; // never touch dock containers
    }
    // Only the wide Home content container qualifies; a narrow DBAnimationView (e.g. in the dock) is skipped.
    UIView *home=icon.superview;
    while (home && !([NSStringFromClass(home.class) isEqualToString:@"DBAnimationView"] &&
                     home.bounds.size.width>=window.bounds.size.width*0.5)) home=home.superview;
    if (!home) return;
    BOOL newSource=HTSource!=window || HTHome!=home;
    HTSource=window; HTHome=home;
    // No wallpaper UIView is inserted into Home. Snapshots/animations of
    // Home now contain icons and labels only, never our background.
    HTUpdateFixedWallpaper();
    HTScheduleLayout();
    if (newSource) {
        // Finite readiness retries, not a repeating scene scan or render loop.
        __weak UIWindow *expected=window;
        for (NSNumber *delay in @[@0.3,@1.0,@2.0]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                if (expected && HTSource==expected) HTLayoutBatteryLayer();
            });
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            if (expected && HTSource==expected) HTProbeDock();
        });
    }
}

#pragma mark - Liquid Glass-style icon rim

static void HTApplyGlass(UIView *iconView) {
    CGRect b=iconView.bounds;
    if (b.size.width<8 || b.size.height<8) return;
    CGFloat r=MIN(b.size.width,b.size.height)*0.225;
    iconView.layer.borderWidth=0;
    iconView.layer.cornerRadius=r;
    iconView.layer.cornerCurve=kCACornerCurveContinuous;
    CAGradientLayer *rim=objc_getAssociatedObject(iconView,&HTRimKey);
    if (!rim) {
        rim=[CAGradientLayer layer];
        rim.name=@"HomeTA.GlassRim";
        rim.colors=@[(id)[UIColor colorWithWhite:1 alpha:0.60].CGColor,(id)[UIColor colorWithWhite:1 alpha:0.06].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0.06].CGColor,(id)[UIColor colorWithWhite:1 alpha:0.28].CGColor];
        rim.locations=@[@0,@0.35,@0.70,@1];
        rim.startPoint=CGPointMake(0.2,0); rim.endPoint=CGPointMake(0.8,1);
        rim.actions=@{@"position":NSNull.null,@"bounds":NSNull.null,@"frame":NSNull.null};
        CAShapeLayer *mask=[CAShapeLayer layer];
        mask.fillColor=nil; mask.strokeColor=UIColor.blackColor.CGColor; mask.lineWidth=1.0;
        mask.actions=@{@"path":NSNull.null,@"position":NSNull.null,@"bounds":NSNull.null};
        rim.mask=mask;
        HTNoHit(rim);
        [iconView.layer addSublayer:rim];
        objc_setAssociatedObject(iconView,&HTRimKey,rim,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!CGRectEqualToRect(rim.frame,b)) {
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        rim.frame=b;
        CAShapeLayer *mask=(CAShapeLayer *)rim.mask;
        mask.frame=(CGRect){CGPointZero,b.size};
        mask.path=[UIBezierPath bezierPathWithRoundedRect:CGRectInset((CGRect){CGPointZero,b.size},0.5,0.5) cornerRadius:r-0.5].CGPath;
        [CATransaction commit];
    }
}

%hook DBAnimationView
- (void)layoutSubviews {
    %orig;
    if (self==HTHome) HTUpdateFixedWallpaper();
}
%end

// Only the known source window is affected. Its bounds/appearance define
// the stationary background, independent of animated Home geometry.
%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self==HTSource) HTUpdateFixedWallpaper();
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    %orig;
    if (self==HTSource && previous.userInterfaceStyle!=self.traitCollection.userInterfaceStyle)
        HTUpdateFixedWallpaper();
}
%end

%hook SBIconImageView
- (void)layoutSubviews {
    %orig;
    HTApplyGlass(self);
    HTAttachHome(self);
}
%end

%hook DBIconLabelBackdropView
- (void)layoutSubviews {
    %orig;
    // iOS 26/27 CarPlay: plain white label over the wallpaper, no dark pill; soft shadow for legibility.
    self.backgroundColor=UIColor.clearColor;
    self.layer.borderWidth=0;
    self.layer.masksToBounds=NO;
    self.layer.shadowColor=UIColor.blackColor.CGColor;
    self.layer.shadowOpacity=0.35;
    self.layer.shadowRadius=3;
    self.layer.shadowOffset=CGSizeMake(0,1);
    for (UIView *child in self.subviews) {
        if ([NSStringFromClass(child.class) containsString:@"DBDashboardPlatterView"]) child.alpha=0;
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
                HTReleaseBatteryLayer(); HTReleaseWallpaper(); HTSource=nil; HTHome=nil; HTProbed=nil;
            }
        }]];
        HTLog(@"LOADED base=0.5.3 fixed window wallpaper + borderless battery; layers hit-test off; no overlay window; no timer");
        %init;
    }
}

