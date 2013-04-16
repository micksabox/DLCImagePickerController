//
//  DLCImagePickerController.h
//  DLCImagePickerController
//
//  Created by Dmitri Cherniak on 8/14/12.
//  Copyright (c) 2012 Dmitri Cherniak. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "GPUImage.h"
#import "BlurOverlayView.h"
#import <QuartzCore/QuartzCore.h>

@class DLCImagePickerController;

@protocol DLCImagePickerDelegate <NSObject>
@optional
- (void)imagePickerController:(DLCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
- (void)imagePickerControllerDidCancel:(DLCImagePickerController *)picker;
@end

/*
 Abstract superclass for capturing photo with option of filters and options of live video feed or static image from library.
 */

@interface DLCImagePickerController : UIViewController <UINavigationControllerDelegate,UIImagePickerControllerDelegate> {
//    GPUImageStillCamera *stillCamera;
//    GPUImageOutput<GPUImageInput> *filter;
//    GPUImageOutput<GPUImageInput> *blurFilter;
//    GPUImageCropFilter *cropFilter;
//    GPUImagePicture *staticPicture;
    UIImageOrientation staticPictureOriginalOrientation;
    
}

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) id <DLCImagePickerDelegate> delegate;
@property (nonatomic, weak) IBOutlet UIButton *photoCaptureButton;
@property (nonatomic, weak) IBOutlet UIButton *cancelButton;

@property (nonatomic, weak) IBOutlet UIButton *cameraToggleButton;
@property (nonatomic, weak) IBOutlet UIButton *blurToggleButton;
@property (nonatomic, weak) IBOutlet UIButton *filtersToggleButton;
@property (nonatomic, weak) IBOutlet UIButton *libraryToggleButton;
@property (nonatomic, weak) IBOutlet UIButton *flashToggleButton;
@property (nonatomic, weak) IBOutlet UIButton *retakeButton;

@property (nonatomic, weak) IBOutlet UIScrollView *filterScrollView;
@property (nonatomic, weak) IBOutlet UIImageView *filtersBackgroundImageView;
@property (nonatomic, weak) IBOutlet UIView *photoBar;
@property (nonatomic, weak) IBOutlet UIView *topBar;
@property (nonatomic, strong) BlurOverlayView *blurOverlayView;
@property (nonatomic, strong) UIImageView *focusView;

@property (nonatomic, assign) CGFloat outputJPEGQuality;

@property (nonatomic, assign) int selectedFilter;

#pragma mark - Subclass These
-(void) loadFilters;
-(void) setUpCamera;
-(void) prepareFilter;
-(IBAction) switchCamera;
-(void) prepareForCapture;
-(void)captureImage;
-(void) removeAllTargets;
-(IBAction) retakePhoto:(UIButton *)button;
-(void) prepareLiveFilter;
-(void) prepareStaticFilter;
-(void) showFilters;
@end
