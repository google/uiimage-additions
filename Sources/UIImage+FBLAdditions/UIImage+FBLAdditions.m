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

#import "UIImage+FBLAdditions.h"

#import <CoreImage/CoreImage.h>
#import <UIKit/UIBezierPath.h>
#import <UIKit/UIGraphics.h>
#import <UIKit/UIGraphicsImageRenderer.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIWindow.h>

static BOOL const FBLImageContextIsTransparent = NO;
// We'll use scale factor of the device's main screen for all drawings unless other is specified.
static CGFloat const FBLImageContextScaleDefault = 0.0;

static CGImageRef __nullable FBLCreateCGImageWithContextAndDrawings(
    CGContextRef context, void (^drawings)(CGContextRef context)) {
  if (!context) {
    return nil;
  }
  CGContextSetShouldAntialias(context, true);
  CGContextSetInterpolationQuality(context, kCGInterpolationHigh);

  drawings(context);

  CGImageRef resultImage = CGBitmapContextCreateImage(context);
  return resultImage;
}

static CGImageRef __nullable FBLCreateCGImageWithDrawings(CGSize size,
                                                          void (^drawings)(CGContextRef context)) {
  size = FBLSizeIntegral(size);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  CGContextRef context =
      CGBitmapContextCreate(NULL, size.width, size.height, 8, (size_t)size.width * 4, colorSpace,
                            kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
  CGColorSpaceRelease(colorSpace);
  CGImageRef resultImage = FBLCreateCGImageWithContextAndDrawings(context, drawings);
  CGContextRelease(context);
  return resultImage;
}

/**
 Makes an integral rect which is imageSize resized to targetSize with respect of the aspect ratio.
 Returns CGRectNull if either size is invalid.
 */
static CGRect FBLProjectedRectForResizedImage(CGSize imageSize, CGSize targetSize,
                                              BOOL keepAspectRatio, BOOL aspectFill) {
  if (!FBLSizeIsValid(imageSize) || !FBLSizeIsValid(targetSize)) {
    return CGRectNull;
  }
  if (CGSizeEqualToSize(imageSize, targetSize)) {
    CGRect integralRect = {.origin = CGPointZero, .size = FBLSizeIntegral(imageSize)};
    return integralRect;
  }
  CGFloat aspectRatio = imageSize.width / imageSize.height;
  CGFloat targetAspectRatio = targetSize.width / targetSize.height;
  CGRect projectedRect = CGRectZero;
  if (keepAspectRatio) {
    if (aspectFill) {
      // Scale and clip image so that the aspect ratio is preserved and the target size is filled.
      if (targetAspectRatio < aspectRatio) {
        // Clip the x-axis.
        projectedRect.size.width = targetSize.height * aspectRatio;
        projectedRect.size.height = targetSize.height;
        projectedRect.origin.x = (targetSize.width - projectedRect.size.width) / 2.0;
        projectedRect.origin.y = 0.0;
      } else {
        // Clip the y-axis.
        projectedRect.size.width = targetSize.width;
        projectedRect.size.height = targetSize.width / aspectRatio;
        projectedRect.origin.x = 0.0;
        projectedRect.origin.y = (targetSize.height - projectedRect.size.height) / 2.0;
      }
    } else {
      // Scale image to ensure it fits inside the specified targetSize.
      if (targetAspectRatio < aspectRatio) {
        // Target is less wide than the original.
        projectedRect.size.width = targetSize.width;
        projectedRect.size.height = projectedRect.size.width / aspectRatio;
      } else {
        // Target is wider than the original.
        projectedRect.size.height = targetSize.height;
        projectedRect.size.width = projectedRect.size.height * aspectRatio;
      }
    }  // if (aspectFill)
  } else {
    // Don't preserve the aspect ratio.
    projectedRect.size = targetSize;
  }

  return CGRectIntegral(projectedRect);
}

static void FBLMirrorCGContextHorizontally(CGContextRef context, CGSize size) {
  CGContextTranslateCTM(context, size.width, 0.0);
  CGContextScaleCTM(context, -1.0, 1.0);
}

static void FBLMirrorCGContextVertically(CGContextRef context, CGSize size) {
  CGContextTranslateCTM(context, 0.0, size.height);
  CGContextScaleCTM(context, 1.0, -1.0);
}

/**
 FBLRotateCGContext applies a transform to context that rotates the rectangle { CGPointZero, size }
 by angle radians and translates that rotated rectangle such that its minimum x and y coordinates
 are both zero.

 @param context The context to be rotated.
 @param angle The angle, in radians, to rotate in the counter-clockwise direction.
 @param size The size of the rectangle to rotate.
 */
static void FBLRotateCGContext(CGContextRef context, CGFloat angle, CGSize size) {
  CGRect const originalBounds = {CGPointZero, size};
  CGAffineTransform const rotationTransform = CGAffineTransformMakeRotation(angle);
  CGRect const rotatedBounds = CGRectApplyAffineTransform(originalBounds, rotationTransform);

  /**
   rotatedBounds is the smallest axis-aligned bounding box that encloses the rotated originalBounds.
   The goal is to center the original bounds, { CGPointZero, size }, in that larger bounding box,
   and rotate it about the center point.

   The translation to center the (not rotated) original rect in the larger bounding box is
   (rotatedBounds.size - size) / 2. If S translates to the center of the rotated bounds and T
   translates to the center of the original bounds, that's S * T^-1. To perform the rotation,
   conjugate a rotation about the origin, R, by the translation, T, that moves the origin to the
   center.

   All together, the sequence comes out S * T^-1 * T * R * T^-1 = S * R * T^-1. And that simplified
   version of the transforms is coded below.
   */
  CGContextTranslateCTM(context, rotatedBounds.size.width / 2, rotatedBounds.size.height / 2);
  CGContextRotateCTM(context, angle);
  CGContextTranslateCTM(context, -size.width / 2, -size.height / 2);
}

void FBLDrawCGImageInCGContext(CGContextRef context, CGImageRef image,
                               UIImageOrientation orientation, CGFloat scale) {
  if (scale == 0.0) {
    return;
  }
  CGFloat const inverseScale = 1 / scale;
  CGSize const size = FBLSizeIntegral(
      CGSizeMake(CGImageGetWidth(image) * inverseScale, CGImageGetHeight(image) * inverseScale));
  if (!FBLSizeIsValid(size)) {
    return;
  }

  CGContextSaveGState(context);
  switch (orientation) {
    case UIImageOrientationUp:
      // Default orientation, do nothing.
      break;
    case UIImageOrientationDown:
      FBLRotateCGContext(context, M_PI, size);
      break;
    case UIImageOrientationLeft:
      FBLRotateCGContext(context, M_PI_2, size);
      break;
    case UIImageOrientationRight:
      FBLRotateCGContext(context, -M_PI_2, size);
      break;
    case UIImageOrientationUpMirrored:
      FBLMirrorCGContextHorizontally(context, size);
      break;
    case UIImageOrientationDownMirrored:
      FBLMirrorCGContextHorizontally(context, size);
      FBLRotateCGContext(context, M_PI, size);
      break;
    case UIImageOrientationLeftMirrored:
      FBLRotateCGContext(context, M_PI_2, size);
      FBLMirrorCGContextHorizontally(context, size);
      break;
    case UIImageOrientationRightMirrored:
      FBLRotateCGContext(context, -M_PI_2, size);
      FBLMirrorCGContextHorizontally(context, size);
      break;
  }
  CGRect const kImageBounds = {.origin = CGPointZero, .size = size};
  CGContextDrawImage(context, kImageBounds, image);
  CGContextRestoreGState(context);
}

@implementation UIImage (FBLAdditions)

+ (UIImage *)fbl_imageWithImage:(UIImage *)image scaledToSize:(CGSize)size {
  return [UIImage fbl_imageWithImage:image
                        scaledToSize:size
                        resizingMode:FBLImageResizingModeScaleToFill];
}

+ (UIImage *)fbl_imageWithImage:(UIImage *)image
                   scaledToSize:(CGSize)size
                   resizingMode:(FBLImageResizingMode)resizingMode {
  if (image == nil || !FBLSizeIsValid(size)) {
    return nil;
  }
  CGRect bounds = {.origin = CGPointZero, .size = size};
  CGSize imageSize = image.size;
  CGRect imageBounds = {.origin = CGPointZero, .size = imageSize};
  BOOL isImageCentered = NO;
  BOOL isImageScaled = NO;
  BOOL keepAspectRatio = NO;
  BOOL aspectFill = NO;
  BOOL isImageCropped = NO;

  switch (resizingMode & FBLImageResizingOptionMask) {
    case FBLImageResizingOptionScaleToFill:
      isImageScaled = YES;
      break;
    case FBLImageResizingOptionScaleAspectFit:
      isImageScaled = YES;
      keepAspectRatio = YES;
      isImageCentered = YES;  // UIViewContentModeScaleAspectFit aligns the content, so do we.
      break;
    case FBLImageResizingOptionScaleAspectFill:
      isImageScaled = YES;
      keepAspectRatio = YES;
      aspectFill = YES;
      break;
    case FBLImageResizingOptionCenter:
      isImageCentered = YES;
      break;
    case FBLImageResizingOptionCenterAspectFill:
      isImageCentered = YES;
      if (CGRectContainsRect(imageBounds, bounds)) {
        isImageScaled = YES;
        keepAspectRatio = YES;
        aspectFill = YES;
      }
      break;
    case FBLImageResizingOptionScaleAspectFitCrop:
      isImageScaled = YES;
      keepAspectRatio = YES;
      isImageCropped = YES;
      break;
  }
  if (isImageScaled) {
    imageBounds = FBLProjectedRectForResizedImage(imageSize, size, keepAspectRatio, aspectFill);
    if (CGRectIsEmpty(imageBounds)) {
      return nil;
    }
  }
  if (isImageCropped) {
    size = imageBounds.size;
  }
  if (isImageCentered) {
    imageBounds = FBLRectCenterAt(imageBounds, FBLRectGetCenter(bounds));
  }
  CGFloat scale = FBLImageContextScaleDefault;
  switch (resizingMode & FBLImageResizingScaleMask) {
    case FBLImageResizingScale1x:
      scale = 1.0;
      break;
  }
  if (scale == FBLImageContextScaleDefault) {
    scale = UIScreen.mainScreen.scale;
  }
  CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scale, scale);
  size = CGSizeApplyAffineTransform(size, scaleTransform);
  imageBounds = CGRectApplyAffineTransform(imageBounds, scaleTransform);

  CGImageRef aCGImage = FBLCreateCGImageWithDrawings(size, ^(CGContextRef context) {
    CGContextDrawImage(context, imageBounds, image.CGImage);
  });
  UIImage *resultImage =
      [UIImage imageWithCGImage:aCGImage scale:scale orientation:image.imageOrientation];
  CGImageRelease(aCGImage);
  return resultImage;
}

- (UIImage *)fbl_orientedUp {
  UIImageOrientation orientation = self.imageOrientation;
  if (orientation == UIImageOrientationUp) {
    return self;
  }
  UIImage *resultImage =
      [UIImage imageWithCGImage:self.CGImage scale:self.scale orientation:UIImageOrientationUp];
  switch (orientation) {
    case UIImageOrientationUpMirrored:
      resultImage = [resultImage fbl_flippedHorizontally];
      // fallthrough
    case UIImageOrientationUp:
      break;
    case UIImageOrientationDownMirrored:
      resultImage = [resultImage fbl_flippedHorizontally];
      // fallthrough
    case UIImageOrientationDown:
      resultImage = [resultImage fbl_rotatedByDegrees:180.0];
      break;
    case UIImageOrientationRightMirrored:
      resultImage = [resultImage fbl_flippedVertically];
      break;
    case UIImageOrientationRight:
      resultImage = [resultImage fbl_rotatedByDegrees:-90.0];
      break;
    case UIImageOrientationLeftMirrored:
      resultImage = [resultImage fbl_flippedVertically];
      break;
    case UIImageOrientationLeft:
      resultImage = [resultImage fbl_rotatedByDegrees:90.0];
      break;
  }
  return resultImage;
}

- (UIImage *)fbl_rotatedByDegrees:(CGFloat)degrees {
  CGSize size = self.size;
  CGRect bounds = {.origin = CGPointZero, .size = size};
  CGFloat radians = degrees * M_PI / 180.0;
  CGRect rotatedBounds = CGRectApplyAffineTransform(bounds, CGAffineTransformMakeRotation(radians));
  CGSize rotatedSize = rotatedBounds.size;

  CGImageRef aCGImage = FBLCreateCGImageWithDrawings(rotatedSize, ^(CGContextRef context) {
    FBLRotateCGContext(context, radians, size);
    CGContextDrawImage(context, bounds, self.CGImage);
  });
  UIImage *resultImage =
      [[UIImage alloc] initWithCGImage:aCGImage scale:self.scale orientation:self.imageOrientation];
  CGImageRelease(aCGImage);
  return resultImage;
}

- (UIImage *)fbl_flippedHorizontally {
  CGSize size = self.size;
  CGRect bounds = {.origin = CGPointZero, .size = size};
  CGImageRef aCGImage = FBLCreateCGImageWithDrawings(size, ^(CGContextRef context) {
    FBLMirrorCGContextHorizontally(context, size);
    CGContextDrawImage(context, bounds, self.CGImage);
  });
  UIImage *resultImage =
      [[UIImage alloc] initWithCGImage:aCGImage scale:self.scale orientation:self.imageOrientation];
  CGImageRelease(aCGImage);
  return resultImage;
}

- (UIImage *)fbl_flippedVertically {
  CGSize size = self.size;
  CGRect bounds = {.origin = CGPointZero, .size = size};
  CGImageRef aCGImage = FBLCreateCGImageWithDrawings(size, ^(CGContextRef context) {
    FBLMirrorCGContextVertically(context, size);
    CGContextDrawImage(context, bounds, self.CGImage);
  });
  UIImage *resultImage =
      [[UIImage alloc] initWithCGImage:aCGImage scale:self.scale orientation:self.imageOrientation];
  CGImageRelease(aCGImage);
  return resultImage;
}

+ (UIImage *)fbl_imageWithImage:(UIImage *)image
                      tintColor:(UIColor *)tintColor
                backgroundColor:(UIColor *)backgroundColor {
  CGFloat scale = UIScreen.mainScreen.scale;
  CGSize size = CGSizeApplyAffineTransform(image.size, CGAffineTransformMakeScale(scale, scale));
  CGRect bounds = {.origin = CGPointZero, .size = size};

  if (image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  }
  CGImageRef aCGImage = FBLCreateCGImageWithDrawings(size, ^(CGContextRef context) {
    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    CGContextFillRect(context, bounds);
    CGContextSetFillColorWithColor(context, tintColor.CGColor);
    CGContextDrawImage(context, bounds, image.CGImage);
  });
  UIImage *resultImage =
      [UIImage imageWithCGImage:aCGImage scale:scale orientation:image.imageOrientation];
  CGImageRelease(aCGImage);
  return resultImage;
}

+ (UIImage *)fbl_imageWithColor:(UIColor *)color {
  CGFloat scale = UIScreen.mainScreen.scale;
  CGSize size =
      CGSizeApplyAffineTransform(CGSizeMake(1.0, 1.0), CGAffineTransformMakeScale(scale, scale));
  CGRect bounds = {.origin = CGPointZero, .size = size};

  CGImageRef aCGImage = FBLCreateCGImageWithDrawings(size, ^(CGContextRef context) {
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, bounds);
  });
  UIImage *resultImage =
      [UIImage imageWithCGImage:aCGImage scale:scale orientation:UIImageOrientationUp];
  CGImageRelease(aCGImage);
  return resultImage;
}

+ (UIImage *)fbl_blendedMaskImage:(UIImage *)image withColor:(UIColor *)color {
  NSParameterAssert(image);

  CGFloat scale = UIScreen.mainScreen.scale;
  CGSize size = CGSizeApplyAffineTransform(image.size, CGAffineTransformMakeScale(scale, scale));
  CGRect bounds = {.origin = CGPointZero, .size = size};

  CGImageRef aCGImage = FBLCreateCGImageWithDrawings(size, ^(CGContextRef context) {
    CGContextDrawImage(context, bounds, image.CGImage);
    CGContextSetBlendMode(context, kCGBlendModeScreen);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, bounds);
    CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
    CGContextSetAlpha(context, 1.0);
    CGContextDrawImage(context, bounds, image.CGImage);
  });
  UIImage *resultImage =
      [UIImage imageWithCGImage:aCGImage scale:scale orientation:image.imageOrientation];
  CGImageRelease(aCGImage);
  if (!UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero)) {
    resultImage = [resultImage resizableImageWithCapInsets:image.capInsets];
  }
  return resultImage;
}

+ (UIImage *)fbl_blendedMaskImageNamed:(NSString *)imageName withColor:(UIColor *)color {
  return [self fbl_blendedMaskImage:[UIImage imageNamed:imageName] withColor:color];
}

+ (UIImage *)fbl_grayScaledImageFromImage:(UIImage *)image {
  CIImage *ciImage = [[CIImage alloc] initWithImage:image];
  CIFilter *grayFiler = [CIFilter filterWithName:@"CIColorControls"];
  [grayFiler setValue:@0 forKey:@"inputSaturation"];
  [grayFiler setValue:ciImage forKey:@"inputImage"];
  CIImage *grayCIImage = grayFiler.outputImage;

  CIContext *context = [CIContext contextWithOptions:nil];
  CGImageRef grayCGImage = [context createCGImage:grayCIImage fromRect:grayCIImage.extent];
  UIImage *resultImage = [UIImage imageWithCGImage:grayCGImage];
  CGImageRelease(grayCGImage);

  return resultImage;
}

+ (UIImage *)fbl_screenshotOfMainScreenWaitForUpdates:(BOOL)waitForUpdates {
  return [self fbl_screenshotOfScreen:[UIScreen mainScreen] waitForUpdates:waitForUpdates];
}

+ (UIImage *)fbl_imageByRasterizingCIImage:(CIImage *)aCIImage scaledToSize:(CGSize)size {
  CGSize prescaledImageSize = aCIImage.extent.size;
  if (!FBLSizeIsValid(prescaledImageSize)) {
    return nil;
  }
  CGFloat imageScaleX = size.width / prescaledImageSize.width;
  CGFloat imageScaleY = size.height / prescaledImageSize.height;
  CGAffineTransform scaleImageTransform = CGAffineTransformMakeScale(imageScaleX, imageScaleY);
  CIImage *scaledCIImage = [aCIImage imageByApplyingTransform:scaleImageTransform];
  CIContext *context = [CIContext context];
  CGImageRef aQRCodeCGImage = [context createCGImage:scaledCIImage fromRect:scaledCIImage.extent];
  UIImage *resultImage = [UIImage imageWithCGImage:aQRCodeCGImage];
  CGImageRelease(aQRCodeCGImage);
  return resultImage;
}

+ (UIImage *)fbl_imageFromView:(UIView *)view
                        opaque:(BOOL)opaque
            afterScreenUpdates:(BOOL)afterScreenUpdates {
  CGRect bounds = view.bounds;
  UIGraphicsBeginImageContextWithOptions(bounds.size, opaque, UIScreen.mainScreen.scale);
  [view drawViewHierarchyInRect:bounds afterScreenUpdates:afterScreenUpdates];
  UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return resultImage;
}

- (UIImage *)fbl_cropToRect:(CGRect)rect {
  CGFloat scale = self.scale;
  rect = CGRectApplyAffineTransform(rect, CGAffineTransformMakeScale(scale, scale));
  CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, rect);
  UIImage *resultImage =
      [UIImage imageWithCGImage:imageRef scale:scale orientation:self.imageOrientation];
  CGImageRelease(imageRef);
  return resultImage;
}

- (UIImage *)fbl_roundCornersWithRadius:(const CGFloat)radius {
  CGSize size = self.size;
  CGImageRef aCGImage = FBLCreateCGImageWithDrawings(size, ^(CGContextRef context) {
    CGRect bounds = {.origin = CGPointZero, .size = size};
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:radius];
    CGContextAddPath(context, path.CGPath);
    CGContextClip(context);
    CGContextDrawImage(context, bounds, self.CGImage);
  });
  UIImage *resultImage =
      [[UIImage alloc] initWithCGImage:aCGImage scale:1.0 orientation:self.imageOrientation];
  CGImageRelease(aCGImage);
  return resultImage;
}

#pragma mark - Private

+ (UIImage *)fbl_screenshotOfScreen:(UIScreen *)screen waitForUpdates:(BOOL)waitForUpdates {
  // Make context sized to the screen being captured.
  CGSize imageSize = screen.bounds.size;
  CGFloat scale = screen.scale;
  UIImage *image;
  if (@available(iOS 10.0, *)) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.prefersExtendedRange = YES;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:imageSize format:format];
    image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *__unused _) {
      [self fbl_renderAllWindowForScreen:screen waitForUpdates:waitForUpdates];
    }];
  } else {
    UIGraphicsBeginImageContextWithOptions(imageSize, FBLImageContextIsTransparent, scale);
    [self fbl_renderAllWindowForScreen:screen waitForUpdates:waitForUpdates];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
  }

  UIInterfaceOrientation deviceOrientation = UIApplication.sharedApplication.statusBarOrientation;
  UIImageOrientation imageOrientation = UIImageOrientationUp;
  switch (deviceOrientation) {
    case UIInterfaceOrientationLandscapeLeft:
      imageOrientation = UIImageOrientationRight;
      break;
    case UIInterfaceOrientationLandscapeRight:
      imageOrientation = UIImageOrientationLeft;
      break;
    case UIInterfaceOrientationPortraitUpsideDown:
      imageOrientation = UIImageOrientationDown;
      break;
    case UIInterfaceOrientationPortrait:
    case UIInterfaceOrientationUnknown:
      imageOrientation = UIImageOrientationUp;
      break;
  }
  UIImage *rotatedImage =
      [UIImage imageWithCGImage:image.CGImage scale:scale orientation:imageOrientation];
  return rotatedImage;
}

+ (void)fbl_renderAllWindowForScreen:(UIScreen *)screen waitForUpdates:(BOOL)waitForUpdates {
  // Spin over all windows on screen to render them.
  for (UIWindow *window in UIApplication.sharedApplication.windows) {
    if (window.screen == screen) {
      [window drawViewHierarchyInRect:window.frame afterScreenUpdates:waitForUpdates];
    }
  }
}

@end
