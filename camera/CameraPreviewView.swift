import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    let isSquare: Bool
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.isSquare = isSquare
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.isSquare = isSquare
        uiView.updateImage(cameraManager.pixelatedImage)
        uiView.setNeedsLayout()
    }
}

class VideoPreviewView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var imageView: UIImageView
    var isSquare: Bool = true
    
    override init(frame: CGRect) {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        super.init(frame: frame)
        backgroundColor = .black
        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 计算预览区域的大小
        let width: CGFloat = 300
        let height: CGFloat = isSquare ? width : width * 4/3
        let x = (bounds.width - width) / 2
        let y = (bounds.height - height) / 2
        
        // 设置图像视图的frame
        imageView.frame = CGRect(x: x, y: y, width: width, height: height)
    }
    
    func updateImage(_ image: CGImage?) {
        if let image = image {
            imageView.image = UIImage(cgImage: image)
        }
    }
} 