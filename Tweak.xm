#import "LGGlass.h"

%hook AWENormalModeTabBar

- (void)layoutSubviews {
    %orig;
    [LGGlass syncTabBar:(UIView *)self];
}

- (void)didMoveToWindow {
    %orig;
    [LGGlass installToggleGestureOnTabBar:(UIView *)self];
    [LGGlass syncTabBar:(UIView *)self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    (void)previousTraitCollection;
    [LGGlass refreshTabBar:(UIView *)self];
}

%end
