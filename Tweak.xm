// HomeTA 0.9.5 — iOS 27-style CarPlay Home (Celosia-inspired wallpaper, Liquid Glass icon rim,
// borderless battery) + dock touch hardening and one-shot dock hit-test diagnostics.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface SBIconImageView : UIImageView @end
@interface DBIconLabelBackdropView : UIView @end
@interface CALayer (HTPrivate)
@property(nonatomic) BOOL allowsHitTesting; // private QuartzCore; guarded by respondsToSelector
@end

#define HT_VERSION @"0.9.5"

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
    // Normal: dark ink over the white fill, white ink over the empty track — two plain fills,
    // split by a hard clip. The previous version used a destination-out blend to "punch" the
    // digits through the fill, but this layer's bitmap has an alpha channel, so the punch left a
    // truly transparent hole; wherever the fill boundary crossed a glyph stroke, the opaque and
    // transparent halves of that stroke no longer lined up, reading as a doubled/ghosted outline.
    UIColor *darkInk=[UIColor colorWithRed:0.04 green:0.10 blue:0.28 alpha:0.92];
    CGContextSaveGState(c);
    CGContextClipToRect(c,fillRect);
    [text drawAtPoint:at withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:darkInk}];
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

#pragma mark - Window-level wallpaper (real UIView, not a bare CALayer)
// Recovered from the 0.5.4 build (the one photo-confirmed working on this exact unit): the
// wallpaper was inserted with insertSubview:atIndex: -- an actual UIView -- not insertSublayer:
// on a bare CALayer. Every later rewrite (0.6.x-0.7.x) used a raw CALayer instead, and never
// rendered on screen despite identical positioning/z-order logic, on this same device. Restoring
// the real-UIView approach here; still applied to every negative-level window since the earlier
// window-swap bug (painting only the currently-hidden buffer) was independently real and correct.
static char HTWallViewKey;

static void HTPaintWallpaperOnWindow(UIWindow *window) {
    if (!window || CGRectIsEmpty(window.bounds)) return;
    HTWallpaper *wall=objc_getAssociatedObject(window,&HTWallViewKey);
    BOOL created=NO;
    if (!wall) {
        wall=[[HTWallpaper alloc] initWithFrame:window.bounds];
        wall.userInteractionEnabled=NO;
        wall.opaque=YES;
        wall.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        wall.contentMode=UIViewContentModeRedraw;
        objc_setAssociatedObject(window,&HTWallViewKey,wall,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        created=YES;
    }
    if (wall.superview!=window || window.subviews.firstObject!=wall) {
        [wall removeFromSuperview];
        [window insertSubview:wall atIndex:0];
    }
    if (!CGRectEqualToRect(wall.frame,window.bounds)) wall.frame=window.bounds;
    NSInteger style=window.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight ? 1 : 2;
    if (wall.htStyle!=style) { wall.htStyle=style; [wall setNeedsDisplay]; }
    if (created) HTLog([NSString stringWithFormat:@"WALL view attached window=%p level=%.0f hidden=%d bounds=%@ style=%ld",
        (void*)window,window.windowLevel,window.hidden,NSStringFromCGRect(window.bounds),(long)style]);
}

static void HTUpdateWindowWallpaper(void) {
    UIWindowScene *scene=HTSource.windowScene;
    if (!scene) return;
    for (UIWindow *w in scene.windows) {
        if (w.windowLevel<0) HTPaintWallpaperOnWindow(w);
    }
}

#pragma mark - One-shot diagnostics (Home layer tree with frames, dock view tree)
static BOOL HTHomeTreeLogged=NO;
static NSString *HTLayerTree(CALayer *l, NSUInteger depth) {
    NSMutableString *out=[NSMutableString stringWithFormat:@"%@(z=%.0f,op=%d,a=%.2f,f=%@)",
        NSStringFromClass(l.class),l.zPosition,l.opaque,l.opacity,NSStringFromCGRect(l.frame)];
    if (depth && l.sublayers.count) {
        [out appendString:@"["];
        NSUInteger i=0;
        for (CALayer *sub in l.sublayers) { if (i++) [out appendString:@","]; if (i>8) { [out appendString:@"…"]; break; } [out appendString:HTLayerTree(sub,depth-1)]; }
        [out appendString:@"]"];
    }
    return out;
}
static void HTLogHomeTreeOnce(UIWindow *window) {
    if (HTHomeTreeLogged || !window) return;
    HTHomeTreeLogged=YES;
    HTLog([NSString stringWithFormat:@"HOMETREE window=%p %@",(void*)window,HTLayerTree(window.layer,7)]);
}

static NSString *HTTree(UIView *v, NSUInteger depth) {
    NSMutableString *out=[NSMutableString stringWithString:NSStringFromClass(v.class)];
    if (depth && v.subviews.count) {
        [out appendString:@"{"];
        NSUInteger i=0;
        for (UIView *sub in v.subviews) { if (i++) [out appendString:@","]; if (i>6) { [out appendString:@"…"]; break; } [out appendString:HTTree(sub,depth-1)]; }
        [out appendString:@"}"];
    }
    return out;
}
static BOOL HTDockTreeLogged=NO;
static void HTLogDockTreeOnce(UIWindowScene *scene) {
    if (HTDockTreeLogged) return;
    for (UIWindow *w in scene.windows) {
        if (![NSStringFromClass(w.class) isEqualToString:@"DBStatusBarHostWindow"]) continue;
        HTDockTreeLogged=YES;
        HTLog([NSString stringWithFormat:@"DOCKTREE %@",HTTree(w,6)]);
        break;
    }
}

#pragma mark - Dock rounded-card overlay (touch-safe: never touches the real dock's frame)
static char HTDockMaskKey;
static CGRect HTDockMaskRect;
static BOOL HTDockMaskDark;

static void HTUpdateDockRoundedMask(UIWindow *host, CGRect dock, BOOL onLeft, BOOL dark) {
    if (!host || CGRectIsEmpty(dock)) return;
    CALayer *mask=objc_getAssociatedObject(host,&HTDockMaskKey);
    BOOL created=NO;
    if (!mask) {
        mask=[CALayer layer];
        mask.name=@"HomeTA.DockRoundMask";
        mask.contentsGravity=kCAGravityResize;
        mask.actions=@{@"contents":NSNull.null,@"position":NSNull.null,@"bounds":NSNull.null,@"hidden":NSNull.null};
        HTNoHit(mask);
        objc_setAssociatedObject(host,&HTDockMaskKey,mask,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        created=YES;
    }
    if (mask.superlayer!=host.layer) { [mask removeFromSuperlayer]; [host.layer addSublayer:mask]; }
    // Render the same deterministic wallpaper pattern into a temporary full-window bitmap and crop
    // the dock's own region out of it, so the two corner patches match pixel-for-pixel. (The real
    // wallpaper is now a UIView with its own drawRect:, not a cached CALayer bitmap, so this can't
    // just read back .contents the way it used to -- render fresh here instead.)
    NSInteger wallStyleNow=HTSource.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight ? 1 : 2;
    CGImageRef wallImage=NULL;
    UIImage *fullWallImage=nil;
    if (HTSource && !CGRectIsEmpty(HTSource.bounds)) {
        HTWallpaper *tmp=[HTWallpaper new];
        tmp.htStyle=wallStyleNow;
        tmp.bounds=(CGRect){CGPointZero,HTSource.bounds.size};
        UIGraphicsBeginImageContextWithOptions(HTSource.bounds.size,YES,MAX(1,HTSource.screen.scale ?: 2));
        [tmp drawRect:tmp.bounds];
        fullWallImage=UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        wallImage=fullWallImage.CGImage;
    }
    (void)fullWallImage;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    mask.frame=dock;
    CGFloat maskWantZ=999999;
    if (mask.zPosition!=maskWantZ) mask.zPosition=maskWantZ;
    if (created || !CGRectEqualToRect(dock,HTDockMaskRect) || dark!=HTDockMaskDark || !mask.contents) {
        HTDockMaskRect=dock; HTDockMaskDark=dark;
        CGFloat scale=MAX(1,host.screen.scale ?: 2);
        CGSize size=dock.size;
        // A little more room now that 2pt proved safe in your video (clock stayed intact): 3pt
        // margin, slightly bigger radius, for a more visibly rounded look.
        CGFloat topGap=3, bottomGap=3, outerGap=3, innerGap=0;
        CGRect inner = onLeft
            ? CGRectMake(outerGap,topGap,size.width-outerGap-innerGap,size.height-topGap-bottomGap)
            : CGRectMake(innerGap,topGap,size.width-outerGap-innerGap,size.height-topGap-bottomGap);
        CGFloat radius=MIN(12,MIN(inner.size.width,inner.size.height)/2);
        UIGraphicsBeginImageContextWithOptions(size,NO,scale);
        CGContextRef c=UIGraphicsGetCurrentContext();
        if (wallImage && CGImageGetWidth(wallImage)>0 && host.bounds.size.width>0) {
            CGFloat imgScale=(CGFloat)CGImageGetWidth(wallImage)/host.bounds.size.width;
            CGRect cropPx=CGRectMake(dock.origin.x*imgScale,dock.origin.y*imgScale,
                                      dock.size.width*imgScale,dock.size.height*imgScale);
            CGImageRef crop=CGImageCreateWithImageInRect(wallImage,cropPx);
            if (crop) {
                UIImage *cropImg=[UIImage imageWithCGImage:crop scale:scale orientation:UIImageOrientationUp];
                [cropImg drawInRect:CGRectMake(0,0,size.width,size.height)];
                CGImageRelease(crop);
            }
        } else {
            UIColor *cornerColor = dark ? [UIColor colorWithRed:0.024 green:0.039 blue:0.125 alpha:1]
                                         : [UIColor colorWithRed:0.918 green:0.941 blue:1.0 alpha:1];
            [cornerColor setFill];
            UIRectFill(CGRectMake(0,0,size.width,size.height));
        }
        CGContextSetBlendMode(c,kCGBlendModeClear);
        UIBezierPath *innerPath=[UIBezierPath bezierPathWithRoundedRect:inner cornerRadius:radius];
        [innerPath fill];
        // Tint wash: instead of leaving the inner hole fully transparent (showing the real dock's
        // own plain mauve chrome untouched), lay a light wallpaper-colored film over it too, at low
        // alpha so the real icons and clock underneath stay fully legible -- a cheap approximation
        // of "the dock tinted/blurred like the Home wallpaper", since the real dock content is
        // rendered by a separate process and its own base color isn't something this tweak can set
        // directly (only paint additively on top of).
        if (wallImage) {
            CGContextSetBlendMode(c,kCGBlendModeNormal);
            CGContextSaveGState(c);
            [innerPath addClip];
            CGFloat imgScale2=(CGFloat)CGImageGetWidth(wallImage)/host.bounds.size.width;
            CGRect cropPx2=CGRectMake(dock.origin.x*imgScale2,dock.origin.y*imgScale2,
                                       dock.size.width*imgScale2,dock.size.height*imgScale2);
            CGImageRef crop2=CGImageCreateWithImageInRect(wallImage,cropPx2);
            if (crop2) {
                UIImage *tintImg=[UIImage imageWithCGImage:crop2 scale:scale orientation:UIImageOrientationUp];
                [tintImg drawInRect:CGRectMake(0,0,size.width,size.height) blendMode:kCGBlendModeNormal alpha:0.42];
                CGImageRelease(crop2);
            }
            CGContextRestoreGState(c);
        }
        UIImage *image=UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        mask.contentsScale=scale;
        mask.contents=(__bridge id)image.CGImage;
        HTLog([NSString stringWithFormat:@"DOCKMASK frame=%@ inner=%@ radius=%.0f onLeft=%d dark=%d patchedFromWallpaper=%d created=%d",
            NSStringFromCGRect(dock),NSStringFromCGRect(inner),radius,onLeft,dark,wallImage!=NULL,created]);
    }
    [CATransaction commit];
}



static void HTLayoutBatteryLayer(void) {
    UIWindow *source=HTSource;
    UIView *home=HTHome;
    UIWindowScene *scene=source.windowScene;
    if (!scene) return;
    HTUpdateWindowWallpaper();
    HTLogHomeTreeOnce(source);
    HTLogDockTreeOnce(scene);
    CGRect dock; BOOL onLeft=YES;
    if (!HTDockRect(source,home,&dock,&onLeft)) {
        static BOOL reported=NO;
        if (!reported && source && home) { reported=YES; HTLog([NSString stringWithFormat:@"WAIT inset bounds=%@ home=%@",NSStringFromCGRect(source.bounds),NSStringFromCGRect([home convertRect:home.bounds toView:source])]); }
        HTBatteryLayer.hidden=YES;
        return;
    }
    UIWindow *host=HTDockWindow(scene);
    CALayer *parent=(host ?: source).layer;
    if (host) {
        NSInteger paintStyle=source.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight ? 1 : 2;
        HTUpdateDockRoundedMask(host,dock,onLeft,paintStyle==2);
    }
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
    // Fixed constant, not derived from siblings -- deriving it from "every sibling" caused a runaway
    // feedback loop with the dock mask (each one kept re-measuring the other and climbing forever,
    // visible as the zPosition endlessly increasing in the log).
    CGFloat wantZ=1000000;
    BOOL isLast=parent.sublayers.lastObject==HTBatteryLayer;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if (!isLast) { [HTBatteryLayer removeFromSuperlayer]; [parent addSublayer:HTBatteryLayer]; changed=YES; }
    if (HTBatteryLayer.zPosition!=wantZ) { HTBatteryLayer.zPosition=wantZ; changed=YES; }
    HTBatteryLayer.frame=battery;
    HTBatteryLayer.hidden=!HTSceneVisible(scene);
    [CATransaction commit];
    HTUpdateBattery();
    if (created || changed) {
        HTLog([NSString stringWithFormat:@"DOCK LAYER host=%@ battery=%@ dock=%@ left=%d active=%ld hidden=%d z=%.0f contents=%d hitTestOff=%d",
            host ? NSStringFromClass(host.class) : @"source(fallback)",NSStringFromCGRect(battery),NSStringFromCGRect(dock),onLeft,(long)scene.activationState,HTBatteryLayer.hidden,
            HTBatteryLayer.zPosition,HTBatteryLayer.contents!=nil,
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
static char HTHomeWallKey;
#pragma mark - Second wallpaper layer, welded directly onto the real stock background
// HOMETREE consistently shows one giveaway layer per Home page: a leaf (no sublayers), opaque,
// sized to Home's own full bounds (381.67x240) while its sibling "page" layers are all 16pt
// shorter. That's almost certainly the real stock wallpaper. An earlier attempt (0.7.6/0.7.7) hid
// and replaced it directly and was abandoned as a failure -- but that conclusion was confounded by
// the SAME "window-level insertion doesn't render on this unit" bug that also broke the wallpaper
// entirely at the time. Now that content genuinely inside Home (HTAttachHomeWallpaper) is proven to
// render, this is worth retrying: a second, independent wallpaper welded directly in the real
// layer's place, as a backstop under the regular subview one for whatever brief moment (matching
// the reported 3-way color flash during app open/close) the system's transition machinery might
// bypass or precede the subview-based one.
static NSMapTable<CALayer*,CALayer*> *HTWeldedPairs; // real original -> our replacement, both weak

static void HTWeldPageBackgrounds(CALayer *layer, CGSize targetSize, NSUInteger depth) {
    if (!HTWeldedPairs) HTWeldedPairs=[NSMapTable weakToWeakObjectsMapTable];
    // Re-assert every pass: if the system ever un-hides its own layer again, notice and re-hide it
    // instead of silently losing to it (the exact failure mode a one-time hide had before).
    for (CALayer *original in [HTWeldedPairs keyEnumerator]) {
        if (!original.hidden) original.hidden=YES;
        CALayer *replacement=[HTWeldedPairs objectForKey:original];
        if (replacement && !CGRectEqualToRect(replacement.frame,original.frame)) replacement.frame=original.frame;
    }
    if (depth==0 || !layer) return;
    for (CALayer *sub in [layer.sublayers copy]) {
        if (sub.sublayers.count==0 && sub.opaque && ![HTWeldedPairs objectForKey:sub]
            && fabs(sub.bounds.size.width-targetSize.width)<1.5 && fabs(sub.bounds.size.height-targetSize.height)<1.5
            && ![NSStringFromClass(sub.class) hasPrefix:@"HomeTA"]) {
            NSInteger style=HTSource.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight ? 1 : 2;
            HTWallpaper *painter=[HTWallpaper new];
            painter.htStyle=style;
            painter.bounds=(CGRect){CGPointZero,targetSize};
            CGFloat scale=MAX(1,HTSource.screen.scale ?: 2);
            UIGraphicsBeginImageContextWithOptions(targetSize,YES,scale);
            [painter drawRect:painter.bounds];
            UIImage *img=UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            CALayer *replacement=[CALayer layer];
            replacement.name=@"HomeTA.WeldedWallpaper";
            replacement.frame=sub.frame;
            replacement.contentsGravity=kCAGravityResize;
            replacement.contentsScale=scale;
            replacement.contents=(__bridge id)img.CGImage;
            replacement.actions=@{@"contents":NSNull.null,@"position":NSNull.null,@"bounds":NSNull.null,@"hidden":NSNull.null};
            HTNoHit(replacement);
            [CATransaction begin]; [CATransaction setDisableActions:YES];
            sub.hidden=YES;
            NSUInteger idx=[layer.sublayers indexOfObject:sub];
            [layer insertSublayer:replacement atIndex:(unsigned)idx];
            [CATransaction commit];
            [HTWeldedPairs setObject:replacement forKey:sub];
            HTLog([NSString stringWithFormat:@"WELD replaced class=%@ frame=%@",NSStringFromClass(sub.class),NSStringFromCGRect(sub.frame)]);
        }
        HTWeldPageBackgrounds(sub,targetSize,depth-1);
    }
}

static void HTAttachHomeWallpaper(UIView *home) {
    if (!home) return;
    HTWallpaper *wall=objc_getAssociatedObject(home,&HTHomeWallKey);
    BOOL created=NO;
    if (!wall) {
        wall=[[HTWallpaper alloc] initWithFrame:home.bounds];
        wall.userInteractionEnabled=NO;
        wall.opaque=YES;
        wall.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        wall.contentMode=UIViewContentModeRedraw;
        objc_setAssociatedObject(home,&HTHomeWallKey,wall,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        created=YES;
    }
    if (wall.superview!=home || home.subviews.firstObject!=wall) {
        [wall removeFromSuperview];
        [home insertSubview:wall atIndex:0];
    }
    if (!CGRectEqualToRect(wall.frame,home.bounds)) wall.frame=home.bounds;
    NSInteger style=home.window.traitCollection.userInterfaceStyle==UIUserInterfaceStyleLight ? 1 : 2;
    if (wall.htStyle!=style) { wall.htStyle=style; [wall setNeedsDisplay]; }
    if (created) HTLog([NSString stringWithFormat:@"HOMEWALL view attached home=%p bounds=%@",(void*)home,NSStringFromCGRect(home.bounds)]);
    HTWeldPageBackgrounds(home.layer,home.bounds.size,8);
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
    static BOOL attachLogged=NO;
    if (!attachLogged) { attachLogged=YES; HTLog([NSString stringWithFormat:@"HOME attached frame=%@ chain=%@",NSStringFromCGRect(home.bounds),HTChain(home)]); }
    HTAttachHomeWallpaper(home);
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

%hook SBIconImageView
- (void)layoutSubviews {
    %orig;
    HTApplyGlass(self);
    HTAttachHome(self);
}
%end

%hook DBAnimationView
// Attach the wallpaper the instant this view itself appears/lays out, without waiting for a child
// icon to also independently trigger layout -- narrows the gap where a freshly (re)created Home
// page briefly has no wallpaper yet, which is the most likely cause of old wallpaper flashing at
// the corners during the app open/close animation.
- (void)layoutSubviews {
    %orig;
    UIView *self_=(UIView *)self;
    if (self_.bounds.size.width>=self_.window.bounds.size.width*0.5) HTAttachHomeWallpaper(self_);
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
                HTReleaseBatteryLayer(); HTSource=nil; HTHome=nil; HTProbed=nil;
            }
        }]];
        HTLog(@"LOADED iOS27-style Home + borderless battery; layers hit-test off; no overlay window; no timer");
        %init;
    }
}
