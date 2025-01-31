import CoreImage
import UIKit

class PixelFilter {
    static func pixelate(image: UIImage, blockSize: Float = 20.0, isPreview: Bool = false) -> UIImage? {
        guard let cgImage = image.cgImage,
              blockSize > 0 else { return image }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let gridSize = CGFloat(max(5.0, blockSize))
        let borderWidth: CGFloat = 16
        
        // 创建绘图上下文
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        // 先绘制原始图像
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0, y: -height)
        
        // 计算网格范围
        let startX = ceil(borderWidth / gridSize) * gridSize
        let startY = ceil(borderWidth / gridSize) * gridSize
        let endX = floor((width - borderWidth) / gridSize) * gridSize
        let endY = floor((height - borderWidth) / gridSize) * gridSize
        
        // 获取图像数据
        guard let imageData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(imageData) else { return image }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        // 遍历每个网格
        for y in stride(from: startY, to: endY, by: gridSize) {
            for x in stride(from: startX, to: endX, by: gridSize) {
                // 计算网格中心点
                let centerX = Int(x + gridSize / 2)
                let centerY = Int(y + gridSize / 2)
                
                // 获取中心点的颜色
                let offset = centerY * bytesPerRow + centerX * bytesPerPixel
                
                // 根据是否是预览模式选择不同的颜色读取顺序
                let (red, green, blue, alpha) = isPreview ? (
                    CGFloat(data[offset]) / 255.0,      // RGBA: Red
                    CGFloat(data[offset + 1]) / 255.0,  // RGBA: Green
                    CGFloat(data[offset + 2]) / 255.0,  // RGBA: Blue
                    CGFloat(data[offset + 3]) / 255.0   // RGBA: Alpha
                ) : (
                    CGFloat(data[offset + 2]) / 255.0,  // BGRA: Red
                    CGFloat(data[offset + 1]) / 255.0,  // BGRA: Green
                    CGFloat(data[offset]) / 255.0,      // BGRA: Blue
                    CGFloat(data[offset + 3]) / 255.0   // BGRA: Alpha
                )
                
                // 使用中心点颜色填充整个网格
                let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: x, y: y, width: gridSize, height: gridSize))
            }
        }
        
        // 设置裁剪区域，排除边框
        let contentRect = CGRect(x: borderWidth, y: borderWidth,
                               width: width - borderWidth * 2,
                               height: height - borderWidth * 2)
        
        context.saveGState()
        context.addRect(contentRect)
        context.clip()
        
        // 绘制网格线
        context.setLineWidth(1.0)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
        
        // 垂直线
        for x in stride(from: startX, through: endX, by: gridSize) {
            context.move(to: CGPoint(x: x, y: startY))
            context.addLine(to: CGPoint(x: x, y: endY))
        }
        
        // 水平线
        for y in stride(from: startY, through: endY, by: gridSize) {
            context.move(to: CGPoint(x: startX, y: y))
            context.addLine(to: CGPoint(x: endX, y: y))
        }
        
        context.strokePath()
        context.restoreGState()
        
        // 获取最终图像
        guard let finalImage = UIGraphicsGetImageFromCurrentImageContext() else { return image }
        return finalImage
    }
    
    static func applyMosaicEffect(image: UIImage, blockSize: Float = 20.0) -> UIImage? {
        return pixelate(image: image, blockSize: blockSize)
    }
} 