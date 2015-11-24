//
//  FOVARView.m
//  FOVfinder
//
//  Created by Tim Gleue on 21.10.13.
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

#import "FOVARView.h"
#import "FOVARShape.h"

#import <AVFoundation/AVFoundation.h>

static char FOVARViewKVOContext;

#pragma mark - Math utilities declaration

#define DEGREES_TO_RADIANS (M_PI/180.0)

#pragma mark - ARView extension

@interface FOVARView () {

    GLKMatrix4 _projectionMatrix;
}

@property (strong, nonatomic) GLKView *renderView;
@property (strong, nonatomic) EAGLContext *renderContext;

@property (strong, nonatomic) UIView *captureView;
@property (strong, nonatomic) AVCaptureDevice *captureDevice;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureLayer;

@property (strong, nonatomic) CADisplayLink *displayLink;

- (void)initARView;

- (void)startCameraPreview;
- (void)stopCameraPreview;

- (void)startDisplayLink;
- (void)stopDisplayLink;

- (void)onDisplayLink:(id)sender;

@end

#pragma mark - ARView implementation

@implementation FOVARView

@synthesize fieldOfViewPortrait = _fieldOfViewPortrait;
@synthesize fieldOfViewLandscape = _fieldOfViewLandscape;

- (id)initWithFrame:(CGRect)frame {
    
	self = [super initWithFrame:frame];
    
	if (self) [self initARView];
    
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
	self = [super initWithCoder:aDecoder];
	
    if (self) [self initARView];
    
	return self;
}

- (void)initARView {
    
    self.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    self.fovScalePortrait = 1.0;
    self.fovScaleLandscape = 1.0;
    
    // Make camera preview in background
    //
    self.captureView = [[UIView alloc] initWithFrame:self.bounds];

    [self addSubview:self.captureView];
	[self sendSubviewToBack:self.captureView];
    
    // Make transparent GL view above preview
    //
    self.renderContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    self.renderView = [[GLKView alloc] initWithFrame:self.bounds context:self.renderContext];
    self.renderView.delegate = self;
    self.renderView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    
    CAEAGLLayer *renderLayer = (CAEAGLLayer *)self.renderView.layer;
    
    renderLayer.opaque = NO;
    
    self.renderView.backgroundColor = [UIColor clearColor];
    self.renderView.opaque = NO;
    
    [self insertSubview:self.renderView aboveSubview:self.captureView];
}

- (void)dealloc {

	[self stop];

	[self.captureView removeFromSuperview];
	[self.renderView removeFromSuperview];
    
    if ([EAGLContext currentContext] == self.renderContext) {

        [EAGLContext setCurrentContext:nil];
    }
    
    self.renderContext = nil;
}

- (void)layoutSubviews {
    
    CGRect bounds = self.bounds;

    self.captureLayer.frame = bounds;
    self.renderView.frame = bounds;

    [self computeFOVfromCameraFormat];
    [self updateProjectionMatrix];

    [super layoutSubviews];
}

#pragma mark - Accessors

- (void)setVideoGravity:(NSString *)videoGravity {

    if (![videoGravity isEqualToString:_videoGravity]) {
        
        _videoGravity = videoGravity;
        
        self.captureLayer.videoGravity = self.videoGravity;
        
        [self setNeedsLayout];
    }
}

- (void)setInterfaceOrienation:(UIInterfaceOrientation)interfaceOrienation {

    _interfaceOrienation = interfaceOrienation;
    
    switch (self.interfaceOrienation) {
            
        case UIInterfaceOrientationPortrait:
            
            if (self.captureLayer.connection.isVideoOrientationSupported) [self.captureLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            
            if (self.captureLayer.connection.isVideoOrientationSupported) [self.captureLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            
            if (self.captureLayer.connection.isVideoOrientationSupported) [self.captureLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            
            if (self.captureLayer.connection.isVideoOrientationSupported) [self.captureLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
            break;
            
        default:

            break;
    }
    
    [self updateProjectionMatrix];
}

- (void)setFovScalePortrait:(CGFloat)fovScale {

    _fovScalePortrait = fovScale;
    
    [self updateProjectionMatrix];
}

- (void)setFovScaleLandscape:(CGFloat)fovScale {
    
    _fovScaleLandscape = fovScale;
    
    [self updateProjectionMatrix];
}

- (NSString *)currentVideoPreset {
    
    return self.captureSession.sessionPreset;
}

- (CGFloat)maxVideoZoom {
    
    return self.captureDevice.activeFormat.videoMaxZoomFactor;
}

- (CGFloat)currentVideoZoom {
    
    return self.captureDevice.videoZoomFactor;
}

- (void)setCurrentVideoZoom:(CGFloat)zoom {

    if ([self.captureDevice lockForConfiguration:nil]) {

        self.captureDevice.videoZoomFactor = MAX(1.0, MIN(zoom, self.captureDevice.activeFormat.videoMaxZoomFactor));

        [self.captureDevice unlockForConfiguration];
        
        [self computeFOVfromCameraFormat];
        [self updateProjectionMatrix];
    }
}

- (CGFloat)effectiveFieldOfViewPortrait {

    return self.fovScalePortrait * self.fieldOfViewPortrait;
}

- (CGFloat)effectiveFieldOfViewLandscape {
    
    return self.fovScaleLandscape * self.fieldOfViewLandscape;
}

#pragma mark - Methods

- (void)start {

	[self startCameraPreview];
	[self startDisplayLink];
    
    [self setNeedsLayout];
    
    [self computeFOVfromCameraFormat];
}

- (void)stop {

	[self stopDisplayLink];
	[self stopCameraPreview];
}

#pragma mark - Projection management

- (void)computeFOVfromCameraFormat {
    
    if (self.captureDevice) {
        
        CGFloat aspectRatio = self.bounds.size.width / self.bounds.size.height;
        
        if (aspectRatio > 1.0) aspectRatio = 1.0 / aspectRatio;
        
        AVCaptureDeviceFormat *activeFormat = self.captureDevice.activeFormat;

        NSLog(@"Active: %@", self.captureDevice.activeFormat);
        
        CMFormatDescriptionRef description = activeFormat.formatDescription;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(description);
        
        CGFloat activeFOV = 2.0 * atan(tan(0.5 * activeFormat.videoFieldOfView * DEGREES_TO_RADIANS) / self.captureDevice.videoZoomFactor) / DEGREES_TO_RADIANS;
        
        CGFloat aspectWidth = (CGFloat)dimensions.height / aspectRatio;
        CGFloat aspectHeight = (CGFloat)dimensions.width * aspectRatio;
        
        if ([self.videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
            
            CGFloat aspectFOV;
            
            if (aspectWidth < dimensions.width) {
                
                aspectFOV = 2.0 * atan(aspectWidth / (CGFloat)dimensions.width * tan(0.5 * activeFOV * DEGREES_TO_RADIANS)) / DEGREES_TO_RADIANS;
                
            } else if (aspectHeight < dimensions.height) {
                
                aspectFOV = activeFOV;
                
            } else {
                
                aspectFOV = activeFOV;
            }

            _fieldOfViewPortrait = aspectFOV;
            _fieldOfViewLandscape = 2.0 * atan(tan(0.5 * aspectFOV * DEGREES_TO_RADIANS) * aspectRatio) / DEGREES_TO_RADIANS;
            
        } else if ([self.videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]) {

            CGFloat aspectFOV;

            if (aspectHeight > dimensions.height) {
                
                // Left and right bars added (in portrait)
                //
                aspectFOV = activeFOV;

            } else if (aspectWidth > dimensions.width) {
                
                // Top and bottom bars added (in portrait)
                //
                aspectFOV = 2.0 * atan(aspectWidth / (CGFloat)dimensions.width * tan(0.5 * activeFOV * DEGREES_TO_RADIANS)) / DEGREES_TO_RADIANS;

            } else {
                
                // Matching aspect ratio -- no bars added
                //
                aspectFOV = activeFOV;
            }

            _fieldOfViewPortrait = aspectFOV;
            _fieldOfViewLandscape = 2.0 * atan(tan(0.5 * aspectFOV * DEGREES_TO_RADIANS) * aspectRatio) / DEGREES_TO_RADIANS;
        }
        
        NSLog(@"Portrait FOV: %g", self.fieldOfViewPortrait);
        NSLog(@"Landscape FOV: %g", self.fieldOfViewLandscape);
    }
}

- (void)updateProjectionMatrix {
    
    // Initialize camera & projection matrix
    //
    CGFloat fovy = UIInterfaceOrientationIsPortrait(self.interfaceOrienation) ? self.effectiveFieldOfViewPortrait : self.effectiveFieldOfViewLandscape;
    CGFloat aspect = self.bounds.size.width / self.bounds.size.height;
    
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(fovy), aspect, 0.1f, 1000.0f);
}

#pragma mark - Camera management

- (void)startCameraPreview {

	AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

//    if ([camera lockForConfiguration:NULL]) {
//
//        // Lock auto focus to min distance
//        //
//        [camera setFocusModeLockedWithLensPosition:0.0 completionHandler:nil];
//        [camera unlockForConfiguration];
//    }

	if (camera == nil) return;
	
    self.captureDevice = camera;

    [self.captureDevice addObserver:self forKeyPath:@"focusMode" options:NSKeyValueObservingOptionInitial context:&FOVARViewKVOContext];
    [self.captureDevice addObserver:self forKeyPath:@"lensPosition" options:NSKeyValueObservingOptionInitial context:&FOVARViewKVOContext];
    [self.captureDevice addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:&FOVARViewKVOContext];

	self.captureSession = [[AVCaptureSession alloc] init];
    
    if (self.videoPreset && [self.captureSession canSetSessionPreset:self.videoPreset]) {
        
        self.captureSession.sessionPreset = self.videoPreset;
    }
    
	AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.captureDevice error:nil];

	[self.captureSession addInput:newVideoInput];
	
	self.captureLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
	self.captureLayer.frame = self.captureView.bounds;
    self.captureLayer.videoGravity = self.videoGravity;

	[self.captureView.layer addSublayer:self.captureLayer];
	
	// Start the session.
    //
    // This is done asychronously since -startRunning
    // doesn't return until the session is running.
    //
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
		[self.captureSession startRunning];
	});
}

- (void)stopCameraPreview {

	[self.captureSession stopRunning];
    [self.captureLayer removeFromSuperlayer];

    self.captureLayer = nil;
    self.captureSession = nil;

    [self.captureDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    [self.captureDevice removeObserver:self forKeyPath:@"lensPosition"];
    [self.captureDevice removeObserver:self forKeyPath:@"focusMode"];

    self.captureDevice = nil;
}

#pragma mark - Redraw management

- (void)startDisplayLink {
    
	self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLink:)];

	[self.displayLink setFrameInterval:1];
	[self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)onDisplayLink:(id)sender {

    // Trigger -glkView:drawInRect:
    //
    [self.renderView setNeedsDisplay];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {

    // Use transparent clear color to let
    // underlying capture view look through
    //
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    GLKMatrix4 viewMatrix = GLKMatrix4Identity;

    for (FOVARShape *shape in self.shapes) {
        
        // Local POI transformation
        //
        GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(0.0, shape.height, -shape.distance);
        
        shape.effect.transform.modelviewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
        shape.effect.transform.projectionMatrix = _projectionMatrix;
        
        [shape draw];
    }
}

- (void)stopDisplayLink {
    
	[self.displayLink invalidate];

	self.displayLink = nil;
}

#pragma mark - Key-value Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {

    if (context == &FOVARViewKVOContext) {

        if ([keyPath isEqualToString:@"focusMode"]) {
            
            if ([self.delegate respondsToSelector:@selector(arView:didChangeFocusMode:)]) {
                
                [self.delegate arView:self didChangeFocusMode:self.captureDevice.focusMode];
            }
            
            return;
            
        } else if ([keyPath isEqualToString:@"lensPosition"]) {
            
            if ([self.delegate respondsToSelector:@selector(arView:didChangeLensPosition:)]) {
                
                [self.delegate arView:self didChangeLensPosition:self.captureDevice.lensPosition];
            }
            
            return;
            
        } else if ([keyPath isEqualToString:@"adjustingFocus"]) {
            
            BOOL oldAdjust = [change[NSKeyValueChangeOldKey] boolValue];
            BOOL newAdjust = [change[NSKeyValueChangeNewKey] boolValue];

            if (!oldAdjust && newAdjust && [self.delegate respondsToSelector:@selector(arViewDidStartAdjustingFocus:)]) {
                
                [self.delegate arViewDidStartAdjustingFocus:self];

            } else if (oldAdjust && !newAdjust && [self.delegate respondsToSelector:@selector(arViewDidStopAdjustingFocus:)]) {
                
                [self.delegate arViewDidStopAdjustingFocus:self];
            }

            return;
        }
    }
    
    if ([super respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
        
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
