#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGGlass : NSObject

+ (BOOL)isEnabled;
+ (void)setEnabled:(BOOL)enabled;
+ (BOOL)hasRealGlass;
+ (void)syncTabBar:(UIView *)tabBar;
+ (void)refreshTabBar:(UIView *)tabBar;
+ (void)installToggleGestureOnTabBar:(UIView *)tabBar;

@end

NS_ASSUME_NONNULL_END
