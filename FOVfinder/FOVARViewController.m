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

- (IBAction)handleTap:(id)sender;
- (IBAction)handlePinch:(id)sender;

- (IBAction)closeInfo:(UIStoryboardSegue *)segue;
- (IBAction)closeSettings:(UIStoryboardSegue *)segue;

@end

@implementation FOVARViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {

	[super viewDidLoad];
    
    _pinchFactor = 10.0;
    _currentSize = CGSizeMake(21.0, 29.7);

    self.navigationItem.title = [UIDeviceHardware platformString];

    [self createShapesOfSize:_currentSize atDistance:SHAPE_DISTANCE height:SHAPE_HEIGHT];

    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 16)];
    self.infoLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.textColor = [UIColor blackColor];

    UIBarButtonItem *info = [[UIBarButtonItem alloc] initWithCustomView:self.infoLabel];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    self.toolbarItems = @[ flex, info, flex ];
    
    [self updateInfo];
}

- (void)viewWillAppear:(BOOL)animated {
    
	[super viewWillAppear:animated];

	[self.arView start];
    
    self.arView.interfaceOrienation = self.interfaceOrientation;
    
    [self updateFOV];
}

- (void)viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];
    
    self.arView.interfaceOrienation = self.interfaceOrientation;
    
    [self updateFOV];
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

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    
    return UIInterfaceOrientationMaskAll;
}

- (UIStatusBarStyle)preferredStatusBarStyle {

    return UIStatusBarStyleLightContent;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
    self.arView.interfaceOrienation = self.interfaceOrientation;

    [self updateFOV];
}

#pragma mark - Actions

- (IBAction)handleTap:(id)sender {
    
    [self.navigationController setNavigationBarHidden:!self.navigationController.navigationBarHidden animated:YES];
    [self.navigationController setToolbarHidden:!self.navigationController.toolbarHidden animated:YES];
}

- (IBAction)handlePinch:(id)sender {

    static float startPortraitFOV;
    static float startLandscapeFOV;
    
    UIPinchGestureRecognizer *recognizer = sender;
    
    switch (recognizer.state) {
            
        case UIGestureRecognizerStateBegan: {
            
            startPortraitFOV = self.arView.fieldOfViewPortrait * self.arView.fovScalePortrait;
            startLandscapeFOV = self.arView.fieldOfViewLandscape * self.arView.fovScaleLandscape;

            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {

                float fov = startPortraitFOV / recognizer.scale;
                
                fov = roundf(fov * _pinchFactor) / _pinchFactor;
                
                if (fov < FOV_MIN) fov = FOV_MIN; else if (fov > FOV_MAX) fov = FOV_MAX;

                self.arView.fovScalePortrait = fov / self.arView.fieldOfViewPortrait;
                
            } else {
                
                float fov = startLandscapeFOV / recognizer.scale;
                
                fov = roundf(fov * _pinchFactor) / _pinchFactor;
                
                if (fov < FOV_MIN) fov = FOV_MIN; else if (fov > FOV_MAX) fov = FOV_MAX;
                
                self.arView.fovScaleLandscape = fov / self.arView.fieldOfViewLandscape;
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

- (IBAction)resetFOV:(id)sender {
    
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {

        self.arView.fovScalePortrait = 1.0;

    } else {
        
        self.arView.fovScaleLandscape = 1.0;
    }
    
    [self updateFOV];
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
    
    NSString *fov = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? [NSNumberFormatter localizedStringFromNumber:@(self.arView.fieldOfViewPortrait * self.arView.fovScalePortrait) numberStyle:NSNumberFormatterDecimalStyle] : [NSNumberFormatter localizedStringFromNumber:@(self.arView.fieldOfViewLandscape * self.arView.fovScaleLandscape) numberStyle:NSNumberFormatterDecimalStyle];
    
    self.fovLabel.text = [NSString stringWithFormat:@"%@°", fov];
}

@end
