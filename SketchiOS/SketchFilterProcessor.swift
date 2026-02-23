//
//  SketchFilterProcessor.swift
//  SketchiOS
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

#if os(iOS)
import UIKit

enum SketchStyle {
    case pencil
    case colorPencil
}

enum SketchPreset: String, CaseIterable, Identifiable {
    case graphiteClassic
    case softPencil
    case cleanLine
    case colorPencil
    case vividColor
    case pastelColor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .graphiteClassic:
            "经典铅笔"
        case .softPencil:
            "柔和素描"
        case .cleanLine:
            "线稿描边"
        case .colorPencil:
            "彩铅标准"
        case .vividColor:
            "彩铅高饱和"
        case .pastelColor:
            "粉彩铅笔"
        }
    }

    var subtitle: String {
        switch self {
        case .graphiteClassic:
            "接近商店款"
        case .softPencil:
            "肤色更柔"
        case .cleanLine:
            "轮廓更清晰"
        case .colorPencil:
            "自然彩铅"
        case .vividColor:
            "颜色更浓"
        case .pastelColor:
            "淡彩纸感"
        }
    }

    var style: SketchStyle {
        switch self {
        case .graphiteClassic, .softPencil, .cleanLine:
            return .pencil
        case .colorPencil, .vividColor, .pastelColor:
            return .colorPencil
        }
    }

    var defaultIntensity: Double {
        switch self {
        case .graphiteClassic:
            return 0.82
        case .softPencil:
            return 0.58
        case .cleanLine:
            return 0.74
        case .colorPencil:
            return 0.72
        case .vividColor:
            return 0.88
        case .pastelColor:
            return 0.55
        }
    }

    var defaultDetail: Double {
        switch self {
        case .graphiteClassic:
            return 0.78
        case .softPencil:
            return 0.42
        case .cleanLine:
            return 0.9
        case .colorPencil:
            return 0.66
        case .vividColor:
            return 0.72
        case .pastelColor:
            return 0.48
        }
    }

    var tuning: SketchTuning {
        switch self {
        case .graphiteClassic:
            return SketchTuning(
                lineBoost: 1.06,
                paperWarmth: 0.32,
                grain: 0.02,
                saturationBoost: 0,
                highlightLift: 0.5,
                toneContrast: 1.12,
                colorLineWarmth: 0,
                whiteBoost: 0.52,
                lineOpacity: 0.86,
                hatchAmount: 0.15
            )
        case .softPencil:
            return SketchTuning(
                lineBoost: 0.78,
                paperWarmth: 0.36,
                grain: 0.018,
                saturationBoost: 0,
                highlightLift: 0.56,
                toneContrast: 1.05,
                colorLineWarmth: 0,
                whiteBoost: 0.44,
                lineOpacity: 0.78,
                hatchAmount: 0.1
            )
        case .cleanLine:
            return SketchTuning(
                lineBoost: 1.46,
                paperWarmth: 0.2,
                grain: 0.008,
                saturationBoost: 0,
                highlightLift: 0.44,
                toneContrast: 1.2,
                colorLineWarmth: 0,
                whiteBoost: 0.38,
                lineOpacity: 1,
                hatchAmount: 0.07
            )
        case .colorPencil:
            return SketchTuning(
                lineBoost: 0.94,
                paperWarmth: 0.46,
                grain: 0.016,
                saturationBoost: 0.2,
                highlightLift: 0.46,
                toneContrast: 1.08,
                colorLineWarmth: 0.5,
                whiteBoost: 0.42,
                lineOpacity: 0.82,
                hatchAmount: 0.1
            )
        case .vividColor:
            return SketchTuning(
                lineBoost: 1.06,
                paperWarmth: 0.4,
                grain: 0.02,
                saturationBoost: 0.38,
                highlightLift: 0.42,
                toneContrast: 1.14,
                colorLineWarmth: 0.45,
                whiteBoost: 0.34,
                lineOpacity: 0.84,
                hatchAmount: 0.12
            )
        case .pastelColor:
            return SketchTuning(
                lineBoost: 0.66,
                paperWarmth: 0.58,
                grain: 0.014,
                saturationBoost: 0.1,
                highlightLift: 0.58,
                toneContrast: 1.02,
                colorLineWarmth: 0.72,
                whiteBoost: 0.54,
                lineOpacity: 0.74,
                hatchAmount: 0.08
            )
        }
    }
}

struct SketchTuning {
    let lineBoost: Double
    let paperWarmth: Double
    let grain: Double
    let saturationBoost: Double
    let highlightLift: Double
    let toneContrast: Double
    let colorLineWarmth: Double
    let whiteBoost: Double
    let lineOpacity: Double
    let hatchAmount: Double
}

final class SketchFilterProcessor {
    static let shared = SketchFilterProcessor()

    private let context = CIContext(options: [
        .priorityRequestLow: false,
    ])

    private init() {}

    func render(image: UIImage, preset: SketchPreset, intensity: Double, detail: Double) -> UIImage? {
        guard let source = Self.makeCIImage(from: image) else { return nil }

        let normalizedIntensity = intensity.clamped(to: 0 ... 1)
        let normalizedDetail = detail.clamped(to: 0 ... 1)
        let tuning = preset.tuning

        if let openCVOutput = renderWithOpenCV(
            image: image,
            style: preset.style,
            intensity: normalizedIntensity,
            detail: normalizedDetail
        ) {
            return openCVOutput
        }

        let output: CIImage
        switch preset.style {
        case .pencil:
            output = makePencilSketch(
                from: source,
                intensity: normalizedIntensity,
                detail: normalizedDetail,
                tuning: tuning
            )
        case .colorPencil:
            output = makeColorPencilSketch(
                from: source,
                intensity: normalizedIntensity,
                detail: normalizedDetail,
                tuning: tuning
            )
        }

        let extent = source.extent.integral
        guard let cgImage = context.createCGImage(output.cropped(to: extent), from: extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func renderWithOpenCV(
        image: UIImage,
        style: SketchStyle,
        intensity: Double,
        detail: Double
    ) -> UIImage? {
        let blurKernel = normalizedOddKernel(from: detail)
        let sigma = 18 + intensity * 62

        switch style {
        case .pencil:
            return OpenCVSketchProcessor.pencilSketch(
                from: image,
                blurKernel: blurKernel,
                sigma: sigma
            )
        case .colorPencil:
            let colorStrength = 0.68 + intensity * 0.22
            return OpenCVSketchProcessor.colorPencilSketch(
                from: image,
                blurKernel: blurKernel,
                sigma: sigma,
                colorStrength: colorStrength
            )
        }
    }

    private func normalizedOddKernel(from detail: Double) -> Int {
        let raw = Int((9 + detail * 30).rounded())
        let clamped = min(max(raw, 3), 39)
        return clamped % 2 == 0 ? clamped + 1 : clamped
    }

    private func makePencilSketch(
        from image: CIImage,
        intensity: Double,
        detail: Double,
        tuning: SketchTuning
    ) -> CIImage {
        let gray = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: tuning.toneContrast + intensity * 0.3,
            kCIInputBrightnessKey: 0.02 + tuning.highlightLift * 0.03,
        ])

        let dodgeBase = gray
            .applyingFilter("CIColorInvert")
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: 2.5 + intensity * 8.5,
            ])
            .cropped(to: image.extent)
            .applyingFilter("CIColorDodgeBlendMode", parameters: [
                kCIInputBackgroundImageKey: gray,
            ])
            .cropped(to: image.extent)

        let edges = applyAlpha(
            to: makeEdgeLineArt(from: gray, detail: detail, lineBoost: tuning.lineBoost),
            alpha: tuning.lineOpacity
        )

        let hatch = applyAlpha(
            to: makeHatchTexture(from: gray, detail: detail),
            alpha: tuning.hatchAmount + intensity * 0.08
        )

        let withEdges = edges
            .applyingFilter("CIMultiplyCompositing", parameters: [
                kCIInputBackgroundImageKey: dodgeBase,
            ])
            .cropped(to: image.extent)

        let withHatch = hatch
            .applyingFilter("CIMultiplyCompositing", parameters: [
                kCIInputBackgroundImageKey: withEdges,
            ])
            .cropped(to: image.extent)

        let lifted = liftHighlights(
            in: withHatch,
            gray: gray,
            boost: tuning.whiteBoost + intensity * 0.1
        )

        let paper = makePaperTexture(
            extent: image.extent,
            warmth: tuning.paperWarmth,
            amount: 0.03 + intensity * 0.05
        )

        let withPaper = paper
            .applyingFilter("CISoftLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: lifted,
            ])

        return applyGrain(
            to: withPaper,
            extent: image.extent,
            amount: tuning.grain + intensity * 0.01
        )
    }

    private func makeColorPencilSketch(
        from image: CIImage,
        intensity: Double,
        detail: Double,
        tuning: SketchTuning
    ) -> CIImage {
        let softened = image.applyingFilter("CINoiseReduction", parameters: [
            "inputNoiseLevel": 0.02 + intensity * 0.04,
            "inputSharpness": 0.28,
        ])

        let colorBase = softened
            .applyingFilter("CIColorPosterize", parameters: [
                "inputLevels": 5 + intensity * 3,
            ])
            .applyingFilter("CIVibrance", parameters: [
                "inputAmount": 0.02 + tuning.saturationBoost * 0.6,
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.98 + tuning.saturationBoost + intensity * 0.15,
                kCIInputContrastKey: tuning.toneContrast + detail * 0.14,
                kCIInputBrightnessKey: 0.02 + tuning.highlightLift * 0.04,
            ])

        let gray = softened.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: 1.04,
            kCIInputBrightnessKey: 0,
        ])

        let warmLineArt = tintLine(
            applyAlpha(
                to: makeEdgeLineArt(from: gray, detail: detail, lineBoost: tuning.lineBoost),
                alpha: tuning.lineOpacity
            ),
            warmth: tuning.colorLineWarmth
        )

        let sketched = warmLineArt
            .applyingFilter("CIMultiplyCompositing", parameters: [
                kCIInputBackgroundImageKey: colorBase,
            ])
            .cropped(to: image.extent)

        let hatched = applyAlpha(
            to: tintLine(makeHatchTexture(from: gray, detail: detail), warmth: tuning.colorLineWarmth * 0.85),
            alpha: tuning.hatchAmount
        )
        .applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: sketched,
        ])

        let lifted = liftHighlights(
            in: hatched,
            gray: gray,
            boost: tuning.whiteBoost + intensity * 0.07
        )

        let paper = makePaperTexture(
            extent: image.extent,
            warmth: tuning.paperWarmth,
            amount: 0.025 + intensity * 0.045
        )

        let withPaper = paper
            .applyingFilter("CISoftLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: lifted,
            ])
            .cropped(to: image.extent)

        return applyGrain(
            to: withPaper,
            extent: image.extent,
            amount: tuning.grain + intensity * 0.012
        )
    }

    private func makeEdgeLineArt(from grayImage: CIImage, detail: Double, lineBoost: Double) -> CIImage {
        grayImage
            .applyingFilter("CIEdges", parameters: [
                kCIInputIntensityKey: (1 + detail * 2.2) * lineBoost,
            ])
            .applyingFilter("CIColorInvert")
            .applyingFilter("CIGammaAdjust", parameters: [
                "inputPower": 0.84,
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.34 + detail * 0.62,
                kCIInputBrightnessKey: 0.016,
            ])
            .cropped(to: grayImage.extent)
    }

    private func makeHatchTexture(from grayImage: CIImage, detail: Double) -> CIImage {
        let extent = grayImage.extent
        let center = CIVector(x: extent.midX, y: extent.midY)

        let hatchA = grayImage
            .applyingFilter("CIHatchedScreen", parameters: [
                "inputCenter": center,
                "inputAngle": Double.pi / 6,
                "inputWidth": 3.2 - detail * 1.2,
                "inputSharpness": 0.9,
            ])

        let hatchB = grayImage
            .applyingFilter("CIHatchedScreen", parameters: [
                "inputCenter": center,
                "inputAngle": -Double.pi / 3,
                "inputWidth": 4.2 - detail * 1.1,
                "inputSharpness": 0.82,
            ])

        return hatchA
            .applyingFilter("CIMultiplyCompositing", parameters: [
                kCIInputBackgroundImageKey: hatchB,
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.32,
                kCIInputBrightnessKey: 0.15,
            ])
            .cropped(to: extent)
    }

    private func liftHighlights(in image: CIImage, gray: CIImage, boost: Double) -> CIImage {
        let extent = image.extent

        let mask = gray
            .applyingFilter("CIGammaAdjust", parameters: [
                "inputPower": (0.86 - boost * 0.22).clamped(to: 0.5 ... 0.95),
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.8 + boost * 0.7,
                kCIInputBrightnessKey: -0.18 + boost * 0.16,
            ])
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: 1.1,
            ])
            .cropped(to: extent)

        let white = CIImage(color: .white).cropped(to: extent)

        return white
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: image,
                kCIInputMaskImageKey: mask,
            ])
            .cropped(to: extent)
    }

    private func tintLine(_ line: CIImage, warmth: Double) -> CIImage {
        let green = 0.955 - warmth * 0.07
        let blue = 0.9 - warmth * 0.16

        return line
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: green, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: blue, w: 0),
                "inputBiasVector": CIVector(
                    x: warmth * 0.012,
                    y: warmth * 0.008,
                    z: warmth * 0.004,
                    w: 0
                ),
            ])
            .cropped(to: line.extent)
    }

    private func applyAlpha(to image: CIImage, alpha: Double) -> CIImage {
        image
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha.clamped(to: 0 ... 1)),
            ])
            .cropped(to: image.extent)
    }

    private func makePaperTexture(extent: CGRect, warmth: Double, amount: Double) -> CIImage {
        let base = CIFilter.randomGenerator()
            .outputImage?
            .cropped(to: extent)
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: 1,
            ])
            .cropped(to: extent)

        let fiberA = base?
            .applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: 18,
                kCIInputAngleKey: 0,
            ])
            .cropped(to: extent)

        let fiberB = base?
            .applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: 12,
                kCIInputAngleKey: Double.pi / 3,
            ])
            .cropped(to: extent)

        let mixed = (fiberA ?? base ?? CIImage(color: .white).cropped(to: extent))
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: fiberB ?? CIImage(color: .white).cropped(to: extent),
            ])
            .cropped(to: extent)

        return mixed
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 0.2,
                kCIInputBrightnessKey: 0.92,
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0.994, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.972, w: 0),
                "inputBiasVector": CIVector(
                    x: 0.003 + warmth * 0.014,
                    y: 0.003 + warmth * 0.01,
                    z: 0.002 + warmth * 0.008,
                    w: 0
                ),
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: amount,
                kCIInputContrastKey: 1,
            ])
            .cropped(to: extent)
    }

    private func applyGrain(to image: CIImage, extent: CGRect, amount: Double) -> CIImage {
        let grain = CIFilter.randomGenerator()
            .outputImage?
            .cropped(to: extent)
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: 0.55,
            ])
            .cropped(to: extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.24,
                kCIInputBrightnessKey: -0.5,
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: amount.clamped(to: 0 ... 0.05)),
            ])

        return (grain ?? image)
            .applyingFilter("CISoftLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: image,
            ])
            .cropped(to: extent)
    }

    private static func makeCIImage(from image: UIImage) -> CIImage? {
        if let cgImage = image.cgImage {
            return CIImage(cgImage: cgImage)
                .oriented(forExifOrientation: image.imageOrientation.exifOrientation)
        }

        if let ciImage = image.ciImage {
            return ciImage
        }

        return CIImage(image: image)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension UIImage.Orientation {
    var exifOrientation: Int32 {
        switch self {
        case .up:
            return 1
        case .down:
            return 3
        case .left:
            return 8
        case .right:
            return 6
        case .upMirrored:
            return 2
        case .downMirrored:
            return 4
        case .leftMirrored:
            return 5
        case .rightMirrored:
            return 7
        @unknown default:
            return 1
        }
    }
}
#endif
