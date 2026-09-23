// HomeTA 0.3.0 — native CarPlay Home restyling using verified Dashboard classes.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface DBFolderView : UIView @end
@interface DBIconView : UIView @end
@interface DBIconLabelBackdropView : UIView @end
@interface SBIconImageView : UIImageView @end
@interface SBIconSimpleLabelView : UIImageView @end
@interface DBIconListPageControl : UIPageControl @end
@interface DBWidgetView : UIView @end

static const void *HTRootPanelKey=&HTRootPanelKey;
static const void *HTRootGradientKey=&HTRootGradientKey;
static const void *HTIconHaloKey=&HTIconHaloKey;
static const void *HTIconGradientKey=&HTIconGradientKey;
static BOOL HTLoggedFolder=NO;
static BOOL HTLoggedIcon=NO;
static BOOL HTLoggedPage=NO;

static UIColor *HTNavy(CGFloat alpha) {
    return [UIColor colorWithRed:0.015 green:0.040 blue:0.085 alpha:alpha];
}
static UIColor *HTCyan(CGFloat alpha) {
    return [UIColor colorWithRed:0.08 green:0.84 blue:1.0 alpha:alpha];
}
static UIColor *HTOrange(CGFloat alpha) {
    return [UIColor colorWithRed:1.0 green:0.52 blue:0.08 alpha:alpha];
}
static void HTContinuousCorners(CALayer *layer, CGFloat radius) {
    layer.cornerRadius=radius;
    if (@available(iOS 13.0,*)) layer.cornerCurve=kCACornerCurveContinuous;
}
static void HTLog(NSString *format, ...) {
    va_list args; va_start(args,format);
    NSString *message=[[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    NSString *path=@"/var/mobile/HomeTA.log";
    NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attributes fileSize]>128*1024) {
        [NSFileManager.defaultManager removeItemAtPath:[path stringByAppendingString:@".1"] error:nil];
        [NSFileManager.defaultManager moveItemAtPath:path toPath:[path stringByAppendingString:@".1"] error:nil];
    }
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA 0.3.0] %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (__unused NSException *exception) {}
    @finally { [handle closeFile]; }
}
static CAGradientLayer *HTGradient(NSArray *colors, NSArray<NSNumber *> *locations) {
    CAGradientLayer *gradient=[CAGradientLayer layer];
    gradient.colors=colors;
    gradient.locations=locations;
    gradient.startPoint=CGPointMake(0.0,0.0);
    gradient.endPoint=CGPointMake(1.0,1.0);
    return gradient;
}
static void HTStyleFolder(DBFolderView *folder) {
    UIView *panel=objc_getAssociatedObject(folder,HTRootPanelKey);
    CAGradientLayer *gradient=objc_getAssociatedObject(folder,HTRootGradientKey);
    if (!panel) {
        panel=[UIView new];
        panel.userInteractionEnabled=NO;
        panel.backgroundColor=HTNavy(0.24);
        panel.layer.borderWidth=0.8;
        panel.layer.borderColor=[UIColor colorWithWhite:1.0 alpha:0.20].CGColor;
        HTContinuousCorners(panel.layer,27.0);
        panel.clipsToBounds=YES;
        gradient=HTGradient(@[(id)HTCyan(0.17).CGColor,(id)HTNavy(0.10).CGColor,(id)HTOrange(0.10).CGColor],@[@0.0,@0.55,@1.0]);
        [panel.layer insertSublayer:gradient atIndex:0];
        [folder insertSubview:panel atIndex:0];
        objc_setAssociatedObject(folder,HTRootPanelKey,panel,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(folder,HTRootGradientKey,gradient,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        [folder sendSubviewToBack:panel];
    }
    panel.frame=UIEdgeInsetsInsetRect(folder.bounds,UIEdgeInsetsMake(6,6,8,6));
    gradient.frame=panel.bounds;
    if (!HTLoggedFolder) { HTLoggedFolder=YES; HTLog(@"STYLED DBFolderView frame=%@",NSStringFromCGRect(folder.frame)); }
}
static SBIconImageView *HTIconImage(DBIconView *icon) {
    Class imageClass=objc_getClass("SBIconImageView");
    for (UIView *view in icon.subviews) if (imageClass && [view isKindOfClass:imageClass]) return (SBIconImageView *)view;
    return nil;
}
static void HTStyleIcon(DBIconView *icon) {
    SBIconImageView *image=HTIconImage(icon);
    if (!image) return;
    UIView *halo=objc_getAssociatedObject(icon,HTIconHaloKey);
    CAGradientLayer *gradient=objc_getAssociatedObject(icon,HTIconGradientKey);
    if (!halo) {
        halo=[UIView new];
        halo.userInteractionEnabled=NO;
        halo.backgroundColor=HTNavy(0.32);
        halo.layer.borderWidth=0.7;
        halo.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.28].CGColor;
        HTContinuousCorners(halo.layer,19.0);
        gradient=HTGradient(@[(id)HTCyan(0.24).CGColor,(id)[UIColor colorWithWhite:1 alpha:0.05].CGColor,(id)HTOrange(0.18).CGColor],@[@0.0,@0.55,@1.0]);
        [halo.layer insertSublayer:gradient atIndex:0];
        [icon insertSubview:halo atIndex:0];
        objc_setAssociatedObject(icon,HTIconHaloKey,halo,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(icon,HTIconGradientKey,gradient,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        [icon sendSubviewToBack:halo];
    }
    halo.frame=CGRectInset(image.frame,-4.0,-4.0);
    gradient.frame=halo.bounds;
    image.layer.borderWidth=0.65;
    image.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.32].CGColor;
    HTContinuousCorners(image.layer,15.5);
    image.layer.masksToBounds=YES;
    if (!HTLoggedIcon) { HTLoggedIcon=YES; HTLog(@"STYLED DBIconView image=%@",NSStringFromCGRect(image.frame)); }
}
static void HTStyleLabelBackdrop(DBIconLabelBackdropView *view) {
    view.backgroundColor=HTNavy(0.62);
    view.layer.borderWidth=0.55;
    view.layer.borderColor=HTCyan(0.28).CGColor;
    HTContinuousCorners(view.layer,8.5);
    view.layer.masksToBounds=YES;
}
static void HTStyleLabelImage(SBIconSimpleLabelView *view) {
    view.layer.shadowColor=UIColor.blackColor.CGColor;
    view.layer.shadowOpacity=0.72;
    view.layer.shadowRadius=2.0;
    view.layer.shadowOffset=CGSizeMake(0,1);
}
static void HTStylePageControl(DBIconListPageControl *page) {
    page.pageIndicatorTintColor=[UIColor colorWithWhite:1 alpha:0.24];
    page.currentPageIndicatorTintColor=HTCyan(1.0);
    if (!HTLoggedPage) { HTLoggedPage=YES; HTLog(@"STYLED DBIconListPageControl pages=%ld",(long)page.numberOfPages); }
}
static void HTStyleWidget(DBWidgetView *widget) {
    widget.layer.borderWidth=0.75;
    widget.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.22].CGColor;
    HTContinuousCorners(widget.layer,22.0);
    widget.layer.masksToBounds=YES;
}

%hook DBFolderView
- (void)layoutSubviews {
    %orig;
    HTStyleFolder(self);
}
- (void)didMoveToWindow {
    %orig;
    if (self.window) HTStyleFolder(self);
}
%end

%hook DBIconView
- (void)layoutSubviews {
    %orig;
    HTStyleIcon(self);
}
- (void)didMoveToWindow {
    %orig;
    if (self.window) HTStyleIcon(self);
}
%end

%hook SBIconImageView
- (void)layoutSubviews {
    %orig;
    self.layer.borderWidth=0.65;
    self.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.32].CGColor;
    HTContinuousCorners(self.layer,15.5);
    self.layer.masksToBounds=YES;
}
%end

%hook DBIconLabelBackdropView
- (void)layoutSubviews {
    %orig;
    HTStyleLabelBackdrop(self);
}
- (void)didMoveToWindow {
    %orig;
    if (self.window) HTStyleLabelBackdrop(self);
}
%end

%hook SBIconSimpleLabelView
- (void)layoutSubviews {
    %orig;
    HTStyleLabelImage(self);
}
%end

%hook DBIconListPageControl
- (void)layoutSubviews {
    %orig;
    HTStylePageControl(self);
}
- (void)didMoveToWindow {
    %orig;
    if (self.window) HTStylePageControl(self);
}
%end

%hook DBWidgetView
- (void)layoutSubviews {
    %orig;
    HTStyleWidget(self);
}
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.CarPlayApp"]) return;
        HTLog(@"LOADED process=%@ directClasses=YES",NSBundle.mainBundle.bundleIdentifier);
        %init;
    }
}
