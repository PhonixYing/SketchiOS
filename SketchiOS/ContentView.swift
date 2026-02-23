//
//  ContentView.swift
//  SketchiOS
//
//  Created by LiDonghui on 2026/2/21.
//

import PhotosUI
import SwiftUI

struct ContentView: View {
    var body: some View {
#if os(iOS)
        SketchEditorView()
#else
        VStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 48))
            Text("SketchiOS demo is available on iPhone/iPad.")
                .foregroundStyle(.secondary)
        }
        .padding()
#endif
    }
}

#if os(iOS)
import AVFoundation
import UIKit

private struct SketchEditorView: View {
    @State private var sourceImage: UIImage?
    @State private var outputImage: UIImage?
    @State private var photoItem: PhotosPickerItem?

    @State private var selectedPreset: SketchPreset = .graphiteClassic
    @State private var intensity: Double = SketchPreset.graphiteClassic.defaultIntensity
    @State private var detail: Double = SketchPreset.graphiteClassic.defaultDetail

    @State private var showCamera = false
    @State private var alertMessage: String?
    @State private var renderTask: Task<Void, Never>?

    private let processor = SketchFilterProcessor.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                preview
                presetBar
                parameterPanel
                actionBar
            }
            .padding()
            .navigationTitle("SketchiOS")
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $sourceImage)
        }
        .onChange(of: sourceImage) { _, _ in
            renderCurrentImage()
        }
        .onChange(of: photoItem) { _, item in
            Task {
                await loadPhoto(from: item)
            }
        }
        .onChange(of: selectedPreset) { _, newPreset in
            intensity = newPreset.defaultIntensity
            detail = newPreset.defaultDetail
            renderCurrentImage()
        }
        .onChange(of: intensity) { _, _ in
            renderCurrentImage()
        }
        .onChange(of: detail) { _, _ in
            renderCurrentImage()
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        alertMessage = nil
                    }
                }
            ),
            actions: {
                Button("知道了", role: .cancel) {}
            },
            message: {
                Text(alertMessage ?? "")
            }
        )
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))

            if let image = outputImage ?? sourceImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(8)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("先拍照或从相册选一张自拍")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
    }

    private var presetBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("预设风格")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SketchPreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            VStack(spacing: 4) {
                                Text(preset.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(preset.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minWidth: 92)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        selectedPreset == preset
                                            ? Color.accentColor.opacity(0.18)
                                            : Color(uiColor: .secondarySystemBackground)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedPreset == preset
                                            ? Color.accentColor
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var parameterPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("强度")
                Slider(value: $intensity, in: 0 ... 1)
                Text(intensity.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }

            HStack {
                Text("线稿")
                Slider(value: $detail, in: 0 ... 1)
                Text(detail.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                openCameraIfPossible()
            } label: {
                Label("拍照", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            PhotosPicker(selection: $photoItem, matching: .images, preferredItemEncoding: .automatic) {
                Label("相册", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func renderCurrentImage() {
        renderTask?.cancel()

        guard let sourceImage else {
            outputImage = nil
            return
        }

        let preset = selectedPreset
        let intensity = intensity
        let detail = detail

        renderTask = Task(priority: .userInitiated) {
            let rendered = processor.render(
                image: sourceImage,
                preset: preset,
                intensity: intensity,
                detail: detail
            )

            if Task.isCancelled {
                return
            }

            await MainActor.run {
                outputImage = rendered ?? sourceImage
            }
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data)
            {
                sourceImage = image
            }
        } catch {
            alertMessage = "读取照片失败：\(error.localizedDescription)"
        }
    }

    private func openCameraIfPossible() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            alertMessage = "当前设备不支持相机。"
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        alertMessage = "请在系统设置中允许相机权限。"
                    }
                }
            }
        case .denied, .restricted:
            alertMessage = "请在系统设置中允许相机权限。"
        @unknown default:
            alertMessage = "无法访问相机。"
        }
    }
}

#Preview {
    ContentView()
}
#endif
