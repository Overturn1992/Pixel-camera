import CoreImage
import UIKit

class PixelFilter {
    static func pixelate(image: UIImage, blockSize: Float = 20.0) -> UIImage? {
        guard let cgImage = image.cgImage,
              blockSize > 0 else { return image }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // 1. 首先应用像素化效果
        guard let pixellateFilter = CIFilter(name: "CIPixellate") else { return image }
        pixellateFilter.setValue(ciImage, forKey: kCIInputImageKey)
        pixellateFilter.setValue(max(5.0, blockSize), forKey: kCIInputScaleKey)
        
        guard let pixellatedImage = pixellateFilter.outputImage else { return image }
        
        // 2. 创建网格图案
        let gridSize = CGFloat(max(5.0, blockSize))
        let width = pixellatedImage.extent.width
        let height = pixellatedImage.extent.height
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let graphicsContext = UIGraphicsGetCurrentContext() else { return image }
        
        // 3. 调整坐标系统并绘制像素化的图像
        graphicsContext.translateBy(x: 0, y: height)
        graphicsContext.scaleBy(x: 1.0, y: -1.0)
        
        if let cgPixellatedImage = context.createCGImage(pixellatedImage, from: pixellatedImage.extent) {
            graphicsContext.draw(cgPixellatedImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // 4. 恢复坐标系统以绘制网格线
        graphicsContext.scaleBy(x: 1.0, y: -1.0)
        graphicsContext.translateBy(x: 0, y: -height)
        
        // 设置裁剪区域，排除边框
        let borderWidth: CGFloat = 16
        let contentRect = CGRect(x: borderWidth, y: borderWidth,
                               width: width - borderWidth * 2,
                               height: height - borderWidth * 2)
        
        // 计算网格线的起始和结束位置
        let startX = ceil(borderWidth / gridSize) * gridSize
        let startY = ceil(borderWidth / gridSize) * gridSize
        let endX = floor((width - borderWidth) / gridSize) * gridSize
        let endY = floor((height - borderWidth) / gridSize) * gridSize
        
        graphicsContext.saveGState()
        graphicsContext.addRect(contentRect)
        graphicsContext.clip()
        
        // 绘制网格线
        graphicsContext.setLineWidth(1.0)
        graphicsContext.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
        
        // 垂直线
        for x in stride(from: startX, through: endX, by: gridSize) {
            graphicsContext.move(to: CGPoint(x: x, y: startY))
            graphicsContext.addLine(to: CGPoint(x: x, y: endY))
        }
        
        // 水平线
        for y in stride(from: startY, through: endY, by: gridSize) {
            graphicsContext.move(to: CGPoint(x: startX, y: y))
            graphicsContext.addLine(to: CGPoint(x: endX, y: y))
        }
        
        graphicsContext.strokePath()
        graphicsContext.restoreGState()
        
        // 5. 获取最终图像
        guard let finalImage = UIGraphicsGetImageFromCurrentImageContext() else { return image }
        return finalImage
    }
    
    static func applyMosaicEffect(image: UIImage, blockSize: Float = 20.0) -> UIImage? {
        return pixelate(image: image, blockSize: blockSize)
    }
} 