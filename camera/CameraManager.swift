import AVFoundation
import SwiftUI
import Combine

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var preview: AVCaptureVideoPreviewLayer?
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
                
                // 设置照片输出的方向
                if let connection = output.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            }
            
            session.commitConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    func takePhoto(completion: @escaping (Data?) -> Void) {
        guard session.isRunning else {
            completion(nil)
            return
        }
        
        self.photoCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        // 确保输出方向正确
        if let photoOutputConnection = output.connection(with: .video) {
            photoOutputConnection.videoOrientation = .portrait
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
            
            self.photoCompletion?(photo.fileDataRepresentation())
        }
    }
} 