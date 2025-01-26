import Metal
import MetalKit
import AVFoundation

class MetalRenderer: NSObject {
    private let metalDevice: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pixelateFunction: MTLComputePipelineState
    private var textureCache: CVMetalTextureCache?
    
    // 像素化参数
    private var blockSize: Float = 8.0
    
    init?(blockSize: Float = 8.0) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        
        self.metalDevice = device
        self.commandQueue = queue
        self.blockSize = blockSize
        
        // 创建纹理缓存
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
        self.textureCache = textureCache
        
        // 加载着色器
        guard let library = try? device.makeDefaultLibrary(),
              let pixelateFunction = library.makeFunction(name: "pixelate"),
              let pixelatePipeline = try? device.makeComputePipelineState(function: pixelateFunction) else {
            return nil
        }
        
        self.pixelateFunction = pixelatePipeline
        
        super.init()
    }
    
    func updateBlockSize(_ newSize: Float) {
        blockSize = newSize
    }
    
    func pixelateImage(sampleBuffer: CMSampleBuffer) -> CVPixelBuffer? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // 创建输入纹理
        var cvTextureIn: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache!, pixelBuffer, nil, .bgra8Unorm,
                                                width, height, 0, &cvTextureIn)
        
        guard let cvTextureIn = cvTextureIn,
              let textureIn = CVMetalTextureGetTexture(cvTextureIn) else {
            return nil
        }
        
        // 创建输出纹理
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false)
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        
        guard let textureOut = metalDevice.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        // 创建命令缓冲区
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        // 设置计算管线
        computeEncoder.setComputePipelineState(pixelateFunction)
        computeEncoder.setTexture(textureIn, index: 0)
        computeEncoder.setTexture(textureOut, index: 1)
        computeEncoder.setBytes(&blockSize, length: MemoryLayout<Float>.size, index: 0)
        
        // 计算线程组大小
        let threadGroupSize = MTLSizeMake(8, 8, 1)
        let threadGroups = MTLSizeMake(
            (width + threadGroupSize.width - 1) / threadGroupSize.width,
            (height + threadGroupSize.height - 1) / threadGroupSize.height,
            1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        // 创建输出像素缓冲区
        var outputPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height,
                           kCVPixelFormatType_32BGRA,
                           [
                            kCVPixelBufferMetalCompatibilityKey: true,
                            kCVPixelBufferIOSurfacePropertiesKey: [:]
                           ] as CFDictionary,
                           &outputPixelBuffer)
        
        guard let outputPixelBuffer = outputPixelBuffer else {
            return nil
        }
        
        // 将处理后的纹理复制到输出像素缓冲区
        CVPixelBufferLockBaseAddress(outputPixelBuffer, [])
        let bytesPerRow = CVPixelBufferGetBytesPerRow(outputPixelBuffer)
        let region = MTLRegionMake2D(0, 0, width, height)
        
        if let baseAddress = CVPixelBufferGetBaseAddress(outputPixelBuffer) {
            textureOut.getBytes(baseAddress,
                              bytesPerRow: bytesPerRow,
                              from: region,
                              mipmapLevel: 0)
        }
        
        CVPixelBufferUnlockBaseAddress(outputPixelBuffer, [])
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputPixelBuffer
    }
} 