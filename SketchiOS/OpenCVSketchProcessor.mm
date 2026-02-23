#import "OpenCVSketchProcessor.h"

#import <opencv2/opencv.hpp>

using namespace cv;

namespace {

static UIImage *normalizedImage(UIImage *image) {
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }

    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized ?: image;
}

static Mat cvMatFromUIImage(UIImage *image) {
    UIImage *fixedImage = normalizedImage(image);
    CGImageRef cgImage = fixedImage.CGImage;
    if (cgImage == nil) {
        return Mat();
    }

    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    Mat mat((int)height, (int)width, CV_8UC4);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(mat.data,
                                                 width,
                                                 height,
                                                 8,
                                                 mat.step[0],
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(colorSpace);

    if (context == nil) {
        return Mat();
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);
    return mat;
}

static UIImage *UIImageFromGrayMat(const Mat &mat) {
    if (mat.empty() || mat.type() != CV_8UC1) {
        return nil;
    }

    NSData *data = [NSData dataWithBytes:mat.data length:mat.elemSize() * mat.total()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();

    CGImageRef cgImage = CGImageCreate(mat.cols,
                                       mat.rows,
                                       8,
                                       8,
                                       mat.step[0],
                                       colorSpace,
                                       kCGImageAlphaNone,
                                       provider,
                                       NULL,
                                       false,
                                       kCGRenderingIntentDefault);

    UIImage *image = cgImage ? [UIImage imageWithCGImage:cgImage] : nil;

    if (cgImage) {
        CGImageRelease(cgImage);
    }
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);

    return image;
}

static UIImage *UIImageFromBGRMat(const Mat &mat) {
    if (mat.empty()) {
        return nil;
    }

    Mat rgba;
    cvtColor(mat, rgba, COLOR_BGR2RGBA);

    NSData *data = [NSData dataWithBytes:rgba.data length:rgba.elemSize() * rgba.total()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGImageRef cgImage = CGImageCreate(rgba.cols,
                                       rgba.rows,
                                       8,
                                       32,
                                       rgba.step[0],
                                       colorSpace,
                                       kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault,
                                       provider,
                                       NULL,
                                       false,
                                       kCGRenderingIntentDefault);

    UIImage *image = cgImage ? [UIImage imageWithCGImage:cgImage] : nil;

    if (cgImage) {
        CGImageRelease(cgImage);
    }
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);

    return image;
}

static int normalizedKernel(NSInteger kernel) {
    int value = (int)MAX(3, kernel);
    if (value % 2 == 0) {
        value += 1;
    }
    return value;
}

static Mat pencilSketchGray(const Mat &rgbaInput, NSInteger blurKernel, double sigma) {
    Mat gray;
    cvtColor(rgbaInput, gray, COLOR_RGBA2GRAY);

    Mat inverseGray;
    bitwise_not(gray, inverseGray);

    int kernel = normalizedKernel(blurKernel);
    Mat blur;
    GaussianBlur(inverseGray, blur, cv::Size(kernel, kernel), sigma, sigma);

    Mat denominator;
    subtract(Scalar::all(255), blur, denominator);
    cv::max(denominator, 1, denominator);

    Mat sketch;
    divide(gray, denominator, sketch, 255.0);
    return sketch;
}

} // namespace

@implementation OpenCVSketchProcessor

+ (UIImage *)pencilSketchFromImage:(UIImage *)image blurKernel:(NSInteger)blurKernel sigma:(double)sigma {
    Mat rgba = cvMatFromUIImage(image);
    if (rgba.empty()) {
        return nil;
    }

    Mat sketch = pencilSketchGray(rgba, blurKernel, sigma);
    return UIImageFromGrayMat(sketch);
}

+ (UIImage *)colorPencilSketchFromImage:(UIImage *)image
                             blurKernel:(NSInteger)blurKernel
                                  sigma:(double)sigma
                          colorStrength:(double)colorStrength {
    Mat rgba = cvMatFromUIImage(image);
    if (rgba.empty()) {
        return nil;
    }

    Mat sketchGray = pencilSketchGray(rgba, blurKernel, sigma);

    Mat srcBGR;
    cvtColor(rgba, srcBGR, COLOR_RGBA2BGR);

    Mat sketchBGR;
    cvtColor(sketchGray, sketchBGR, COLOR_GRAY2BGR);

    Mat multiplied;
    multiply(srcBGR, sketchBGR, multiplied, 1.0 / 255.0);

    double alpha = std::min(1.0, std::max(0.0, colorStrength));
    Mat blended;
    addWeighted(multiplied, alpha, srcBGR, 1.0 - alpha, 0.0, blended);

    return UIImageFromBGRMat(blended);
}

@end
