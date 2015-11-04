//
//  FOVARViewController.m
//  FOVfinder
//
//  Created by Tim Gleue on 26.09.13.
//  Copyright (c) 2015 Tim Gleue ( http://gleue-interactive.com )
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "FOVARViewController.h"
#import "FOVSettingsViewController.h"

#import "UIDeviceHardware.h"
#import "FOVARPlaneShape.h"
#import "FOVARRectShape.h"
#import "FOVARView.h"

#import "UIDeviceHardware.h"

#define FOV_MIN 1.0
#define FOV_MAX 70.0

#define SHAPE_HEIGHT -30.0
#define SHAPE_DISTANCE 100.0

@interface FOVARViewController () {
    
    CGSize _currentSize;

    float _pinchFactor;

    float _targetFOVPortrait;
    float _targetFOVLandscape;
}

@property (weak, nonatomic) IBOutlet FOVARView *arView;
@property (weak, nonatomic) IBOutlet UILabel *fovLabel;

@property (strong, nonatomic) UILabel *infoLabel;

@property (strong, nonatomic) FOVARRectShape *verticalShape;
@property (strong, nonatomic) FOVARPlaneShape *horizontalShape;

@property (strong, readonly) NSDictionary *fieldOfView;

- (IBAction)handleTap:(id)sender;
- (IBAction)handlePan:(id)sender;
- (IBAction)handlePinch:(id)sender;

- (IBAction)closeInfo:(UIStoryboardSegue *)segue;
- (IBAction)closeSettings:(UIStoryboardSegue *)segue;

@end

@implementation FOVARViewController

@synthesize fieldOfView = _fieldOfView;

#pragma mark - View lifecycle

- (void)viewDidLoad {

	[super viewDidLoad];
    
    _pinchFactor = 1.0;
    _currentSize = CGSizeMake(21.0, 29.7);

    self.navigationItem.title = [UIDeviceHardware platformString];

    NSString *device = [UIDeviceHardware platform];    
    NSDictionary *dict = self.fieldOfView[device];
    
    self.arView.fieldOfViewPortrait = dict ? [dict[@"portrait"] floatValue] : 60.0;
    self.arView.fieldOfViewLandscape = dict ? [dict[@"landscape"] floatValue] : 40.0;
    self.arView.videoGravity = AVLayerVideoGravityResizeAspectFill;

    [self createShapesOfSize:_currentSize atDistance:SHAPE_DISTANCE height:SHAPE_HEIGHT];

    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 16)];
    self.infoLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.textColor = [UIColor blackColor];

    UIBarButtonItem *info = [[UIBarButtonItem alloc] initWithCustomView:self.infoLabel];

    UISwitch *modeSwitch = [[UISwitch alloc] init];
    
    modeSwitch.onTintColor = [UIColor whiteColor];
    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    self.toolbarItems = @[ flex, info, flex ];
    
    [self updateFOV];
    [self updateInfo];
}

- (void)viewWillAppear:(BOOL)animated {
    
	[super viewWillAppear:animated];

	[self.arView start];
    
    self.arView.interfaceOrienation = self.interfaceOrientation;
}

- (void)viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];
    
    self.arView.interfaceOrienation = self.interfaceOrientation;
}

- (void)viewDidDisappear:(BOOL)animated {
    
	[super viewDidDisappear:animated];
    
	[self.arView stop];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

    if ([segue.identifier isEqualToString:@"OpenSettings"]) {
        
        UINavigationController *navigation = segue.destinationViewController;
        FOVSettingsViewController *controller = (FOVSettingsViewController *)navigation.topViewController;
        
        controller.videoGravity = self.arView.videoGravity;
        
        controller.overlaySize = _currentSize;
        controller.overlayHeight = self.horizontalShape.height;
        controller.overlayDistance = self.horizontalShape.distance;
    }
}

#pragma mark - Appearance

- (NSUInteger)supportedInterfaceOrientations {
    
    return UIInterfaceOrientationMaskAll;
}

- (UIStatusBarStyle)preferredStatusBarStyle {

    return UIStatusBarStyleLightContent;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {

    [self updateFOV];
    [self updateInfo];

    self.arView.interfaceOrienation = self.interfaceOrientation;
}

#pragma mark - Accessors

- (NSDictionary *)fieldOfView {

    if (_fieldOfView == nil) {
    
        _fieldOfView = @{ @"iPhone3,1": @{ @"portrait": @60.0, @"landscape": @40.0 }, /* iPhone 4: !!!Unknown!!! */
                          @"iPhone3,3": @{ @"portrait": @60.0, @"landscape": @40.0 },
                          @"iPhone4,1": @{ @"portrait": @60.0, @"landscape": @40.0 }, /* iPhone 4S: !!!Unknown!!! */
                          @"iPhone5,1": @{ @"portrait": @55.0, @"landscape": @32.0 }, /* iPhone 5 & 5c: OK */
                          @"iPhone5,2": @{ @"portrait": @55.0, @"landscape": @32.0 },
                          @"iPhone5,3": @{ @"portrait": @55.0, @"landscape": @32.0 },
                          @"iPhone5,4": @{ @"portrait": @55.0, @"landscape": @32.0 },
                          @"iPhone6,1": @{ @"portrait": @60.0, @"landscape": @37.0 }, /* iPhone 5s: OK */
                          @"iPhone6,2": @{ @"portrait": @60.0, @"landscape": @37.0 },
                          @"iPod4,1":   @{ @"portrait": @60.0, @"landscape": @40.0 }, /* iPod 4G: !!!Unknown!!! */
                          @"iPod5,1":   @{ @"portrait": @57.0, @"landscape": @35.0 }, /* iPod 5G: OK */
                          @"iPad2,1":   @{ @"portrait": @44.0, @"landscape": @33.0 }, /* iPad 2: OK */
                          @"iPad2,2":   @{ @"portrait": @44.0, @"landscape": @33.0 },
                          @"iPad2,3":   @{ @"portrait": @44.0, @"landscape": @33.0 },
                          @"iPad2,4":   @{ @"portrait": @44.0, @"landscape": @33.0 },
                          @"iPad2,5":   @{ @"portrait": @45.0, @"landscape": @34.0 }, /* iPad mini:OK */
                          @"iPad2,6":   @{ @"portrait": @45.0, @"landscape": @34.0 },
                          @"iPad2,7":   @{ @"portrait": @45.0, @"landscape": @34.0 },
                          @"iPad3,1":   @{ @"portrait": @35.0, @"landscape": @27.0 }, /* iPad 3: OK */
                          @"iPad3,2":   @{ @"portrait": @35.0, @"landscape": @27.0 },
                          @"iPad3,3":   @{ @"portrait": @35.0, @"landscape": @27.0 },
                          @"iPad3,4":   @{ @"portrait": @35.0, @"landscape": @27.0 }, /* iPad 4: Guessed from iPad 3 */
                          @"iPad3,5":   @{ @"portrait": @35.0, @"landscape": @27.0 },
                          @"iPad3,6":   @{ @"portrait": @35.0, @"landscape": @27.0 },
                          @"iPad4,1":   @{ @"portrait": @44.0, @"landscape": @34.0 }, /* iPad Air: OK */
                          @"iPad4,2":   @{ @"portrait": @44.0, @"landscape": @34.0 },
                          @"iPad4,4":   @{ @"portrait": @44.0, @"landscape": @34.0 }, /* iPad mini Retina: Guessed from iPad Air */
                          @"iPad4,5":   @{ @"portrait": @44.0, @"landscape": @34.0 },
                          @"i386":      @{ @"portrait": @60.0, @"landscape": @40.0 }, /* Simulator */
                          @"x86_64":    @{ @"portrait": @60.0, @"landscape": @40.0 } };
    }
    
    return _fieldOfView;
}

#pragma mark - Actions

- (IBAction)handleTap:(id)sender {
    
    [self.navigationController setNavigationBarHidden:!self.navigationController.navigationBarHidden animated:YES];
    [self.navigationController setToolbarHidden:!self.navigationController.toolbarHidden animated:YES];
}

- (IBAction)handlePan:(id)sender {

    static float startHeight;
    static CGPoint startLocation;

    UIPanGestureRecognizer *recognizer = sender;
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {

        startHeight = self.horizontalShape.height;
        startLocation = [recognizer locationInView:self.arView];

    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        CGPoint location = [recognizer locationInView:self.arView];
        CGFloat delta = location.y - startLocation.y;
        
        self.horizontalShape.height = startHeight - roundf(0.1 * delta);
        
        [self updateInfo];
    }
}

- (IBAction)handlePinch:(id)sender {

    static float startPortraitFOV;
    static float startLandscapeFOV;
    
    UIPinchGestureRecognizer *recognizer = sender;
    
    switch (recognizer.state) {
            
        case UIGestureRecognizerStateBegan: {
            
            startPortraitFOV = self.arView.fieldOfViewPortrait;
            startLandscapeFOV = self.arView.fieldOfViewLandscape;

            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            
            CGFloat currentScale = recognizer.scale;

            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {

                float fov = startPortraitFOV / currentScale;
                
                if (_pinchFactor != 1.0) {
                    
                    fov = roundf(fov * _pinchFactor) / _pinchFactor;
                    
                    if (fov < _targetFOVPortrait - 1.0) fov = _targetFOVPortrait - 1.0; else if (fov > _targetFOVPortrait + 1.0) fov = _targetFOVPortrait + 1.0;
                    
                } else {
                    
                    fov = roundf(fov);

                    if (fov < FOV_MIN) fov = FOV_MIN; else if (fov > FOV_MAX) fov = FOV_MAX;
                }

                self.arView.fieldOfViewPortrait = fov;
                
            } else {
                
                float fov = startLandscapeFOV / currentScale;
                
                if (_pinchFactor != 1.0) {
                    
                    fov = roundf(fov * _pinchFactor) / _pinchFactor;
                    
                    if (fov < _targetFOVLandscape - 1.0) fov = _targetFOVLandscape - 1.0; else if (fov > _targetFOVLandscape + 1.0) fov = _targetFOVLandscape + 1.0;
                    
                } else {
                    
                    fov = roundf(fov);
                    
                    if (fov < FOV_MIN) fov = FOV_MIN; else if (fov > FOV_MAX) fov = FOV_MAX;
                }
                
                self.arView.fieldOfViewLandscape = fov;
            }
            
            [self updateFOV];
            
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {

        }
            
        default:
            
            // Just to avoid compiler warnings
            break;
    }
}

- (IBAction)closeInfo:(UIStoryboardSegue *)segue {
}

- (IBAction)closeSettings:(UIStoryboardSegue *)segue {
    
    FOVSettingsViewController *controller = segue.sourceViewController;
    
    self.arView.videoGravity = controller.videoGravity;
    
    [self createShapesOfSize:controller.overlaySize atDistance:controller.overlayDistance height:controller.overlayHeight];
    
    _currentSize = controller.overlaySize;
    
    [self updateInfo];
}

#pragma mark - Helpers

- (void)createShapesOfSize:(CGSize)size atDistance:(CGFloat)distance height:(CGFloat)height {

    self.verticalShape = [[FOVARRectShape alloc] initWithContext:self.arView.renderContext size:size];
    self.verticalShape.distance = distance;
    
    self.horizontalShape = [[FOVARPlaneShape alloc] initWithContext:self.arView.renderContext size:size];
    self.horizontalShape.height = height;
    self.horizontalShape.distance = distance;

    self.arView.shapes = @[ self.verticalShape, self.horizontalShape ];
}

- (void)updateInfo {
    
    NSString *w = [NSNumberFormatter localizedStringFromNumber:@(_currentSize.width) numberStyle:NSNumberFormatterDecimalStyle];
    NSString *h = [NSNumberFormatter localizedStringFromNumber:@(_currentSize.height) numberStyle:NSNumberFormatterDecimalStyle];
    NSString *dist = [NSNumberFormatter localizedStringFromNumber:@(self.verticalShape.distance) numberStyle:NSNumberFormatterDecimalStyle];
    NSString *height = [NSNumberFormatter localizedStringFromNumber:@(self.horizontalShape.height) numberStyle:NSNumberFormatterDecimalStyle];
    
    self.infoLabel.text = [NSString stringWithFormat:@"%@cm x %@cm @ %@cm / %@cm", w, h, dist, height];
}

- (void)updateFOV {
    
    NSString *fov = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? [NSNumberFormatter localizedStringFromNumber:@(self.arView.fieldOfViewPortrait) numberStyle:NSNumberFormatterDecimalStyle] : [NSNumberFormatter localizedStringFromNumber:@(self.arView.fieldOfViewLandscape) numberStyle:NSNumberFormatterDecimalStyle];
    
    self.fovLabel.text = [NSString stringWithFormat:@"%@°", fov];
}

@end
