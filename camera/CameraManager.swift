import AVFoundation
import SwiftUI
import Combine
import CoreImage
import ImageIO

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var error: Error?
    @Published var isUsingFrontCamera = false
    @Published var currentFrame: CMSampleBuffer?
    @Published var pixelatedImage: CGImage?
    @Published var pixelSize: Float = 8.0
    
    private var photoCompletion: ((Data?) -> Void)?
    let output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let context = CIContext()
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            DispatchQueue.global(qos: .userInitiated).async {
                self.setupCamera()
                self.session.startRunning()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        DispatchQueue.global(qos: .userInitiated).async {
                            self?.setupCamera()
                            self?.session.startRunning()
                        }
                    }
                }
            }
        default:
            self.isAuthorized = false
        }
    }
    
    func setupCamera() {
        do {
            session.beginConfiguration()
            
            // 清除现有的输入和输出
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            
            // 选择摄像头
            let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInUltraWideCamera, .builtInWideAngleCamera]
            let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
            
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: position
            )
            
            // 获取可用的摄像头
            let availableDevices = discoverySession.devices
            
            // 根据前后置选择合适的摄像头
            let device: AVCaptureDevice?
            if isUsingFrontCamera {
                // 前置摄像头直接使用广角
                device = availableDevices.first { $0.position == .front }
            } else {
                // 后置摄像头优先使用超广角
                device = availableDevices.first { $0.deviceType == .builtInUltraWideCamera } ??
                        availableDevices.first { $0.deviceType == .builtInWideAngleCamera }
            }
            
            guard let camera = device else {
                throw NSError(domain: "CameraError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法找到相机设备"])
            }
            
            // 只为后置摄像头设置变焦
            if !isUsingFrontCamera {
                try camera.lockForConfiguration()
                if camera.deviceType == .builtInUltraWideCamera {
                    camera.videoZoomFactor = 1.0 // 超广角摄像头默认就是0.5倍
                } else {
                    // 确保变焦倍数在有效范围内
                    let minZoom = camera.minAvailableVideoZoomFactor
                    let targetZoom = max(0.5, minZoom)
                    camera.videoZoomFactor = targetZoom
                }
                camera.unlockForConfiguration()
            }
            
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // 添加照片输出
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            // 添加视频输出用于实时预览
            if session.canAddOutput(videoOutput) {
                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                session.addOutput(videoOutput)
            }
            
            session.commitConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    func switchCamera() {
        isUsingFrontCamera.toggle()
        DispatchQueue.global(qos: .userInitiated).async {
            self.setupCamera()
        }
    }
    
    private func getCurrentVideoOrientation() -> AVCaptureVideoOrientation {
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
    
    func takePhoto(completion: @escaping (Data?) -> Void) {
        guard session.isRunning else {
            completion(nil)
            return
        }
        
        self.photoCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        
        // 根据当前设备方向设置照片方向
        if let photoOutputConnection = output.connection(with: .video) {
            photoOutputConnection.videoOrientation = getCurrentVideoOrientation()
        }
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
    // AVCapturePhotoCaptureDelegate 方法
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("拍照错误: \(error.localizedDescription)")
                self.photoCompletion?(nil)
                return
            }
            
            guard let imageData = photo.fileDataRepresentation() else {
                self.photoCompletion?(nil)
                return
            }
            
            self.photoCompletion?(imageData)
        }
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 根据摄像头类型设置视频方向
        if isUsingFrontCamera {
            connection.videoOrientation = .portrait
        } else {
            connection.videoOrientation = .landscapeLeft
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 根据像素大小决定是否应用像素化效果
        if pixelSize > 0 {
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
               let uiImage = PixelFilter.pixelate(image: UIImage(cgImage: cgImage), blockSize: pixelSize, isPreview: true),
               let finalCGImage = uiImage.cgImage {
                DispatchQueue.main.async {
                    self.pixelatedImage = finalCGImage
                }
            }
        } else {
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                DispatchQueue.main.async {
                    self.pixelatedImage = cgImage
                }
            }
        }
    }
} 