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

var body: some View {
    ZStack {
        CameraPreview(session: cameraManager.session)
            .ignoresSafeArea()

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
//                HStack(spacing: 30) {
//                    ForEach(["0.5x", "1x", "2x"], id: \.self) { zoom in
//                        Text(zoom)
//                            .foregroundColor(.white)
//                            .padding(8)
//                            .background(Color.black.opacity(0.3))
//                            .clipShape(Circle())
//                    }
//                }
//                .padding(.bottom, 100)

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
                                .fill(Color.white.opacity(0.3))
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
private let movieOutput = AVCaptureMovieFileOutput()
var outputURL: URL?
var onRecordingFinished: ((URL) -> Void)?
private var currentCameraPosition: AVCaptureDevice.Position = .back

func configure() {
    DispatchQueue.global(qos: .userInitiated).async {
        self.session.beginConfiguration()

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              self.session.canAddInput(videoInput) else {
            print("카메라 설정 실패")
            return
        }

        self.session.addInput(videoInput)

        if self.session.canAddOutput(self.movieOutput) {
            self.session.addOutput(self.movieOutput)
        }

        self.session.commitConfiguration()
        self.session.startRunning()
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

func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = UIScreen.main.bounds
    view.layer.addSublayer(previewLayer)
    return view
}

func updateUIView(_ uiView: UIView, context: Context) {}
}

