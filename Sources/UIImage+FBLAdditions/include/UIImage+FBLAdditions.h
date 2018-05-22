/**
 Copyright 2018 Google Inc. All rights reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at:

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <UIKit/UIImage.h>
#import <UIKit/UIView.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, FBLImageResizingScale) {
  /** Device's main screen scale factor. */
  FBLImageResizingScaleDefault = 1 << 0,
  FBLImageResizingScale1x = 1 << 1,
  FBLImageResizingScaleMax = FBLImageResizingScale1x,
  FBLImageResizingScaleMask = FBLImageResizingScaleDefault | FBLImageResizingScale1x,
};

typedef NS_OPTIONS(NSUInteger, FBLImageResizingOption) {
  /** Scale the content to a new size by changing the aspect ratio if necessary. */
  FBLImageResizingOptionScaleToFill = FBLImageResizingScaleMax << 1,
  /** Scale the content to wholly fit in a new size by maintaining the aspect ratio. */
  FBLImageResizingOptionScaleAspectFit = FBLImageResizingScaleMax << 2,
  /** Scale the content to wholly fit in a new size by maintaining the aspect ratio & crop extra. */
  FBLImageResizingOptionScaleAspectFitCrop = FBLImageResizingScaleMax << 3,
  /** Scale the content to fill a new size. May clip some portion of the content. */
  FBLImageResizingOptionScaleAspectFill = FBLImageResizingScaleMax << 4,
  /** Centers the image in a new size. Keeps the proportions & clips the content beyond the size. */
  FBLImageResizingOptionCenter = FBLImageResizingScaleMax << 5,
  /** Centers the image in a new size. Aspect fill the content if the image is > size. */
  FBLImageResizingOptionCenterAspectFill = FBLImageResizingScaleMax << 6,
  FBLImageResizingOptionMask = FBLImageResizingOptionScaleToFill |
      FBLImageResizingOptionScaleAspectFit | FBLImageResizingOptionScaleAspectFitCrop |
      FBLImageResizingOptionScaleAspectFill | FBLImageResizingOptionCenter |
      FBLImageResizingOptionCenterAspectFill,
};

typedef NS_OPTIONS(NSUInteger, FBLImageResizingMode) {
  FBLImageResizingModeScaleToFill = FBLImageResizingScaleDefault |
      FBLImageResizingOptionScaleToFill,
  FBLImageResizingModeScaleAspectFit = FBLImageResizingScaleDefault |
      FBLImageResizingOptionScaleAspectFit,
  FBLImageResizingModeScaleAspectFitCrop = FBLImageResizingScaleDefault |
      FBLImageResizingOptionScaleAspectFitCrop,
  FBLImageResizingModeScaleAspectFill = FBLImageResizingScaleDefault |
      FBLImageResizingOptionScaleAspectFill,
  FBLImageResizingModeCenter = FBLImageResizingScaleDefault | FBLImageResizingOptionCenter,
  FBLImageResizingModeCenterAspectFill = FBLImageResizingScaleDefault |
      FBLImageResizingOptionCenterAspectFill,

  FBLImageResizingModeScaleToFill1x = FBLImageResizingScale1x | FBLImageResizingOptionScaleToFill,
  FBLImageResizingModeScaleAspectFit1x = FBLImageResizingScale1x |
      FBLImageResizingOptionScaleAspectFit,
  FBLImageResizingModeScaleAspectFitCrop1x = FBLImageResizingScale1x |
      FBLImageResizingOptionScaleAspectFitCrop,
  FBLImageResizingModeScaleAspectFill1x = FBLImageResizingScale1x |
      FBLImageResizingOptionScaleAspectFill,
  FBLImageResizingModeCenter1x = FBLImageResizingScale1x | FBLImageResizingOptionCenter,
  FBLImageResizingModeCenterAspectFill1x = FBLImageResizingScale1x |
      FBLImageResizingOptionCenterAspectFill,
};

static inline BOOL FBLSizeIsValid(CGSize size) { return size.height >= 1.0 && size.width >= 1.0; }

/**
 Returns a size with the smallest integer values that contains the source size.
 If width or height is negligibly bigger than an integer, it's rounded down, and up otherwise.
 */
static inline CGSize FBLSizeIntegral(CGSize size) {
  CGFloat width = floor(size.width);
  CGFloat height = floor(size.height);
  if (ABS(size.width - width) > 0.001) {
    width = ceil(size.width);
  }
  if (ABS(size.height - height) > 0.001) {
    height = ceil(size.height);
  }
  return CGSizeMake(width, height);
}

static inline CGPoint FBLRectGetCenter(CGRect rect) {
  return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

/** Centers a rect at a point. */
static inline CGRect FBLRectCenterAt(CGRect rect, CGPoint center) {
  CGPoint origin = CGPointMake(center.x - rect.size.width / 2.0, center.y - rect.size.height / 2.0);
  CGRect centeredRect = {.origin = origin, .size = rect.size};
  return centeredRect;
}

/**
 FBLDrawCGImageInCGContext draws image in context with the given orientation and scale.

 This function acts as a replacement for -[UIImage drawInRect:], but draws with CoreGraphics APIs
 only, which is sometimes more efficient than using UIGraphics APIs. Calling this method like:
 FBLDrawCGImageInCGContext(context, uiImage.CGImage, uiImage.orientation, uiImage.scale);
 will produce the same result as calling:
 [uiImage drawInRect:(CGRect){ CGPointZero, uiImage.size }];

 @param context The context in which to draw.
 @param image The image to draw.
 @param orientation The image orientation.
 @param scale The ratio of the pixel size of image to its intended drawing size.
 */
FOUNDATION_EXPORT void FBLDrawCGImageInCGContext(CGContextRef context, CGImageRef image,
                                                 UIImageOrientation orientation, CGFloat scale);

@interface UIImage (FBLAdditions)

/** Returns an image scaled to size. Similar to FBLImageResizingModeScaleToFill. */
+ (UIImage *)fbl_imageWithImage:(UIImage *)image scaledToSize:(CGSize)size;

/**
 Returns an image scaled to size with respect of the given image resizing mode.
 The resulting image always has the requested size unless the resizing mode is
 FBLImageResizingModeScaleAspectFitCrop.
 */
+ (UIImage *)fbl_imageWithImage:(UIImage *)image
                   scaledToSize:(CGSize)size
                   resizingMode:(FBLImageResizingMode)resizingMode;

/** Returns an image equal to self with UIImageOrientationUp. */
- (UIImage *)fbl_orientedUp;

/** Returns an image rotated by the given degrees. */
- (UIImage *)fbl_rotatedByDegrees:(CGFloat)degrees;

/** Returns an image flipped horizontally. */
- (UIImage *)fbl_flippedHorizontally;

/** Returns an image flipped vertically. */
- (UIImage *)fbl_flippedVertically;

/** Returns an image with a given tint and background color added to the original image. */
+ (UIImage *)fbl_imageWithImage:(UIImage *)image
                      tintColor:(UIColor *)tintColor
                backgroundColor:(UIColor *)backgroundColor;

/** Returns an image filled with color. */
+ (UIImage *)fbl_imageWithColor:(UIColor *)color;

/**
 This method is the same as QTMIcon's blendImageWithColor(UIImage *image, UIColor *color)
 with additional handling for both alpha & white sources. This method will only tint the black
 part of the image, leaving the white & transparent sources intact.
 */
+ (UIImage *)fbl_blendedMaskImage:(UIImage *)image withColor:(UIColor *)color;

/** Calls |UIImage fbl_blendedMaskImage:withColor:| with the UIImage of the given imageName. */
+ (UIImage *)fbl_blendedMaskImageNamed:(NSString *)imageName withColor:(UIColor *)color;

/** Returns a grayscaled version of the image. */
+ (UIImage *)fbl_grayScaledImageFromImage:(UIImage *)image;

/**
 Takes a screenshot of the windows on the main screen. Pass |YES| for waitForUpdates if you're
 making changes to the screen immediately before taking the screenshot and want those changes to
 be reflected in the screenshot.
 */
+ (UIImage *)fbl_screenshotOfMainScreenWaitForUpdates:(BOOL)waitForUpdates;

+ (UIImage *)fbl_imageByRasterizingCIImage:(CIImage *)aCIImage scaledToSize:(CGSize)size;

/**
 Renders the content of the view into an image.
 If opaque is NO, the transparency in the view is preserved.
 If afterScreenUpdates is YES, draw after the screen updates.
 */
+ (UIImage *)fbl_imageFromView:(UIView *)view
                        opaque:(BOOL)opaque
            afterScreenUpdates:(BOOL)afterScreenUpdates;

/** Crops the image using given rect. */
- (UIImage *)fbl_cropToRect:(CGRect)rect;

/** Rounds the corners of the image and returns the new image. */
- (UIImage *)fbl_roundCornersWithRadius:(const CGFloat)radius;

@end

NS_ASSUME_NONNULL_END
