#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVSketchProcessor : NSObject

+ (nullable UIImage *)pencilSketchFromImage:(UIImage *)image
                                 blurKernel:(NSInteger)blurKernel
                                      sigma:(double)sigma;

+ (nullable UIImage *)colorPencilSketchFromImage:(UIImage *)image
                                      blurKernel:(NSInteger)blurKernel
                                           sigma:(double)sigma
                                   colorStrength:(double)colorStrength;

@end

NS_ASSUME_NONNULL_END
