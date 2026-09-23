// HomeTA 0.1.0 — native CarPlay Home styling, no overlay window and no timer.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static const void *HTGridKey=&HTGridKey;
static const void *HTCellKey=&HTCellKey;
static const void *HTHomeKey=&HTHomeKey;
static const NSInteger HTDockTag=270120;
static NSMutableSet<NSString *> *HTLoggedControllers;

static UIColor *HTGlass(CGFloat alpha) {
    return [UIColor colorWithRed:0.035 green:0.055 blue:0.090 alpha:alpha];
}
static UIColor *HTAccent(void) {
    return [UIColor colorWithRed:0.16 green:0.84 blue:1.0 alpha:1.0];
}
static void HTLog(NSString *format, ...) {
    va_list args; va_start(args,format);
    NSString *message=[[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    NSString *path=@"/var/mobile/HomeTA.log";
    NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attributes fileSize]>512*1024) {
        [NSFileManager.defaultManager removeItemAtPath:[path stringByAppendingString:@".1"] error:nil];
        [NSFileManager.defaultManager moveItemAtPath:path toPath:[path stringByAppendingString:@".1"] error:nil];
    }
    NSData *data=[[NSString stringWithFormat:@"%@ [HomeTA 0.1.0] %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (__unused NSException *exception) {}
    @finally { [handle closeFile]; }
}
static BOOL HTVisible(UIView *view) {
    return view && !view.hidden && view.alpha>0.02 && view.window && view.bounds.size.width>1 && view.bounds.size.height>1;
}
static BOOL HTDashboardWindow(UIWindow *window) {
    if (!window.windowScene) return NO;
    NSString *identifier=window.windowScene.session.persistentIdentifier ?: @"";
    return [identifier containsString:@"DBDashboard-Car"];
}
static void HTCollectViews(UIView *root, Class wanted, NSMutableArray<UIView *> *result, NSInteger depth, NSInteger *budget) {
    if (!root || depth>16 || (*budget)--<=0) return;
    if ([root isKindOfClass:wanted]) [result addObject:root];
    for (UIView *child in root.subviews) HTCollectViews(child,wanted,result,depth+1,budget);
}
static NSInteger HTImageCount(UIView *root) {
    NSInteger budget=500;
    NSMutableArray *images=[NSMutableArray new];
    HTCollectViews(root,UIImageView.class,images,0,&budget);
    NSInteger count=0;
    for (UIImageView *image in images) if (HTVisible(image) && image.image) count++;
    return count;
}
static UICollectionView *HTFindGrid(UIView *root) {
    NSInteger budget=900;
    NSMutableArray<UIView *> *collections=[NSMutableArray new];
    HTCollectViews(root,UICollectionView.class,collections,0,&budget);
    UICollectionView *best=nil; CGFloat bestArea=0;
    for (UICollectionView *collection in collections) {
        if (!HTVisible(collection)) continue;
        CGFloat area=collection.bounds.size.width*collection.bounds.size.height;
        if (area>bestArea) { best=collection; bestArea=area; }
    }
    return best;
}
static BOOL HTNamedLikeHome(UIViewController *controller) {
    NSString *name=NSStringFromClass(controller.class).lowercaseString;
    if ([name containsString:@"map"] || [name containsString:@"nowplaying"] ||
        [name containsString:@"template"] || [name containsString:@"sceneview"]) return NO;
    return [name containsString:@"home"] || [name containsString:@"icon"] ||
           [name containsString:@"grid"] || [name containsString:@"dashboard"];
}
static void HTStyleGlassView(UIView *view, CGFloat radius, UIColor *border) {
    view.backgroundColor=HTGlass(0.34);
    view.layer.cornerRadius=radius;
    if (@available(iOS 13.0,*)) view.layer.cornerCurve=kCACornerCurveContinuous;
    view.layer.borderWidth=0.8;
    view.layer.borderColor=(border ?: [UIColor colorWithWhite:1 alpha:0.18]).CGColor;
}
static void HTStyleCell(UICollectionViewCell *cell) {
    if (!cell || objc_getAssociatedObject(cell,HTCellKey)) return;
    objc_setAssociatedObject(cell,HTCellKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    HTStyleGlassView(cell.contentView,22,[UIColor colorWithWhite:1 alpha:0.16]);
    NSInteger budget=160;
    NSMutableArray<UIView *> *labels=[NSMutableArray new];
    HTCollectViews(cell.contentView,UILabel.class,labels,0,&budget);
    for (UILabel *label in labels) {
        label.textColor=UIColor.whiteColor;
        label.font=[UIFont systemFontOfSize:label.font.pointSize weight:UIFontWeightSemibold];
        label.backgroundColor=[UIColor colorWithWhite:0 alpha:0.38];
        label.layer.cornerRadius=7;
        label.clipsToBounds=YES;
    }
    budget=160;
    NSMutableArray<UIView *> *images=[NSMutableArray new];
    HTCollectViews(cell.contentView,UIImageView.class,images,0,&budget);
    for (UIImageView *image in images) {
        CGFloat edge=MIN(image.bounds.size.width,image.bounds.size.height);
        if (!image.image || edge<28) continue;
        image.layer.cornerRadius=MIN(18,edge*0.22);
        if (@available(iOS 13.0,*)) image.layer.cornerCurve=kCACornerCurveContinuous;
        image.layer.borderWidth=0.65;
        image.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.28].CGColor;
        image.clipsToBounds=YES;
    }
}
static void HTStyleGrid(UICollectionView *grid) {
    if (!grid) return;
    objc_setAssociatedObject(grid,HTGridKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    HTStyleGlassView(grid,30,[UIColor colorWithWhite:1 alpha:0.20]);
    grid.clipsToBounds=YES;
    for (UICollectionViewCell *cell in grid.visibleCells) HTStyleCell(cell);
    NSInteger budget=500;
    NSMutableArray<UIView *> *pages=[NSMutableArray new];
    HTCollectViews(grid.superview ?: grid,UIPageControl.class,pages,0,&budget);
    for (UIPageControl *page in pages) {
        page.pageIndicatorTintColor=[UIColor colorWithWhite:1 alpha:0.28];
        page.currentPageIndicatorTintColor=HTAccent();
    }
}
static UIView *HTFindDock(UIView *root, UICollectionView *grid) {
    NSMutableArray<UIView *> *stack=[NSMutableArray arrayWithObject:root];
    CGRect screen=root.window.bounds;
    UIView *best=nil; CGFloat bestScore=0;
    while (stack.count) {
        UIView *view=stack.lastObject; [stack removeLastObject];
        for (UIView *child in view.subviews) [stack addObject:child];
        if (view==root || view==grid || [view isDescendantOfView:grid] || !HTVisible(view)) continue;
        NSString *name=NSStringFromClass(view.class).lowercaseString;
        CGRect frame=[view convertRect:view.bounds toView:root.window];
        BOOL named=[name containsString:@"dock"];
        BOOL shaped=frame.size.width>38 && frame.size.width<screen.size.width*0.28 &&
                    frame.size.height>screen.size.height*0.45;
        if (!named && !shaped) continue;
        NSInteger icons=HTImageCount(view);
        CGFloat score=(named ? 1000 : 0)+icons*100+frame.size.height-frame.size.width;
        if (icons>=2 && score>bestScore) { best=view; bestScore=score; }
    }
    return best;
}
static void HTStyleDock(UIView *dock) {
    if (!dock || [dock viewWithTag:HTDockTag]) return;
    UIVisualEffect *effect=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    UIVisualEffectView *glass=[[UIVisualEffectView alloc] initWithEffect:effect];
    glass.tag=HTDockTag; glass.frame=dock.bounds;
    glass.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    glass.userInteractionEnabled=NO;
    glass.layer.cornerRadius=24;
    if (@available(iOS 13.0,*)) glass.layer.cornerCurve=kCACornerCurveContinuous;
    glass.layer.borderWidth=0.8;
    glass.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.22].CGColor;
    glass.clipsToBounds=YES;
    [dock insertSubview:glass atIndex:0];
    dock.backgroundColor=UIColor.clearColor;
}
static void HTApplyToController(UIViewController *controller) {
    if (!controller.view.window || !HTDashboardWindow(controller.view.window)) return;
    UICollectionView *grid=HTFindGrid(controller.view);
    if (!grid) return;
    CGRect windowBounds=controller.view.window.bounds;
    CGFloat area=grid.bounds.size.width*grid.bounds.size.height;
    CGFloat screenArea=windowBounds.size.width*windowBounds.size.height;
    BOOL structural=screenArea>0 && area>screenArea*0.28 && HTImageCount(grid)>=4;
    if (!HTNamedLikeHome(controller) && !structural) return;
    objc_setAssociatedObject(controller,HTHomeKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    HTStyleGrid(grid);
    HTStyleDock(HTFindDock(controller.view,grid));
    NSString *name=NSStringFromClass(controller.class);
    if (![HTLoggedControllers containsObject:name]) {
        [HTLoggedControllers addObject:name];
        HTLog(@"HOME MATCH controller=%@ grid=%@ frame=%@ images=%ld",name,NSStringFromClass(grid.class),NSStringFromCGRect(grid.frame),(long)HTImageCount(grid));
    }
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_async(dispatch_get_main_queue(),^{ HTApplyToController(self); });
}
- (void)viewDidLayoutSubviews {
    %orig;
    if (objc_getAssociatedObject(self,HTHomeKey)) HTApplyToController(self);
}
%end

%hook UICollectionView
- (void)layoutSubviews {
    %orig;
    if (objc_getAssociatedObject(self,HTGridKey)) HTStyleGrid(self);
}
%end

%hook UICollectionViewCell
- (void)setHighlighted:(BOOL)highlighted {
    %orig;
    if (!objc_getAssociatedObject(self,HTCellKey)) return;
    [UIView animateWithDuration:highlighted ? 0.08 : 0.20 delay:0
        usingSpringWithDamping:0.78 initialSpringVelocity:0
        options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction
        animations:^{ self.transform=highlighted ? CGAffineTransformMakeScale(0.92,0.92) : CGAffineTransformIdentity; }
        completion:nil];
}
%end

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.CarPlayApp"]) return;
        HTLoggedControllers=[NSMutableSet new];
        HTLog(@"LOADED process=%@",NSBundle.mainBundle.bundleIdentifier);
        %init;
    }
}
