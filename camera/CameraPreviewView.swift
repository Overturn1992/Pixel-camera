import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
            // 预览画面始终保持竖直
            if videoPreviewLayer.connection?.isVideoOrientationSupported == true {
                videoPreviewLayer.connection?.videoOrientation = .portrait
            }
        }
    }
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        
        // 设置预览方向为竖直
        if view.videoPreviewLayer.connection?.isVideoOrientationSupported == true {
            view.videoPreviewLayer.connection?.videoOrientation = .portrait
        }
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // 确保预览方向始终为竖直
        if uiView.videoPreviewLayer.connection?.isVideoOrientationSupported == true {
            uiView.videoPreviewLayer.connection?.videoOrientation = .portrait
        }
    }
} 