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

#import "UIImage+FBLAdditionsTestHelpers.h"

#import <UIKit/UIGraphics.h>

#define FBL_CONCAT(A, B) FBL_CONCAT_(A, B)
#define FBL_CONCAT_(A, B) A##B

typedef void (^__fbl_defer_block__)(void);
static inline void __fbl_defer_run__(__fbl_defer_block__ *block) { (*block)(); }

/**
 Specifies a block to execute on leaving the current scope.
 On an imaginary line 123 this will unwrap to:

 __unused void (^__fbl_defer_123)() __attribute__((cleanup(__fbl_defer_run__)) = ^

 I.e. an unused local var of type block which will invoke __fbl_defer_run__(__fbl_defer_123)
 on leaving the current scope.
 */
#define FBL_DEFER                                        \
  __fbl_defer_block__ FBL_CONCAT(__fbl_defer_, __LINE__) \
      __attribute__((cleanup(__fbl_defer_run__), unused)) = ^

BOOL FBLTestImagesAreIdentical(UIImage *imageA, UIImage *imageB) {
  CGSize const sizeA = imageA.size;
  CGFloat const scaleA = imageA.scale;
  CGSize const sizeB = imageB.size;
  CGFloat const scaleB = imageB.scale;
  CGSize const pixelSizeA = CGSizeMake(sizeA.width * scaleA, sizeA.height * scaleA);
  CGSize const pixelSizeB = CGSizeMake(sizeB.width * scaleB, sizeB.height * scaleB);
  if (!CGSizeEqualToSize(pixelSizeA, pixelSizeB)) {
    return NO;
  }

  CGSize const size = pixelSizeA;  // One common size, don't need to call it "A" or "B" anymore.
  CGRect const imageBounds = {CGPointZero, size};
  size_t const bytesPerRow = sizeof(FBLTestRGBAColor) * size.width;
  size_t const pixelBufferSize = bytesPerRow * size.height;
  CGBitmapInfo const bitmapInfo = kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedLast;
  FBLTestRGBAColor *pixelBufferA = (FBLTestRGBAColor *)calloc(1, pixelBufferSize);
  FBLTestRGBAColor *pixelBufferB = (FBLTestRGBAColor *)calloc(1, pixelBufferSize);
  CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
  FBL_DEFER {
    free(pixelBufferA);
    free(pixelBufferB);
    CGColorSpaceRelease(deviceRGB);
  };
  CGContextRef contextA = CGBitmapContextCreate(pixelBufferA, size.width, size.height, 8,
                                                bytesPerRow, deviceRGB, bitmapInfo);
  FBL_DEFER { CGContextRelease(contextA); };

  UIGraphicsPushContext(contextA);
  [imageA drawInRect:imageBounds];
  UIGraphicsPopContext();

  CGContextRef contextB = CGBitmapContextCreate(pixelBufferB, size.width, size.height, 8,
                                                bytesPerRow, deviceRGB, bitmapInfo);
  FBL_DEFER { CGContextRelease(contextB); };

  UIGraphicsPushContext(contextB);
  [imageB drawInRect:imageBounds];
  UIGraphicsPopContext();

  return (memcmp(pixelBufferA, pixelBufferB, pixelBufferSize) == 0);
}

void FBLTestASCIIArtPrint(FBLTestRGBAColor const *pixelBuffer, size_t width, size_t height) {
  for (size_t y = 0; y < height; ++y) {
    for (size_t x = 0; x < width; ++x) {
      // We expect red, green, and blue to all be the same here, and it's easier to read pixels in
      // the console as just single letters rather than strings like AAA, BBB, etc.
      printf("%c", pixelBuffer[y * width + x].red);
    }
    printf("\n");
  }
}

FBLTestRGBAColor *FBLTestCreateASCIISequencePixelBuffer(size_t width, size_t height) {
  uint8_t const kAlphabetSize = 26;
  size_t const pixelBufferSize = width * height * sizeof(FBLTestRGBAColor);
  FBLTestRGBAColor *pixelBuffer = (FBLTestRGBAColor *)malloc(pixelBufferSize);
  for (size_t pixelIndex = 0; pixelIndex < width * height; ++pixelIndex) {
    uint8_t const letter = 'A' + (pixelIndex % kAlphabetSize);
    pixelBuffer[pixelIndex] = (FBLTestRGBAColor){letter, letter, letter, UINT8_MAX};
  }
  return pixelBuffer;
}
