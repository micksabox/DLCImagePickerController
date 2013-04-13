//
//  CIFilterImagePickerController.h
//  DLCImagePickerController
//
//  Created by Michael Nolivos on 2013-04-04.
//  Copyright (c) 2013 Backspaces Inc. All rights reserved.
//

#import "DLCImagePickerController.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>
#import "UIColor+Expanded.h"
#import "AVCamUtilities.h"

#define CAMERA_PREVIEW_DIMENSION 480 //360

@interface CIFilterImagePickerController : DLCImagePickerController
<
AVCaptureVideoDataOutputSampleBufferDelegate
>
{
    
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureSession *session;
    AVCaptureStillImageOutput *imageOutput;
    AVCaptureConnection *cameraConnection;
    AVCaptureVideoDataOutput *output;

    CIContext *ciContext;
    
    CALayer *videoLayer;
//    CALayer *originalLayer;
    BOOL useFilters;
    

}
@property(nonatomic,readonly)AVCaptureSession *session;
@property (strong) UIImage * colorMapGradient;
@property (strong) AVCaptureDevice * currentCaptureDevice;

@property (strong) CIFilter * currentFilter;

@property (strong) UIImageView * staticImageView;

@end

@protocol CIFilterImagePickerControllDelegate <NSObject>

/*
 Return the number of filters to be used for the filter picker.
 */
-(NSInteger)numberOfFilters:(CIFilterImagePickerController *)fPicker;

/*
 Returns the preview image to be shown for a specified index
 */
-(UIImage *)filterPicker:(CIFilterImagePickerController *)fPicker imageForPickerAtIndex:(NSInteger)fIndex;

@end
