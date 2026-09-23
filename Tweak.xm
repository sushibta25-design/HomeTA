// HomeTA 0.3.3 Safe Test — verified native Home view hooks only.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface SBIconImageView : UIImageView @end
@interface DBIconLabelBackdropView : UIView @end
@interface DBIconListPageControl : UIPageControl @end

static BOOL HTDidLogStyle=NO;
static BOOL HTDidLogLabel=NO;
static BOOL HTDidLogPage=NO;

static void HTLog(NSString *message) {
    NSString *path=@"/var/mobile/HomeTA.log";
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA 0.3.3] %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (__unused NSException *exception) {}
    @finally { [handle closeFile]; }
}

static void HTStyleLabelBackdrop(DBIconLabelBackdropView *label) {
    label.backgroundColor=[UIColor colorWithRed:0.015 green:0.040 blue:0.085 alpha:0.68];
    label.layer.borderWidth=0.5;
    label.layer.borderColor=[UIColor colorWithRed:0.08 green:0.84 blue:1.0 alpha:0.32].CGColor;
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
    image.layer.cornerRadius=15.5;
    if (@available(iOS 13.0,*)) image.layer.cornerCurve=kCACornerCurveContinuous;
    image.layer.masksToBounds=YES;
    if (!HTDidLogStyle) {
        HTDidLogStyle=YES;
        HTLog([NSString stringWithFormat:@"STYLED SBIconImageView frame=%@",NSStringFromCGRect(image.frame)]);
    }
}

static void HTStylePageControl(DBIconListPageControl *page) {
    page.pageIndicatorTintColor=[UIColor colorWithWhite:1.0 alpha:0.26];
    page.currentPageIndicatorTintColor=[UIColor colorWithRed:0.08 green:0.84 blue:1.0 alpha:1.0];
    if (!HTDidLogPage) {
        HTDidLogPage=YES;
        HTLog([NSString stringWithFormat:@"STYLED DBIconListPageControl frame=%@",NSStringFromCGRect(page.frame)]);
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

%hook DBIconListPageControl
- (void)layoutSubviews {
    %orig;
    HTStylePageControl(self);
}
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.CarPlayApp"]) return;
        HTLog(@"LOADED safe-test hooks=SBIconImageView,DBIconLabelBackdropView,DBIconListPageControl");
        %init;
    }
}
