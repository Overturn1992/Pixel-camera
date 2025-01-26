import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let isSquare: Bool  // true 为 1:1，false 为 3:4
    
    class VideoPreviewView: UIView {
        private var overlayLayer: CAShapeLayer?
        private var borderLayer: CAShapeLayer?
        var isSquare: Bool = true
        
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
            
            // 更新遮罩层和边框
            updateOverlay()
        }
        
        func setupOverlay() {
            // 创建遮罩层
            let overlay = CAShapeLayer()
            overlay.fillRule = .evenOdd
            overlay.fillColor = UIColor.black.cgColor // 纯黑色不透明
            layer.addSublayer(overlay)
            overlayLayer = overlay
            
            // 创建白色边框
            let border = CAShapeLayer()
            border.fillColor = nil
            border.strokeColor = UIColor.white.cgColor
            border.lineWidth = 8
            layer.addSublayer(border)
            borderLayer = border
            
            updateOverlay()
        }
        
        private func updateOverlay() {
            guard let overlay = overlayLayer,
                  let border = borderLayer else { return }
            
            overlay.frame = bounds
            border.frame = bounds
            
            // 创建遮罩路径
            let path = UIBezierPath(rect: bounds)
            
            // 计算预览区域大小
            let width: CGFloat = 300
            let height: CGFloat = isSquare ? width : width * 4/3
            let x = (bounds.width - width) / 2
            
            // 计算Y位置，使其位于顶部和进度条之间的中心
            let bottomPadding: CGFloat = 300
            let availableHeight = bounds.height - bottomPadding
            let y = (availableHeight - height) / 2
            
            let rect = CGRect(x: x, y: y, width: width, height: height)
            
            // 在遮罩中挖出预览区域
            path.append(UIBezierPath(rect: rect).reversing())
            overlay.path = path.cgPath
            
            // 设置边框
            border.path = UIBezierPath(rect: rect).cgPath
        }
    }
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.isSquare = isSquare
        
        // 设置预览方向为竖直
        if view.videoPreviewLayer.connection?.isVideoOrientationSupported == true {
            view.videoPreviewLayer.connection?.videoOrientation = .portrait
        }
        
        // 设置遮罩和边框
        view.setupOverlay()
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // 确保预览方向始终为竖直
        if uiView.videoPreviewLayer.connection?.isVideoOrientationSupported == true {
            uiView.videoPreviewLayer.connection?.videoOrientation = .portrait
        }
        uiView.isSquare = isSquare
        uiView.setNeedsLayout()
    }
} 