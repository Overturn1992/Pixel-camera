import AVFoundation
import SwiftUI
import Combine
import CoreImage
import ImageIO

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    @Published var error: Error?
    
    private var photoCompletion: ((Data?) -> Void)?
    let output = AVCapturePhotoOutput()
    
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
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw NSError(domain: "CameraError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法找到相机设备"])
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
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
} 