// HomeTA 0.2.0 — event-driven native CarPlay Home restyling.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static const void *HTPendingKey=&HTPendingKey;
static const void *HTStyledKey=&HTStyledKey;
static const void *HTGridKey=&HTGridKey;
static const void *HTCellKey=&HTCellKey;
static const void *HTDockKey=&HTDockKey;
static NSString *HTLastSignature;

static UIColor *HTGlass(CGFloat alpha) { return [UIColor colorWithRed:0.025 green:0.050 blue:0.090 alpha:alpha]; }
static UIColor *HTAccent(void) { return [UIColor colorWithRed:0.10 green:0.84 blue:1.0 alpha:1.0]; }
static void HTLog(NSString *format, ...) {
    va_list args; va_start(args,format);
    NSString *message=[[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    NSString *path=@"/var/mobile/HomeTA.log";
    NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attributes fileSize]>512*1024) {
        [NSFileManager.defaultManager removeItemAtPath:[path stringByAppendingString:@".1"] error:nil];
        [NSFileManager.defaultManager moveItemAtPath:path toPath:[path stringByAppendingString:@".1"] error:nil];
    }
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA 0.2.0] %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (__unused NSException *exception) {}
    @finally { [handle closeFile]; }
}
static BOOL HTDashboardWindow(UIWindow *window) {
    if (!window || !window.windowScene) return NO;
    NSString *identifier=window.windowScene.session.persistentIdentifier ?: @"";
    return [identifier containsString:@"DBDashboard"] || [identifier containsString:@"CarPlay"];
}
static BOOL HTVisible(UIView *view) {
    return view && view.window && !view.hidden && view.alpha>0.02 && view.bounds.size.width>2 && view.bounds.size.height>2;
}
static void HTCollect(UIView *root, NSMutableArray<UIView *> *views, NSInteger depth, NSInteger *budget) {
    if (!root || depth>18 || (*budget)--<=0) return;
    [views addObject:root];
    for (UIView *child in root.subviews) HTCollect(child,views,depth+1,budget);
}
static NSInteger HTDescendantCount(UIView *root, Class wanted, NSInteger budget) {
    if (!root || budget<=0) return 0;
    NSInteger count=[root isKindOfClass:wanted] ? 1 : 0;
    for (UIView *child in root.subviews) {
        if (--budget<=0) break;
        count+=HTDescendantCount(child,wanted,budget);
    }
    return count;
}
static void HTStyleGlass(UIView *view, CGFloat radius, CGFloat alpha, UIColor *border) {
    view.backgroundColor=HTGlass(alpha);
    view.layer.cornerRadius=radius;
    if (@available(iOS 13.0,*)) view.layer.cornerCurve=kCACornerCurveContinuous;
    view.layer.borderWidth=0.8;
    view.layer.borderColor=(border ?: [UIColor colorWithWhite:1 alpha:0.20]).CGColor;
}
static void HTStyleContents(UIView *container) {
    NSInteger budget=220;
    NSMutableArray<UIView *> *views=[NSMutableArray new];
    HTCollect(container,views,0,&budget);
    for (UIView *view in views) {
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label=(UILabel *)view;
            label.textColor=UIColor.whiteColor;
            if (label.font.pointSize>=10) label.font=[UIFont systemFontOfSize:label.font.pointSize weight:UIFontWeightSemibold];
            label.backgroundColor=[UIColor colorWithWhite:0 alpha:0.38];
            label.layer.cornerRadius=7; label.clipsToBounds=YES;
        } else if ([view isKindOfClass:UIImageView.class]) {
            UIImageView *image=(UIImageView *)view;
            CGFloat edge=MIN(image.bounds.size.width,image.bounds.size.height);
            if (!image.image || edge<26) continue;
            image.layer.cornerRadius=MIN(18,edge*0.22);
            if (@available(iOS 13.0,*)) image.layer.cornerCurve=kCACornerCurveContinuous;
            image.layer.borderWidth=0.65;
            image.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.30].CGColor;
            image.clipsToBounds=YES;
        }
    }
}
static BOOL HTIsIconCandidate(UIView *view, UIWindow *window) {
    if (!HTVisible(view) || view==window || [view isKindOfClass:UIImageView.class] || [view isKindOfClass:UILabel.class] || [view isKindOfClass:UICollectionView.class]) return NO;
    CGRect frame=[view convertRect:view.bounds toView:window];
    CGFloat sw=window.bounds.size.width, sh=window.bounds.size.height;
    if (frame.size.width<48 || frame.size.height<48 || frame.size.width>sw*0.34 || frame.size.height>sh*0.48) return NO;
    NSInteger images=HTDescendantCount(view,UIImageView.class,100);
    NSInteger labels=HTDescendantCount(view,UILabel.class,100);
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    BOOL named=[name containsString:@"icon"] || [name containsString:@"cell"] || [name containsString:@"application"] || [name containsString:@"button"];
    BOOL interactive=[view isKindOfClass:UIControl.class] || view.gestureRecognizers.count>0 || view.isAccessibilityElement;
    return images>=1 && labels>=1 && (named || interactive);
}
static void HTStyleIcon(UIView *view) {
    if (objc_getAssociatedObject(view,HTStyledKey)) return;
    objc_setAssociatedObject(view,HTStyledKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view,HTCellKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    HTStyleGlass(view,22,0.30,[UIColor colorWithWhite:1 alpha:0.17]);
    HTStyleContents(view);
}
static void HTStyleGrid(UICollectionView *grid) {
    if (!grid) return;
    objc_setAssociatedObject(grid,HTGridKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    HTStyleGlass(grid,30,0.20,[UIColor colorWithWhite:1 alpha:0.18]);
    grid.clipsToBounds=YES;
    for (UICollectionViewCell *cell in grid.visibleCells) {
        objc_setAssociatedObject(cell,HTCellKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        HTStyleGlass(cell.contentView,22,0.30,[UIColor colorWithWhite:1 alpha:0.17]);
        HTStyleContents(cell.contentView);
    }
}
static void HTStyleDock(UIView *dock) {
    if (!dock || objc_getAssociatedObject(dock,HTDockKey)) return;
    objc_setAssociatedObject(dock,HTDockKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIVisualEffectView *material=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    material.frame=dock.bounds;
    material.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    material.userInteractionEnabled=NO;
    material.layer.cornerRadius=24;
    if (@available(iOS 13.0,*)) material.layer.cornerCurve=kCACornerCurveContinuous;
    material.layer.borderWidth=0.8;
    material.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.23].CGColor;
    material.clipsToBounds=YES;
    [dock insertSubview:material atIndex:0];
    dock.backgroundColor=UIColor.clearColor;
}
static void HTScanWindow(UIWindow *window) {
    if (!HTDashboardWindow(window) || !window.rootViewController.view) return;
    NSInteger budget=1600;
    NSMutableArray<UIView *> *views=[NSMutableArray new];
    HTCollect(window.rootViewController.view,views,0,&budget);
    NSMutableArray<UIView *> *icons=[NSMutableArray new];
    UIView *dock=nil; CGFloat dockScore=0;
    NSInteger grids=0, pages=0;
    CGFloat sw=window.bounds.size.width, sh=window.bounds.size.height;
    for (UIView *view in views) {
        if (!HTVisible(view)) continue;
        if ([view isKindOfClass:UIPageControl.class]) {
            UIPageControl *page=(UIPageControl *)view;
            page.pageIndicatorTintColor=[UIColor colorWithWhite:1 alpha:0.25];
            page.currentPageIndicatorTintColor=HTAccent(); pages++;
        }
        if ([view isKindOfClass:UICollectionView.class]) {
            UICollectionView *collection=(UICollectionView *)view;
            CGRect frame=[collection convertRect:collection.bounds toView:window];
            if (frame.size.width*frame.size.height>sw*sh*0.18 && HTDescendantCount(collection,UIImageView.class,500)>=3) { HTStyleGrid(collection); grids++; }
        }
        if (HTIsIconCandidate(view,window)) [icons addObject:view];
        NSString *name=NSStringFromClass(view.class).lowercaseString;
        CGRect frame=[view convertRect:view.bounds toView:window];
        BOOL named=[name containsString:@"dock"];
        BOOL shaped=frame.size.width>38 && frame.size.width<sw*0.28 && frame.size.height>sh*0.45;
        if (named || shaped) {
            NSInteger images=HTDescendantCount(view,UIImageView.class,350);
            CGFloat score=(named ? 1000 : 0)+images*100+frame.size.height-frame.size.width;
            if (images>=2 && score>dockScore) { dock=view; dockScore=score; }
        }
    }
    for (UIView *icon in icons) HTStyleIcon(icon);
    HTStyleDock(dock);
    NSString *signature=[NSString stringWithFormat:@"%@/%lu/%lu/%ld/%ld/%@",NSStringFromCGSize(window.bounds.size),(unsigned long)views.count,(unsigned long)icons.count,(long)grids,(long)pages,dock ? NSStringFromClass(dock.class) : @"none"];
    if (![signature isEqual:HTLastSignature]) {
        HTLastSignature=signature;
        NSMutableOrderedSet<NSString *> *classes=[NSMutableOrderedSet new];
        for (UIView *icon in icons) if (classes.count<16) [classes addObject:NSStringFromClass(icon.class)];
        HTLog(@"SCAN signature=%@ iconClasses=%@",signature,classes.array);
    }
}
static void HTScheduleScan(UIWindow *window) {
    if (!HTDashboardWindow(window) || objc_getAssociatedObject(window,HTPendingKey)) return;
    objc_setAssociatedObject(window,HTPendingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIWindow *weakWindow=window;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,120*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        UIWindow *strongWindow=weakWindow;
        if (!strongWindow) return;
        objc_setAssociatedObject(strongWindow,HTPendingKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        HTScanWindow(strongWindow);
    });
}

%hook UIView
- (void)didMoveToWindow { %orig; if (self.window) HTScheduleScan(self.window); }
- (void)didAddSubview:(UIView *)subview { %orig; if (self.window) HTScheduleScan(self.window); }
%end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated { %orig; HTScheduleScan(self.view.window); }
%end

%hook UICollectionView
- (void)layoutSubviews { %orig; if (objc_getAssociatedObject(self,HTGridKey)) HTStyleGrid(self); }
%end

%hook UICollectionViewCell
- (void)setHighlighted:(BOOL)highlighted {
    %orig;
    if (!objc_getAssociatedObject(self,HTCellKey)) return;
    [UIView animateWithDuration:highlighted ? 0.08 : 0.20 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{ self.transform=highlighted ? CGAffineTransformMakeScale(0.92,0.92) : CGAffineTransformIdentity; } completion:nil];
}
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.CarPlayApp"]) return;
        HTLog(@"LOADED process=%@",NSBundle.mainBundle.bundleIdentifier);
        %init;
    }
}
