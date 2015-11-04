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

#pragma mark - Math utilities declaration

#define DEGREES_TO_RADIANS (M_PI/180.0)

#pragma mark - ARView extension

@interface FOVARView () {

    GLKMatrix4 _projectionMatrix;
}

@property (strong, nonatomic) GLKView *renderView;
@property (strong, nonatomic) EAGLContext *renderContext;

@property (strong, nonatomic) UIView *captureView;
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

- (void)setFieldOfViewPortrait:(float)fieldOfViewPortrait {

    _fieldOfViewPortrait = fieldOfViewPortrait;

    [self updateProjectionMatrix];
}

- (void)setFieldOfViewLandscape:(float)fieldOfViewLandscape {
    
    _fieldOfViewLandscape = fieldOfViewLandscape;
    
    [self updateProjectionMatrix];
}

- (void)updateProjectionMatrix {

    // Initialize camera & projection matrix
    //
    float fovy = UIInterfaceOrientationIsPortrait(self.interfaceOrienation) ? self.fieldOfViewPortrait : self.fieldOfViewLandscape;
    float aspect = self.bounds.size.width / self.bounds.size.height;
    
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(fovy), aspect, 0.1f, 1000.0f);
}

#pragma mark - Methods

- (void)start {
    
	[self startCameraPreview];
	[self startDisplayLink];
    
    [self setNeedsLayout];
}

- (void)stop {

	[self stopDisplayLink];
	[self stopCameraPreview];
}

#pragma mark - Camera management

- (void)startCameraPreview {

	AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

	if (camera == nil) return;
	
	self.captureSession = [[AVCaptureSession alloc] init];
    
	AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:nil];

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

	self.captureSession = nil;
	self.captureLayer = nil;
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

@end
