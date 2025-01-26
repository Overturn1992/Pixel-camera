import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    let isSquare: Bool
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.isSquare = isSquare
        view.isUsingFrontCamera = cameraManager.isUsingFrontCamera
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.isSquare = isSquare
        uiView.isUsingFrontCamera = cameraManager.isUsingFrontCamera
        uiView.updateImage(cameraManager.pixelatedImage)
        uiView.setNeedsLayout()
    }
}

class VideoPreviewView: UIView {
    private var imageView: UIImageView
    private var borderLayer: CAShapeLayer
    var isSquare: Bool = true
    var isUsingFrontCamera: Bool = false
    
    override init(frame: CGRect) {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        borderLayer = CAShapeLayer()
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.fillColor = nil
        borderLayer.lineWidth = 8
        
        super.init(frame: frame)
        backgroundColor = .black
        
        // 添加遮罩层
        let overlayLayer = CAShapeLayer()
        overlayLayer.fillRule = .evenOdd
        overlayLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        layer.addSublayer(overlayLayer)
        
        addSubview(imageView)
        layer.addSublayer(borderLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 计算预览区域的大小
        let bottomPadding: CGFloat = 200  // 为底部控制栏预留空间
        let availableHeight = bounds.height - bottomPadding
        
        let width: CGFloat = 300
        let height: CGFloat = isSquare ? width : width * 4/3
        let x = (bounds.width - width) / 2
        let y = (availableHeight - height) / 2
        
        // 设置图像视图的frame
        imageView.frame = CGRect(x: x, y: y, width: width, height: height)
        
        // 更新遮罩层
        if let overlayLayer = layer.sublayers?.first as? CAShapeLayer {
            let path = UIBezierPath(rect: bounds)
            path.append(UIBezierPath(rect: imageView.frame))
            overlayLayer.path = path.cgPath
        }
        
        // 更新边框
        let borderRect = imageView.frame.insetBy(dx: borderLayer.lineWidth/2, dy: borderLayer.lineWidth/2)
        borderLayer.path = UIBezierPath(rect: borderRect).cgPath
    }
    
    func updateImage(_ image: CGImage?) {
        if let image = image {
            // 计算目标尺寸
            let targetAspectRatio = isSquare ? 1.0 : 3.0/4.0
            let imageSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
            
            // 计算裁剪区域
            var cropRect: CGRect
            let imageAspectRatio = imageSize.width / imageSize.height
            
            if imageAspectRatio > targetAspectRatio {
                // 图片较宽，以高度为基准
                let cropWidth = imageSize.height * targetAspectRatio
                let x = (imageSize.width - cropWidth) / 2
                cropRect = CGRect(x: x, y: 0, width: cropWidth, height: imageSize.height)
            } else {
                // 图片较高，以宽度为基准
                let cropHeight = imageSize.width / targetAspectRatio
                let y = (imageSize.height - cropHeight) / 2
                cropRect = CGRect(x: 0, y: y, width: imageSize.width, height: cropHeight)
            }
            
            // 裁剪图像
            if let croppedImage = image.cropping(to: cropRect) {
                // 创建 UIImage 并根据摄像头类型设置正确的方向
                let orientation: UIImage.Orientation = isUsingFrontCamera ? .upMirrored : .left
                let uiImage = UIImage(cgImage: croppedImage, scale: 1.0, orientation: orientation)
                imageView.image = uiImage
            }
        }
    }
} 