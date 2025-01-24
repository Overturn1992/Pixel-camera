import CoreImage
import UIKit

class PixelFilter {
    static func pixelate(image: UIImage, blockSize: Float = 20.0) -> UIImage? {
        guard let cgImage = image.cgImage,
              blockSize > 0 else { return image }  // 添加保护
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let filter = CIFilter(name: "CIPixellate") else { return image }  // 如果滤镜失败返回原图
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(max(5.0, blockSize), forKey: kCIInputScaleKey)  // 确保最小值为5.0
        
        guard let outputImage = filter.outputImage,
              let cgOutputImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image  // 如果处理失败返回原图
        }
        
        return UIImage(cgImage: cgOutputImage)
    }
    
    static func applyMosaicEffect(image: UIImage, blockSize: Float = 20.0) -> UIImage? {
        guard let cgImage = image.cgImage,
              blockSize > 0 else { return image }  // 添加保护
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // 创建马赛克滤镜
        guard let filter = CIFilter(name: "CIPixellate") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(max(5.0, blockSize), forKey: kCIInputScaleKey)  // 确保最小值为5.0
        
        // 添加一些颜色调整
        guard let colorFilter = CIFilter(name: "CIColorControls") else { return image }
        colorFilter.setValue(filter.outputImage, forKey: kCIInputImageKey)
        colorFilter.setValue(1.1, forKey: kCIInputSaturationKey) // 增加饱和度
        colorFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // 调整亮度
        
        guard let outputImage = colorFilter.outputImage,
              let cgOutputImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image  // 如果处理失败返回原图
        }
        
        return UIImage(cgImage: cgOutputImage)
    }
} 