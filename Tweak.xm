#import "LGGlass.h"

%hook AWENormalModeTabBar

- (void)layoutSubviews {
    %orig;
    [LGGlass syncTabBar:self];
}

- (void)didMoveToWindow {
    %orig;
    [LGGlass installToggleGestureOnTabBar:self];
    [LGGlass syncTabBar:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    (void)previousTraitCollection;
    [LGGlass refreshTabBar:self];
}

%end
