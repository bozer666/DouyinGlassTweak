#import "LGGlass.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static char kLGGlassViewKey;
static char kLGSavedStateKey;
static char kLGToggleGestureKey;
static NSString * const kLGEnabledKey = @"lg_enabled";
static __weak UIView *gTabBar;

static id LGValue(id object, NSString *key) {
    if (![object respondsToSelector:NSSelectorFromString(key)]) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static UIViewController *LGTopViewController(void) {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    if (!keyWindow) {
        keyWindow = UIApplication.sharedApplication.windows.firstObject;
    }
    UIViewController *controller = keyWindow.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

static UIColor *LGDynamicTint(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.0 alpha:0.18];
        }
        return [UIColor colorWithWhite:1.0 alpha:0.10];
    }];
}

static UIVisualEffect *LGMakeEffect(void) {
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    }
    if (@available(iOS 26.0, *)) {
        Class glassClass = NSClassFromString(@"UIGlassEffect");
        SEL factory = NSSelectorFromString(@"effectWithStyle:");
        if (glassClass && [glassClass respondsToSelector:factory]) {
            id effect = ((id (*)(id, SEL, NSInteger))objc_msgSend)(glassClass, factory, 0);
            if (effect) {
                SEL setTint = NSSelectorFromString(@"setTintColor:");
                if ([effect respondsToSelector:setTint]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(effect, setTint, LGDynamicTint());
                }
                SEL setInteractive = NSSelectorFromString(@"setInteractive:");
                if ([effect respondsToSelector:setInteractive]) {
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(effect, setInteractive, NO);
                }
                return (UIVisualEffect *)effect;
            }
        }
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
}

static NSDictionary *LGStateForView(UIView *view) {
    UIColor *backgroundColor = view.backgroundColor;
    return @{
        @"view": view,
        @"hidden": @(view.hidden),
        @"alpha": @(view.alpha),
        @"backgroundColor": backgroundColor ?: (id)[NSNull null],
    };
}

static void LGRestoreState(NSDictionary *state) {
    UIView *view = state[@"view"];
    if (![view isKindOfClass:[UIView class]]) return;
    view.hidden = [state[@"hidden"] boolValue];
    view.alpha = [state[@"alpha"] doubleValue];
    id backgroundColor = state[@"backgroundColor"];
    view.backgroundColor = (backgroundColor == [NSNull null]) ? nil : backgroundColor;
}

static void LGInstall(UIView *host) {
    if (objc_getAssociatedObject(host, &kLGGlassViewKey)) return;

    NSMutableArray<NSDictionary *> *states = [NSMutableArray array];
    NSArray<NSString *> *keys = @[
        @"backgroundView",
        @"awe_blurView",
        @"darkBackgroundImageView",
        @"lightBackgroundImageView",
        @"compactModeBackgroundView",
        @"separatorLine"
    ];
    for (NSString *key in keys) {
        id value = LGValue(host, key);
        if (![value isKindOfClass:[UIView class]]) continue;
        UIView *view = (UIView *)value;
        if (view == host) continue;
        [states addObject:LGStateForView(view)];
        view.hidden = YES;
        view.alpha = 0.0;
    }
    [states addObject:LGStateForView(host)];
    host.backgroundColor = [UIColor clearColor];
    objc_setAssociatedObject(host, &kLGSavedStateKey, states, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:LGMakeEffect()];
    glass.userInteractionEnabled = NO;
    glass.frame = host.bounds;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    glass.clipsToBounds = YES;
    glass.layer.cornerRadius = host.layer.cornerRadius;
    glass.layer.cornerCurve = host.layer.cornerCurve;
    glass.layer.maskedCorners = host.layer.maskedCorners;
    if (![LGGlass hasRealGlass]) {
        glass.contentView.backgroundColor = LGDynamicTint();
    }
    [host insertSubview:glass atIndex:0];
    objc_setAssociatedObject(host, &kLGGlassViewKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void LGUninstall(UIView *host) {
    UIVisualEffectView *glass = objc_getAssociatedObject(host, &kLGGlassViewKey);
    if (glass) {
        [glass removeFromSuperview];
        objc_setAssociatedObject(host, &kLGGlassViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray<NSDictionary *> *states = objc_getAssociatedObject(host, &kLGSavedStateKey);
    for (NSDictionary *state in states) {
        LGRestoreState(state);
    }
    objc_setAssociatedObject(host, &kLGSavedStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void LGUpdateGeometry(UIView *host) {
    UIVisualEffectView *glass = objc_getAssociatedObject(host, &kLGGlassViewKey);
    if (!glass) return;
    glass.frame = host.bounds;
    glass.layer.cornerRadius = host.layer.cornerRadius;
    glass.layer.cornerCurve = host.layer.cornerCurve;
    glass.layer.maskedCorners = host.layer.maskedCorners;
    host.backgroundColor = [UIColor clearColor];
    NSArray<NSDictionary *> *states = objc_getAssociatedObject(host, &kLGSavedStateKey);
    for (NSDictionary *state in states) {
        UIView *view = state[@"view"];
        if (![view isKindOfClass:[UIView class]] || view == host) continue;
        view.hidden = YES;
        view.alpha = 0.0;
    }
}

static void LGRefresh(UIView *host) {
    UIVisualEffectView *glass = objc_getAssociatedObject(host, &kLGGlassViewKey);
    if (!glass) return;
    LGUpdateGeometry(host);
    glass.effect = LGMakeEffect();
    if (![LGGlass hasRealGlass]) {
        glass.contentView.backgroundColor = LGDynamicTint();
    }
}

@interface LGGlass ()
+ (void)handleToggle:(UITapGestureRecognizer *)gesture;
@end

@implementation LGGlass

+ (BOOL)isEnabled {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kLGEnabledKey];
    return value ? [value boolValue] : YES;
}

+ (void)setEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kLGEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    UIView *tabBar = gTabBar;
    if (tabBar) [self syncTabBar:tabBar];
}

+ (BOOL)hasRealGlass {
    if (@available(iOS 26.0, *)) {
        Class glassClass = NSClassFromString(@"UIGlassEffect");
        if (!glassClass) return NO;
        return [glassClass respondsToSelector:NSSelectorFromString(@"effectWithStyle:")];
    }
    return NO;
}

+ (void)syncTabBar:(UIView *)tabBar {
    if (!tabBar) return;
    gTabBar = tabBar;
    if ([self isEnabled]) {
        LGInstall(tabBar);
        LGUpdateGeometry(tabBar);
    } else {
        LGUninstall(tabBar);
    }
}

+ (void)refreshTabBar:(UIView *)tabBar {
    if (!tabBar) return;
    if ([self isEnabled]) LGRefresh(tabBar);
}

+ (void)installToggleGestureOnTabBar:(UIView *)tabBar {
    if (!tabBar) return;
    if (objc_getAssociatedObject(tabBar, &kLGToggleGestureKey)) return;
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleToggle:)];
    gesture.numberOfTapsRequired = 2;
    gesture.numberOfTouchesRequired = 3;
    gesture.cancelsTouchesInView = NO;
    [tabBar addGestureRecognizer:gesture];
    objc_setAssociatedObject(tabBar, &kLGToggleGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)handleToggle:(UITapGestureRecognizer *)gesture {
    (void)gesture;
    BOOL enabled = ![self isEnabled];
    [self setEnabled:enabled];
    UIViewController *controller = LGTopViewController();
    if (!controller) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"液态玻璃"
                                                                   message:enabled ? @"已开启" : @"已关闭"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

@end
