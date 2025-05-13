//
//  CameraView.swift
//  TakeAgain
//
//  Created by 고재현 on 5/8/25.
//

import SwiftUI
import AVFoundation
import Photos

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var dragTranslation: CGSize = .zero
    @State private var didTriggerHaptic = false
    @State private var dragPulseTick: Int = 0
    @State private var dragReturn: CGFloat = 0
    @State private var isDragging = false
    @State private var recentImage: UIImage?
    @State private var showDeleteWarning = false
    @AppStorage("hasSeenDeleteWarning") private var hasSeenDeleteWarning: Bool = false
    @State private var selectedZoom: CGFloat = 1.0
    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var focusPoint: CGPoint? = nil
    @State private var focusScale: CGFloat = 1.5
    // Step 1: Add new state properties for focus animation
    @State private var focusOpacity: Double = 1.0
    @State private var showBlink: Bool = false
    // Exposure UI state
    @State private var showExposureUI: Bool = false
    @State private var exposureValue: Float = 0.0
    // Track tap-to-focus state for exposure drag
    @State private var didFocusTap: Bool = false

    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session, cameraManager: cameraManager)
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            guard cameraManager.currentCameraPosition == .back else { return }
                            let newZoom = currentZoomFactor * value
                            let clamped = min(max(newZoom, 0.5), 6.0)
                            cameraManager.setZoomFactor(clamped)
                        }
                        .onEnded { value in
                            guard cameraManager.currentCameraPosition == .back else { return }
                            currentZoomFactor = min(max(currentZoomFactor * value, 0.5), 6.0)
                        }
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard didFocusTap else { return }
                            let delta = Float(-value.translation.height / 100)
                            let newValue = max(min(exposureValue + delta, 2.0), -2.0)
                            exposureValue = newValue
                            cameraManager.setExposure(value: newValue)
                            showExposureUI = true
                        }
                        .onEnded { value in
                            let location = value.location
                            focusPoint = location
                            showExposureUI = true
                            exposureValue = 0.0
                            didFocusTap = true

                            DispatchQueue.main.async {
                                focusScale = 1.5
                                focusOpacity = 1.0
                                showBlink = false

                                cameraManager.focus(at: location)

                                withAnimation(.easeOut(duration: 0.25)) {
                                    focusScale = 1.0
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showBlink = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            showBlink = false
                                        }
                                    }
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation(.easeOut(duration: 1.0)) {
                                        focusOpacity = 0.5
                                    }
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                                    focusPoint = nil
                                    focusOpacity = 1.0
                                    didFocusTap = false
                                }
                            }
                        }
                )

            // Step 3: Enhanced focus rectangle view
            if let point = focusPoint {
                Rectangle()
                    .stroke(Color.yellow, lineWidth: showBlink ? 2 : 1)
                    .frame(width: 80, height: 80)
                    .scaleEffect(focusScale)
                    .opacity(focusOpacity)
                    .position(point)
            }

            // Exposure UI
            /*
            if showExposureUI, let point = focusPoint {
                ExposureControlView(
                    exposureValue: $exposureValue,
                    onExposureChanged: { value in
                        cameraManager.setExposure(value: value)
                    },
                    position: CGPoint(x: point.x + 60, y: point.y)
                )
            }
            */

            // Top overlay: Native-style recording timer bar
            VStack(spacing: 0) {
                if isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                        Text(String(format: "%02d:%02d:%02d", Int(recordingTime) / 3600, Int(recordingTime) / 60 % 60, Int(recordingTime) % 60))
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.top, 30)
                }
                Spacer()
            }

            // Middle: zoom selector and bottom bar
            VStack {
                Spacer()

                // Zoom selector and semicircular dial for rear camera (always show for rear)
                if cameraManager.currentCameraPosition == .back {
                    ZoomPicker(cameraManager: cameraManager, availableZooms: cameraManager.availableZoomFactors, selectedZoom: $selectedZoom) { newZoom in
                        currentZoomFactor = newZoom
                        cameraManager.setZoomFactor(newZoom)
                    }
                }

                // Bottom bar
                HStack {
                if !isRecording {
                    if let image = recentImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Rectangle())
                            .cornerRadius(6)
                            .onTapGesture {
                                if let url = URL(string: "photos-redirect://") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    } else {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 50, height: 50)
                            .cornerRadius(6)
                            .onTapGesture {
                                if let url = URL(string: "photos-redirect://") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                }

                Spacer()

                ZStack {
                    Capsule()
                        .fill(Color.red)
                        .frame(width: isRecording ? 145 : 80, height: 80)
                        .overlay(
                            Group {
                                if isRecording {
                                    ZStack {
                                        // Checkmark on left side, visually centered
                                        HStack {
                                            Button(action: {
                                                cameraManager.stopRecording()
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    PhotoLibraryService.saveVideo(from: cameraManager.outputURL) {
                                                        fetchLatestPhotoThumbnail()
                                                    }
                                                }
                                                recordingTime = 0
                                                isRecording = false
                                            }) {
                                                Image(systemName: "checkmark")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 28, height: 28)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.leading, 20)

                                            Spacer()
                                        }

                                        // Retake on right edge with drag gesture
                                        HStack {
                                            Spacer()
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(dragTranslation.width <= -55 ? 1.0 : (isDragging ? 0.8 : 1.0)))
                                                    .frame(width: isDragging ? 65 : 64, height: isDragging ? 65 : 64)
                                                Image(systemName: "arrow.counterclockwise")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 28, height: 28)
                                                    .foregroundColor(.gray)
                                            }
                                            .offset(x: dragTranslation.width + dragReturn)
                                            .animation(.easeOut(duration: 0.2), value: isDragging)
                                            .simultaneousGesture(
                                                TapGesture()
                                                    .onEnded {
                                                        if !hasSeenDeleteWarning {
                                                            showDeleteWarning = true
                                                        } else {
                                                            cameraManager.stopRecording()
                                                            recordingTime = 0
                                                            isRecording = false
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                PhotoLibraryService.deleteAndSaveToRecentlyDeleted(from: cameraManager.outputURL) {
                                                                    fetchLatestPhotoThumbnail()
                                                                }
                                                            }
                                                        }
                                                    }
                                            )
                                            .gesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { value in
                                                        if !isDragging {
                                                            let press = UIImpactFeedbackGenerator(style: .light)
                                                            press.impactOccurred()
                                                            isDragging = true
                                                        }

                                                        let clampedX = max(min(value.translation.width, 0), -66)
                                                        dragTranslation = CGSize(width: clampedX, height: 0)

                                                        let tick = Int(abs(clampedX) / 10)
                                                        if tick != dragPulseTick {
                                                            let feedback = UIImpactFeedbackGenerator(style: .light)
                                                            feedback.impactOccurred()
                                                            dragPulseTick = tick
                                                        }

                                                        if clampedX <= -55 && !didTriggerHaptic {
                                                            let impact = UIImpactFeedbackGenerator(style: .medium)
                                                            impact.impactOccurred()
                                                            didTriggerHaptic = true
                                                        }
                                                        if clampedX <= -55 {
                                                            isDragging = true
                                                        } else {
                                                            isDragging = true
                                                        }
                                                    }
                                                    .onEnded { value in
                                                        isDragging = false
                                                        if value.translation.width <= -60 {
                                                            cameraManager.stopRecording()
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                PhotoLibraryService.saveVideo(from: cameraManager.outputURL) {
                                                                    fetchLatestPhotoThumbnail()
                                                                }
                                                            }
                                                            recordingTime = 0
                                                            isRecording = false
                                                        } else {
                                                            withAnimation(.spring()) {
                                                                dragReturn = 0
                                                                dragTranslation = .zero
                                                            }
                                                        }
                                                        didTriggerHaptic = false
                                                        dragPulseTick = 0
                                                    }
                                            )
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .padding(.trailing, 7)
                                        }
                                    }
                                    .frame(width: 145, height: 80)
                                } else {
                                    Button(action: {
                                        cameraManager.startRecording()
                                        recordingTime = 0
                                        isRecording = true
                                        dragTranslation = .zero
                                        dragReturn = 0
                                    }) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 70, height: 70)
                                    }
                                }
                            }
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 4)
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isRecording)
                }

                Spacer()

                if !isRecording {
                    Button(action: {
                        cameraManager.switchCamera()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 50, height: 50)
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
    }
    .onAppear {
        cameraManager.configure()
        cameraManager.onRecordingFinished = { url in
            isRecording = false
        }
        fetchLatestPhotoThumbnail()
        selectedZoom = 1.0
        currentZoomFactor = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let first = cameraManager.availableZoomFactors.first {
                selectedZoom = first
                currentZoomFactor = first
                cameraManager.setZoomFactor(first)
            }
        }
    }
    .onReceive(timer) { _ in
        if isRecording {
            recordingTime += 1
        }
    }
    .navigationBarBackButtonHidden(true)
    .alert(isPresented: $showDeleteWarning) {
        Alert(
            title: Text("자동 삭제 안내"),
            message: Text("이 항목은 자동 삭제돼요.\n삭제된 항목에서 복구할 수 있어요."),
            dismissButton: .default(Text("확인")) {
                hasSeenDeleteWarning = true
                cameraManager.stopRecording()
                recordingTime = 0
                isRecording = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    PhotoLibraryService.deleteAndSaveToRecentlyDeleted(from: cameraManager.outputURL) {
                        fetchLatestPhotoThumbnail()
                    }
                }
            }
        )
    }
}

func fetchLatestPhotoThumbnail() {
    PhotoLibraryService.fetchLatestThumbnail { image in
        self.recentImage = image
    }
}
}

final class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    private let movieOutput = AVCaptureMovieFileOutput()
    var outputURL: URL?
    var onRecordingFinished: ((URL) -> Void)?
    @Published var availableZoomFactors: [CGFloat] = [1.0, 2.0]
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back

    func configure() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.beginConfiguration()
            
            // Discover appropriate device
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInUltraWideCamera,
                    .builtInWideAngleCamera,
                    .builtInTelephotoCamera,
                    .builtInDualCamera,
                    .builtInTripleCamera
                ],
                mediaType: .video,
                position: self.currentCameraPosition
            )
            
            guard let videoDevice = discoverySession.devices.first,
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoInput) else {
                print("카메라 설정 실패")
                return
            }

            self.session.addInput(videoInput)
            
            // Use device model to determine zoom factors
            if videoDevice.position == .back {
                // Print the device model before setting zoom factors
                print("📱 현재 기기 모델:", UIDevice.current.modelName)
                self.availableZoomFactors = self.zoomFactorsForDeviceModel()
            }

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    // Helper to return predefined zoom factors per device model
    func zoomFactorsForDeviceModel() -> [CGFloat] {
        let model = UIDevice.current.modelName

        switch model {
        case "iPhone 16 Pro", "iPhone 16 Pro Max",
             "iPhone 15 Pro", "iPhone 15 Pro Max",
             "iPhone 14 Pro", "iPhone 13 Pro":
            return [1.0, 3.0, 6.0]

        case "iPhone 16", "iPhone 16 Plus",
             "iPhone 15", "iPhone 15 Plus",
             "iPhone 14", "iPhone 13", "iPhone 12":
            return [1.0, 2.0, 5.0]

        case "iPhone SE":
            return [1.0, 2.0]

        default:
            return [1.0, 2.0]
        }
    }

    func switchCamera() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        currentCameraPosition = currentCameraPosition == .back ? .front : .back

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        session.commitConfiguration()
    }

    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        outputURL = fileURL
        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
    }

    func stopRecording() {
        movieOutput.stopRecording()
    }

    func setZoomFactor(_ factor: CGFloat) {
        guard let device = session.inputs
            .compactMap({ $0 as? AVCaptureDeviceInput })
            .first?.device, device.position == .back else { return }

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.unlockForConfiguration()
        } catch {
            print("Zoom 설정 실패: \(error.localizedDescription)")
        }
    }
    func focus(at point: CGPoint) {
        guard let previewLayer = self.previewLayer else {
            print("❌ Preview layer 없음")
            return
        }

        guard let device = session.inputs
            .compactMap({ $0 as? AVCaptureDeviceInput })
            .first?.device, device.isFocusPointOfInterestSupported else {
            print("⚠️ 포커스 지원 안됨")
            return
        }

        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)

        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
            print("🎯 포커스 위치:", focusPoint)
        } catch {
            print("포커스 설정 실패:", error.localizedDescription)
        }
    }
    func setExposure(value: Float) {
        guard let device = session.inputs
            .compactMap({ $0 as? AVCaptureDeviceInput })
            .first?.device else {
            print("노출 조절: device 없음")
            return
        }

        do {
            try device.lockForConfiguration()

            if device.isExposureModeSupported(.custom) {
                print("노출 모드: .custom 사용")
                device.setExposureTargetBias(value) { _ in }
            } else if device.isExposureModeSupported(.continuousAutoExposure) {
                print("노출 모드: fallback to .continuousAutoExposure")
                device.exposureMode = .continuousAutoExposure
                let clamped = max(min(value, device.maxExposureTargetBias), device.minExposureTargetBias)
                device.setExposureTargetBias(clamped) { _ in }
            } else {
                print("노출 조절 지원 안 함")
            }

            device.unlockForConfiguration()
        } catch {
            print("노출 설정 실패: \(error)")
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("녹화 종료: \(outputFileURL)")
        DispatchQueue.main.async {
            let asset = AVAsset(url: outputFileURL)
            if asset.isPlayable {
                self.onRecordingFinished?(outputFileURL)
            } else {
                print("녹화된 파일이 재생 불가능한 상태입니다.")
            }
        }
    }
    
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let cameraManager: CameraManager

func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = UIScreen.main.bounds
    cameraManager.previewLayer = previewLayer
    view.layer.addSublayer(previewLayer)
    return view
}

func updateUIView(_ uiView: UIView, context: Context) {}
}


#Preview {
    CameraView()
}




// MARK: - Horizontal Native-style Zoom Picker
struct ZoomPicker: View {
    var cameraManager: CameraManager
    var availableZooms: [CGFloat]
    @Binding var selectedZoom: CGFloat
    var onZoomChange: (CGFloat) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(availableZooms, id: \.self) { zoom in
                ZStack {
                    let displayText: String = {
                        if abs(selectedZoom - zoom) < 0.05 {
                            return zoom == floor(zoom) ? String(format: "%.0fx", zoom) : String(format: "%.1fx", zoom)
                        } else {
                            // Unselected: show .5 for 0.5, 1 for 1.0, etc.
                            if zoom == floor(zoom) {
                                return String(format: "%.0f", zoom)
                            } else {
                                return String(format: ".%d", Int((zoom * 10).truncatingRemainder(dividingBy: 10)))
                            }
                        }
                    }()
                    Text(displayText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(abs(selectedZoom - zoom) < 0.05 ? .yellow : .white)
                        .frame(width: abs(selectedZoom - zoom) < 0.05 ? 40 : 26, height: abs(selectedZoom - zoom) < 0.05 ? 40 : 26)
                        .background(
                            Circle()
                                .fill(abs(selectedZoom - zoom) < 0.05 ? Color.black : Color.black.opacity(0.5))
                        )
                }
                .frame(width: 40, height: 40)
                .animation(.easeInOut(duration: 0.2), value: selectedZoom)
                .onTapGesture {
                    withAnimation(.easeInOut) {
                        selectedZoom = zoom
                        onZoomChange(zoom)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
        )
        .offset(y: -12)
    }
}




// MARK: - UIDevice extension for model name
import UIKit

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }

        return mapToDevice(identifier: identifier)
    }

    private func mapToDevice(identifier: String) -> String {
        switch identifier {
        case "iPhone17,1": return "iPhone 16 Pro Max"
        case "iPhone17,2": return "iPhone 16 Pro"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"

        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone16,3": return "iPhone 15"
        case "iPhone16,4": return "iPhone 15 Plus"

        case "iPhone15,2", "iPhone15,3": return "iPhone 14 Pro"
        case "iPhone15,4", "iPhone15,5": return "iPhone 14"

        case "iPhone14,2", "iPhone14,3": return "iPhone 13 Pro"
        case "iPhone14,4", "iPhone14,5": return "iPhone 13"

        case "iPhone13,2": return "iPhone 12"
        case "iPhone12,8": return "iPhone SE"
        default: return identifier
        }
    }
}



