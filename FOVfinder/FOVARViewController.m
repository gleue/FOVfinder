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
#define SHAPE_DISTANCE 72.5 //100.0

@interface FOVARViewController () <FOVARViewDelegate> {
    
    CGSize _currentSize;

    float _pinchFactor;
    
    BOOL _isFocusing;
    CGFloat _lensPosition;
}

@property (weak, nonatomic) IBOutlet FOVARView *arView;
@property (weak, nonatomic) IBOutlet UILabel *fovLabel;
@property (weak, nonatomic) IBOutlet UILabel *zoomLabel;
@property (weak, nonatomic) IBOutlet UILabel *focusLabel;

@property (strong, nonatomic) IBOutlet UIPanGestureRecognizer *panRecognizer;
@property (strong, nonatomic) IBOutlet UIPinchGestureRecognizer *pinchRecognizer;

@property (strong, nonatomic) UILabel *infoLabel;

@property (strong, nonatomic) FOVARRectShape *verticalShape;
@property (strong, nonatomic) FOVARPlaneShape *horizontalShape;

@property (assign, nonatomic, getter=isLensAdjustmentEnabled) BOOL lensAdjustmentEnabled;
@property (assign, nonatomic) CGFloat lensAdjustmentFactor;

@end

@implementation FOVARViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {

	[super viewDidLoad];
    
    _pinchFactor = 100.0;
    _currentSize = CGSizeMake(21.0, 29.7);

    self.lensAdjustmentEnabled = YES;
    self.lensAdjustmentFactor = 0.05;

    self.navigationItem.title = [UIDeviceHardware platformString];
    
    self.arView.delegate = self;

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
}

- (void)viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];
    
    self.arView.interfaceOrienation = self.interfaceOrientation;
    
    [self updateFOV];
    [self updateZoom];
}

- (void)viewDidDisappear:(BOOL)animated {
    
	[super viewDidDisappear:animated];
    
	[self.arView stop];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

    if ([segue.identifier isEqualToString:@"OpenSettings"]) {
        
        UINavigationController *navigation = segue.destinationViewController;
        FOVSettingsViewController *controller = (FOVSettingsViewController *)navigation.topViewController;
        
        controller.videoFormat = self.arView.currentVideoPreset;
        controller.videoGravity = self.arView.videoGravity;
        
        controller.overlaySize = _currentSize;
        controller.overlayHeight = self.horizontalShape.height;
        controller.overlayDistance = self.horizontalShape.distance;
        
        controller.lensAdjustmentEnabled = self.lensAdjustmentEnabled;
        controller.lensAdjustmentFactor = self.lensAdjustmentFactor;
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

- (IBAction)handlePan:(UIPanGestureRecognizer *)recognizer {
    
    static CGPoint startLocation;
    static CGFloat startVideoZoom;

    switch (recognizer.state) {
            
        case UIGestureRecognizerStateBegan: {
            
            startLocation = [recognizer locationInView:self.arView];
            startVideoZoom = self.arView.currentVideoZoom;
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            
            CGPoint location = [recognizer locationInView:self.arView];
            
            self.arView.currentVideoZoom = startVideoZoom * (1.0 + 2.0 * (startLocation.y - location.y) / CGRectGetHeight(self.arView.bounds));
            
            [self updateZoom];
            break;
        }
            
        default:
            
            // Just to avoid compiler warnings
            break;
    }
}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *)recognizer {

    static float startPortraitFOV;
    static float startLandscapeFOV;
    
    switch (recognizer.state) {
            
        case UIGestureRecognizerStateBegan: {
            
            startPortraitFOV = self.arView.effectiveFieldOfViewPortrait;
            startLandscapeFOV = self.arView.effectiveFieldOfViewLandscape;
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {

                float fov = startPortraitFOV / recognizer.scale;
                
                fov = roundf(fov * _pinchFactor) / _pinchFactor;
                
                if (fov < FOV_MIN) fov = FOV_MIN; else if (fov > FOV_MAX) fov = FOV_MAX;

                self.arView.fovScalePortrait = fov / self.arView.fieldOfViewPortrait;
                self.lensAdjustmentEnabled = NO;
                
            } else {
                
                float fov = startLandscapeFOV / recognizer.scale;
                
                fov = roundf(fov * _pinchFactor) / _pinchFactor;
                
                if (fov < FOV_MIN) fov = FOV_MIN; else if (fov > FOV_MAX) fov = FOV_MAX;
                
                self.arView.fovScaleLandscape = fov / self.arView.fieldOfViewLandscape;
                self.lensAdjustmentEnabled = NO;
            }
            
            [self updateFOV];
            break;
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

- (IBAction)closeSettings:(UIStoryboardSegue *)segue {
    
    FOVSettingsViewController *controller = segue.sourceViewController;
    
    self.arView.videoPreset = controller.videoFormat;
    self.arView.videoGravity = controller.videoGravity;
    
    [self createShapesOfSize:controller.overlaySize atDistance:controller.overlayDistance height:controller.overlayHeight];
    
    _currentSize = controller.overlaySize;
    
    [self updateInfo];
    
    self.lensAdjustmentEnabled = controller.isLensAdjustmentEnabled;
    self.lensAdjustmentFactor = controller.lensAdjustmentFactor;
    
    if (self.isLensAdjustmentEnabled) {
        
        [self updateLensAdjustment];
        
    } else {
        
        [self resetFOV:nil];
    }
    
    [self updateZoom];
}

#pragma mark - FOVARViewDelegate protocol

- (void)arViewDidStartAdjustingFocus:(FOVARView *)view {
    
    _isFocusing = YES;
    
    [self updateLens];
}

- (void)arViewDidStopAdjustingFocus:(FOVARView *)view {

    _isFocusing = NO;
    
    [self updateLens];
}

- (void)arView:(FOVARView *)view didChangeLensPosition:(CGFloat)position {

    _lensPosition = position;
    
    [self updateLens];
    [self updateLensAdjustment];
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
    
    NSString *fov = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? [NSNumberFormatter localizedStringFromNumber:@(self.arView.effectiveFieldOfViewPortrait) numberStyle:NSNumberFormatterDecimalStyle] : [NSNumberFormatter localizedStringFromNumber:@(self.arView.effectiveFieldOfViewLandscape) numberStyle:NSNumberFormatterDecimalStyle];
    
    self.fovLabel.text = [NSString stringWithFormat:@"%@°", fov];
}

- (void)updateZoom {

    if (self.arView.maxVideoZoom > 1.0) {
        
        NSString *zoom = [NSNumberFormatter localizedStringFromNumber:@(self.arView.currentVideoZoom) numberStyle:NSNumberFormatterDecimalStyle];
        
        self.zoomLabel.text = [NSString stringWithFormat:@"x%@", zoom];
        self.zoomLabel.hidden = NO;
        self.panRecognizer.enabled = YES;

    } else {
        
        self.zoomLabel.hidden = YES;
        self.panRecognizer.enabled = NO;
    }
}

- (void)updateLens {
    
    NSString *text = _isFocusing ? @"⌾ " : @"";
    NSString *lens = [NSNumberFormatter localizedStringFromNumber:@(_lensPosition) numberStyle:NSNumberFormatterDecimalStyle];

    self.focusLabel.text = [text stringByAppendingString:lens];
}

- (void)updateLensAdjustment {
    
    if (self.isLensAdjustmentEnabled) {
        
        CGFloat scale = 1.0 + _lensPosition * self.lensAdjustmentFactor;
        
        self.arView.fovScalePortrait = self.arView.fovScaleLandscape = scale;
    }
    
    [self updateFOV];
}

@end
