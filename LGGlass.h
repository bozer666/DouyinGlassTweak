#import <UIKit/UIKit.h>

@interface LGGlass : NSObject

+ (BOOL)isEnabled;
+ (void)setEnabled:(BOOL)enabled;
+ (BOOL)hasRealGlass;
+ (void)syncTabBar:(UIView *)tabBar;
+ (void)refreshTabBar:(UIView *)tabBar;
+ (void)installToggleGestureOnTabBar:(UIView *)tabBar;

@end
