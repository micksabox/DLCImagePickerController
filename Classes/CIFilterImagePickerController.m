//
//  CIFilterImagePickerController.m
//  DLCImagePickerController
//
//  Created by Michael Nolivos on 2013-04-04.
//  Copyright (c) 2013 Backspaces Inc. All rights reserved.
//

#import "CIFilterImagePickerController.h"

@interface CIFilterImagePickerController ()
- ( AVCaptureDevice * ) cameraWithPosition : ( AVCaptureDevicePosition ) position;
- (void) swapFrontAndBackCameras ;
-(void)setupColorWithPrimary:(UIColor *)primaryColor;
-(CGImageRef)createImageByPassingThroughCurrentFilter:(CIImage *)originalImage;
@end

@implementation CIFilterImagePickerController
@synthesize session;

- (void)viewDidLoad
{
    
	// Do any additional setup after loading the view.
    
    self.blurToggleButton.enabled = NO;
    
    UIColor * primaryColor = [UIColor cyanColor];
    
    [self setupColorWithPrimary:primaryColor];
    
    

    if( ciContext == nil )
        ciContext = [CIContext contextWithOptions:nil];
    
    _staticImageView = [[UIImageView alloc] initWithFrame:self.imageView.bounds];
    _staticImageView.backgroundColor = [UIColor redColor];
    //We need to transform the image view because
//    _staticImageView.transform = CGAffineTransformMakeRotation(M_PI/2);
    
    // create a capture session
    session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset640x480;
//    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    
    
    
    
    [super viewDidLoad];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- ( AVCaptureDevice * ) cameraWithPosition : ( AVCaptureDevicePosition ) position
{
    NSArray * Devices = [ AVCaptureDevice devicesWithMediaType : AVMediaTypeVideo ] ;
    for ( AVCaptureDevice * Device in Devices )
        if ( Device . position == position )
            return Device ;
    return nil ;
}
- (void) swapFrontAndBackCameras {
    // Assume the session is already running
    
    NSArray * inputs = session.inputs;
    for ( AVCaptureDeviceInput * INPUT in inputs ) {
        AVCaptureDevice * Device = INPUT.device ;
        if ( [ Device hasMediaType : AVMediaTypeVideo ] ) {
            
            AVCaptureDevicePosition position = Device.position ;
            AVCaptureDevice * newCamera = nil ;
            AVCaptureDeviceInput * newInput = nil ;
            
            if ( position == AVCaptureDevicePositionFront )
                newCamera = [ self cameraWithPosition : AVCaptureDevicePositionBack ] ;
            else
                newCamera = [ self cameraWithPosition : AVCaptureDevicePositionFront ] ;
            
            if ([newCamera hasFlash] && [newCamera hasTorch]) {
                [self.flashToggleButton setEnabled:YES];
            } else {
                [self.flashToggleButton setEnabled:NO];
            }

            self.currentCaptureDevice = newCamera;
            
            newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil ] ;
            
            // beginConfiguration ensures that pending changes are not applied immediately
            [session beginConfiguration ] ;
            
            [session removeInput : INPUT ] ;
            [session addInput : newInput ] ;
            

            cameraConnection = [[output connections] objectAtIndex:0];
            cameraConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            // Changes take effect once the outermost commitConfiguration is invoked.
            [ session commitConfiguration ] ;
            break;
        }
    } 
}
#pragma mark
-(void) setUpCamera{
 
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        // Has camera
        
        // setup the device and input
        
        AVCaptureDevice *videoCaptureDevice;
        AVCaptureDevice * frontDevice = [self cameraWithPosition:AVCaptureDevicePositionFront];
        
        if (frontDevice) {
            
            videoCaptureDevice = frontDevice;
        }
        else{
            
            videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        
        self.currentCaptureDevice = videoCaptureDevice;
        
        if([self.currentCaptureDevice hasTorch]){
            [self.flashToggleButton setEnabled:YES];
        }else{
            [self.flashToggleButton setEnabled:NO];
        }

        
        NSError *error = nil;
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoCaptureDevice error:&error];
        
        if (videoInput) {
            [session addInput:videoInput];
            
            // Create a VideoDataOutput and add it to the session
            output = [[AVCaptureVideoDataOutput alloc] init];
            
            NSDictionary *outputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                                       forKey:(id)kCVPixelBufferPixelFormatTypeKey];
            
            output.alwaysDiscardsLateVideoFrames = YES;
            output.videoSettings = outputSettings;
            [session addOutput:output];
            
            imageOutput = [[AVCaptureStillImageOutput alloc] init];
            imageOutput.outputSettings = outputSettings;

            [session addOutput:imageOutput];
            
            // Configure your output.
            dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
            [output setSampleBufferDelegate:self queue:queue];
            dispatch_release(queue);
            
            cameraConnection = [[output connections] objectAtIndex:0];
            cameraConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            if ([cameraConnection isVideoOrientationSupported]) {
                
                [cameraConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            }
            
            videoLayer = [CALayer layer];
            videoLayer.frame = self.imageView.bounds;
            
            [videoLayer removeFromSuperlayer];
            [self.imageView.layer addSublayer:videoLayer];
            
            [session startRunning];
            
            useFilters = YES;
        }
        else { 
            // Handle the failure.
            NSLog(@"No camera input available.");
        }
        
        if([self.currentCaptureDevice hasTorch]){
            [self.flashToggleButton setEnabled:YES];
        }else{
            [self.flashToggleButton setEnabled:NO];
        }
        
        [self prepareFilter];

    } else {
        // No camera
        NSLog(@"No camera");
        
        dispatch_async(dispatch_get_main_queue(), ^{
           
            [self prepareFilter];
        });
        
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    // create memory pool for handling our images since we are off the main thread.
    @autoreleasepool {
        
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // turn buffer into an image we can manipulate
        CIImage *result = [CIImage imageWithCVPixelBuffer:imageBuffer];
        
        
//        NSLog(@"Camera output extent is %@, buffer size is %@", NSStringFromCGRect(result.extent), NSStringFromCGSize(CVImageBufferGetEncodedSize(imageBuffer)));
        
        // store final usable image
        CGImageRef finishedImage;
        
        if( useFilters ) {
            // hue
            
            
            CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
            [cropFilter setValue:result forKey:@"inputImage"];
            
            
            CGRect cropRect = CGRectMake(0, 0, CAMERA_PREVIEW_DIMENSION, CAMERA_PREVIEW_DIMENSION);
            
            CIVector *cropVector = [CIVector vectorWithCGRect:cropRect];
            [cropFilter setValue:cropVector forKey:@"inputRectangle"];
            
            result = cropFilter.outputImage;
            
        }
        else {
            // add vibrance
            
        }
        
        finishedImage = [self createImageByPassingThroughCurrentFilter:result];
        
        [videoLayer performSelectorOnMainThread:@selector(setContents:) withObject:(__bridge id)finishedImage waitUntilDone:YES];
        
        CGImageRelease(finishedImage);
    }
}

-(void)switchCamera{
 
    [self swapFrontAndBackCameras];

}

-(void)prepareForCapture{
 
    if(self.flashToggleButton.selected && [self.currentCaptureDevice hasTorch]){
        
        if ([self.currentCaptureDevice lockForConfiguration:nil]){
         
            [self.currentCaptureDevice setTorchMode:AVCaptureTorchModeOn];

        }
        
        [self.currentCaptureDevice unlockForConfiguration];
        
        [self performSelector:@selector(captureImage)
                   withObject:nil
                   afterDelay:0.5];
    }else{
        [self captureImage];
    }

    
}

-(void)captureImage{
    
    //Stop the camera
    
//    self.imageView.image = [UIImage imageWithCGImage:(CGImageRef)videoLayer.contents];

    

    AVCaptureConnection * connection = [AVCamUtilities connectionWithMediaType:AVMediaTypeVideo fromConnections:[imageOutput connections]];
    
    if ([connection isVideoOrientationSupported]) {
        
        [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    [imageOutput captureStillImageAsynchronouslyFromConnection:connection
                                             completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                
                                                 @autoreleasepool {
                                                     
                                                     // Get a CMSampleBuffer's Core Video image buffer for the media data
                                                     CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(imageDataSampleBuffer);
                                                     
                                                     // turn buffer into an image we can manipulate
                                                     CIImage *result = [CIImage imageWithCVPixelBuffer:imageBuffer];
                                                     
//                                                     NSLog(@"Image output extent is %@", NSStringFromCGRect(result.extent));
                                                     
                                                     // store final usable image
                                                     CGImageRef finishedImage;
                                                     
                                                     CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
                                                     [cropFilter setValue:result forKey:@"inputImage"];
                                                     
                                                     //Offset the crop rect x by the difference of the width and the height of the image.
                                                     //This is because core image starts in a diff coordinate system
                                                     CGRect cropRect = CGRectMake( result.extent.size.width - result.extent.size.height , 0, CAMERA_PREVIEW_DIMENSION, CAMERA_PREVIEW_DIMENSION);
                                                     
                                                     CIVector *cropVector = [CIVector vectorWithCGRect:cropRect];
                                                     [cropFilter setValue:cropVector forKey:@"inputRectangle"];
                                                     
                                                     result = cropFilter.outputImage;
                                                     
                                                     CGAffineTransform rotateTransform = CGAffineTransformMakeRotation(-M_PI/2);
                                                     
                                                     CGAffineTransform translate = CGAffineTransformMakeTranslation(160, result.extent.size.width + 160);
                                                     
                                                     CGAffineTransform finalTransform = CGAffineTransformConcat(rotateTransform, translate);
                                                     
                                                     finishedImage =  [ciContext createCGImage:[result imageByApplyingTransform:finalTransform]
                                                                                      fromRect:[result extent]];
                                                     
                                                     UIImage * croppedImage = [UIImage imageWithCGImage:finishedImage];
                                                     
//                                                     NSLog(@"Image size is %@, orientation is %d", NSStringFromCGSize(croppedImage.size), croppedImage.imageOrientation);
                                                     
                                                     self.imageView.image = croppedImage;
                                                     
                                                     [session stopRunning];
                                                     
                                                     [super captureImage];
                                                     
                                                     CGImageRelease(finishedImage);
                                                     
                                                     /*
                                                     NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                     
                                                     UIImage * image = [[UIImage alloc] initWithData:imageData];
                                                     
                                                    
                                                     
                                                     //Crop the image the same way you do before
                                                     
                                                     NSLog(@"Image size is %@, orientation is %d", NSStringFromCGSize(image.size), image.imageOrientation);
                                                     
                                                     CIImage * imageToCrop = [CIImage imageWithCGImage:image.CGImage];
                                                     
                                                     CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
                                                     [cropFilter setValue:imageToCrop forKey:@"inputImage"];
                                                     
                                                     CGRect cropRect = CGRectMake(0, 0, CAMERA_PREVIEW_DIMENSION, CAMERA_PREVIEW_DIMENSION);
                                                     
                                                     CIVector *cropVector = [CIVector vectorWithCGRect:cropRect];
                                                     [cropFilter setValue:cropVector forKey:@"inputRectangle"];
                                                     
                                                     CIImage * croppedImage = cropFilter.outputImage;
                                                                                                          
                                                     UIImage * properCroppedImage = [UIImage imageWithCIImage:croppedImage];
                                                     
                                                     NSLog(@"Image size is %@", NSStringFromCGSize(properCroppedImage.size));
                                                     
                                                     [self.imageView setImage:properCroppedImage];
                                                     [session stopRunning];
//                                                     [super captureImage];
                                                     
                                                     [self prepareFilter];
                                                     [self.retakeButton setHidden:NO];
                                                     [self.photoCaptureButton setTitle:@"Done" forState:UIControlStateNormal];
                                                     [self.photoCaptureButton setImage:nil forState:UIControlStateNormal];
                                                     [self.photoCaptureButton setEnabled:YES];
                                                     if(![self.filtersToggleButton isSelected]){
                                                         [self showFilters];
                                                     }
                                                     
                                                     
                                                     */
                                                     
                                                 }
                                                 
                                                 
                                                 
                                                 

                                             }];
    
    
    
//    [session stopRunning];
    
//    self.imageView.image = [UIImage imageWithCIImage:self.croppedImageFromCamera];
    
//    [super captureImage];
    
    
}

-(void)removeAllTargets{
    
//    [videoLayer removeFromSuperlayer];
    
//    [session stopRunning];

}

-(IBAction) retakePhoto:(UIButton *)button {

    [super retakePhoto:button];
    
    if([self.currentCaptureDevice hasTorch]){
        [self.flashToggleButton setEnabled:YES];
    }else{
        [self.flashToggleButton setEnabled:NO];
    }
    
    [videoLayer removeFromSuperlayer];
    [self.imageView.layer addSublayer:videoLayer];
    
    [session startRunning];
}

-(void)prepareLiveFilter{
  
//    NSLog(@"prepare live filter");
    
    [_staticImageView removeFromSuperview];
    
}

-(void)prepareStaticFilter{
    
//    NSLog(@"prepare static filter");
    
    [session stopRunning];
    
    [videoLayer removeFromSuperlayer];
    
    
    
    CIImage * originalImage = [CIImage imageWithCGImage:self.imageView.image.CGImage];
    
    CGImageRef filteredImage = [self createImageByPassingThroughCurrentFilter:originalImage];
    
    self.staticImageView.image = [UIImage imageWithCGImage:filteredImage];
    
    [self.imageView addSubview:self.staticImageView];
    
    CGImageRelease(filteredImage);

}

-(UIImage *)finalProcessedImage{
 
   return self.staticImageView.image;
}

#pragma mark -

-(void)setupColorWithPrimary:(UIColor *)primaryColor{
 
    //Setup the color map image
    
    CGFloat mapWidth = 800;
    
    CGSize cmSize = CGSizeMake(mapWidth, 1);
    CGRect cmRect = CGRectMake(0, 0, cmSize.width, cmSize.height);
    
    
    NSArray * triadicColors = [primaryColor triadicColors];
    
    UIColor * secondaryColor = [triadicColors objectAtIndex:0];
    UIColor * tertiaryColor = [triadicColors objectAtIndex:1];
    
    CAGradientLayer * gradLayer = [CAGradientLayer layer];
    gradLayer.frame = cmRect;
    gradLayer.colors = @[(id)[UIColor blackColor].CGColor,
                         (id)primaryColor.CGColor,
                         (id)secondaryColor.CGColor,
                         (id)tertiaryColor.CGColor
                         ];
    
    gradLayer.startPoint = CGPointMake(0.0, 0.5);
    gradLayer.endPoint = CGPointMake(1.0, 0.5);
    
    UIGraphicsBeginImageContext(CGSizeMake(mapWidth, 1));
    
    [gradLayer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage * cmImage = UIGraphicsGetImageFromCurrentImageContext();

    self.colorMapGradient = cmImage;

    
    UIGraphicsEndImageContext();
    
}

-(CGImageRef)createImageByPassingThroughCurrentFilter:(CIImage *)originalImage {
 
    //There are 10 filters
    
    CGImageRef  filteredImage = NULL;
    
    
    if (self.selectedFilter == 0) {
        
        //Clear filter
        filteredImage = [ciContext createCGImage:originalImage fromRect:[originalImage extent]];

        
        
    }
    else{
        
//        CIFilter * colorMap = [CIFilter filterWithName:@"CIColorMap"];
//        [colorMap setValue:originalImage forKey:@"inputImage"];
//        
//        CIImage * ciMapImage = [CIImage imageWithCGImage:self.colorMapGradient.CGImage];
//        [colorMap setValue:ciMapImage forKey:@"inputGradientImage"];

     
        //Use the selected filter as the input to some color filters
        
        NSInteger adjustedIndex = self.selectedFilter;
        
        NSInteger numOfFilters = 10;
        
        CGFloat hue = (CGFloat)adjustedIndex / (CGFloat)numOfFilters;
        
//        NSLog(@"self.selectedFilter = %d, hue is %f", self.selectedFilter, hue);

        
        UIColor * tempColor = [UIColor colorWithHue:hue
                                         saturation:1.0
                                         brightness:1.0
                                              alpha:1.0];
        

        
        CIFilter * monochrome = [CIFilter filterWithName:@"CIColorMonochrome"];
        [monochrome setDefaults];
        
        [monochrome setValue:originalImage forKey:@"inputImage"];
        
        CIColor * monoColor = [CIColor colorWithCGColor:tempColor.CGColor];
        [monochrome setValue:monoColor forKey:@"inputColor"];
        
//        [monochrome setValue:@1 forKey:@"inputIntensity"];
        
        filteredImage = [ciContext createCGImage:monochrome.outputImage fromRect:[originalImage extent]];
        
    }
    
    
    
    return filteredImage;
    
}

@end
