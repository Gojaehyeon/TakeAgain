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

    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()

            // Top overlay: Only timer centered
            VStack {
                HStack {
                    Spacer()
                    Text(String(format: "%02d:%02d:%02d", Int(recordingTime) / 3600, Int(recordingTime) / 60 % 60, Int(recordingTime) % 60))
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                Spacer()
            }

            // Middle: zoom selector and bottom bar
            VStack {
                Spacer()
                HStack(spacing: 30) {
                    ForEach(["0.5x", "1x", "2x"], id: \.self) { zoom in
                        Text(zoom)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 100)

                // Bottom bar
                HStack {
                    Image(systemName: "photo")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .clipShape(Rectangle())
                        .cornerRadius(6)

                    Spacer()

                    Button(action: {
                        if isRecording {
                            cameraManager.stopRecording()
                        } else {
                            cameraManager.startRecording()
                            recordingTime = 0
                            isRecording = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)

                            Group {
                                if isRecording {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.red)
                                        .frame(width: 40, height: 40)
                                } else {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 60, height: 60)
                                }
                            }
                            .frame(width: 60, height: 60)
                        }
                    }

                    Spacer()

                    Button(action: {
                        if isRecording {
                            cameraManager.stopRecording()
                            recordingTime = 0
                            isRecording = false
                        } else {
                            cameraManager.switchCamera()
                        }
                    }) {
                        Image(systemName: isRecording ? "arrow.counterclockwise" : "camera.rotate")
                            .font(.title)
                            .foregroundColor(.white)
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
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
            }
        }
        .onReceive(timer) { _ in
            if isRecording {
                recordingTime += 1
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

final class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    var outputURL: URL?
    var onRecordingFinished: ((URL) -> Void)?
    private var currentCameraPosition: AVCaptureDevice.Position = .back

    func configure() {
        session.beginConfiguration()

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            print("카메라 설정 실패")
            return
        }

        session.addInput(videoInput)

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        session.startRunning()
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
