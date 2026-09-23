// HomeTA 0.3.1 Safe Test — one verified native hook only.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface SBIconImageView : UIImageView @end

static BOOL HTDidLogStyle=NO;

static void HTLog(NSString *message) {
    NSString *path=@"/var/mobile/HomeTA.log";
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA 0.3.1] %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (__unused NSException *exception) {}
    @finally { [handle closeFile]; }
}

static void HTStyleIconImage(SBIconImageView *image) {
    image.layer.borderWidth=1.5;
    image.layer.borderColor=[UIColor colorWithRed:0.08 green:0.84 blue:1.0 alpha:0.92].CGColor;
    if (@available(iOS 13.0,*)) image.layer.cornerCurve=kCACornerCurveContinuous;
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

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.CarPlayApp"]) return;
        HTLog(@"LOADED safe-test hook=SBIconImageView");
        %init;
    }
}
