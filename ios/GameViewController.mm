#import "GameViewController.h"
#import "GameView.h"

@implementation GameViewController

- (void)loadView {
    self.view = [[GameView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate { return YES; }

@end
