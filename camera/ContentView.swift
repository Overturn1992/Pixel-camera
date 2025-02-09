//
//  ContentView.swift
//  camera
//
//  Created by 刘南府 on 2025/1/22.
//

import SwiftUI
import Photos
import PhotosUI
import UIKit

// 添加权限声明
extension Bundle {
    static var cameraPermission: String { "需要访问相机来拍摄像素风格的照片" }
    static var photoLibraryPermission: String { "需要访问照片库来保存拍摄的照片" }
}

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var pixelSize: Float = 8.0  // 初始像素大小为8.0
    @State private var sliderPosition: CGFloat = 8.0/16.0  // 确保初始位置对应8.0
    @State private var lastPhoto: UIImage?
    @State private var lastPhotoAsset: PHAsset?
    @State private var showingImagePicker = false
    @State private var showingFullImage = false
    @State private var fullSizeImage: UIImage?
    @State private var isSquareFormat = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if cameraManager.isAuthorized {
                CameraPreviewView(
                    cameraManager: cameraManager,
                    isSquare: isSquareFormat
                )
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // 顶部切换摄像头按钮
                    HStack {
                        Button(action: {
                            cameraManager.switchCamera()
                        }) {
                            Image("CameraSwitch")
                                .resizable()
                                .frame(width: 32, height: 32)
                        }
                        .padding(.top, 20)
                        .padding(.leading, 30)  // 左边距改为30dp
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // 进度条控制栏
                    VStack(spacing: 0) {
                        // 像素化程度数字
                        Text("\(Int(pixelSize))")
                            .font(.custom("Goldman-Regular", size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(height: 30)
                            .padding(.bottom, 10)
                        
                        HStack {
                            // 进度条
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // 进度条背景
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 300, height: 30)
                                    
                                    // 滑块
                                    Image("ProgressSlider")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .offset(x: sliderPosition * (300 - 20))  // 减去滑块宽度
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    let newPosition = value.location.x / (300 - 20)  // 减去滑块宽度
                                                    sliderPosition = min(max(newPosition, 0), 1)
                                                    pixelSize = Float(sliderPosition * 16)  // 0-16的范围
                                                    cameraManager.pixelSize = pixelSize
                                                }
                                        )
                                }
                                .frame(width: 300, height: 30)
                            }
                            .frame(width: 300, height: 30)
                        }
                        .padding(.horizontal, 45)
                    }
                    .padding(.bottom, 30)
                    
                    // 底部控制栏
                    HStack {
                        // 左侧最近照片预览
                        if let lastPhoto = lastPhoto {
                            Button(action: {
                                if let asset = lastPhotoAsset {
                                    openLastPhoto(asset: asset)
                                }
                            }) {
                                Image(uiImage: lastPhoto)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                            }
                            .padding(.leading, 60)  // 左边距60dp
                        } else {
                            Rectangle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 32, height: 32)
                                .padding(.leading, 60)  // 左边距60dp
                        }
                        
                        Spacer()  // 使用Spacer自动分配空间
                        
                        // 中间拍照按钮
                        Button(action: {
                            takePhoto()
                        }) {
                            Image("ShutterButton")
                                .resizable()
                                .frame(width: 84, height: 84)
                        }
                        
                        Spacer()  // 使用Spacer自动分配空间
                        
                        // 右侧比例切换按钮
                        Button(action: {
                            isSquareFormat.toggle()
                        }) {
                            Image(isSquareFormat ? "RatioButton1x1" : "RatioButton3x4")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: isSquareFormat ? 32 : 42.67)
                        }
                        .padding(.trailing, 60)  // 右边距60dp
                    }
                    .padding(.bottom, 50)
                }
            } else {
                VStack {
                    Text("需要相机权限")
                        .font(.title)
                    Button("授权相机") {
                        cameraManager.checkPermissions()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .onAppear {
            loadLastPhoto()
        }
        .sheet(isPresented: $showingImagePicker) {
            if #available(iOS 14, *) {
                PHPickerView(isPresented: $showingImagePicker)
            }
        }
        .sheet(isPresented: $showingFullImage) {
            if let image = fullSizeImage {
                ImagePreviewView(image: image)
            }
        }
    }
    
    private func takePhoto() {
        cameraManager.takePhoto { [self] imageData in
            guard let imageData = imageData,
                  let originalImage = UIImage(data: imageData)?.fixOrientation() else { return }
            
            // 计算预览区域在原图中的对应区域
            let previewWidth: CGFloat = 300  // 修改为与预览界面相同的宽度
            let previewHeight: CGFloat = isSquareFormat ? previewWidth : previewWidth * 4/3
            
            // 计算裁剪区域
            let scale = originalImage.scale
            let imageSize = originalImage.size
            
            // 计算中心点
            let centerX = imageSize.width / 2
            let centerY = imageSize.height / 2
            
            // 计算裁剪区域的大小（保持原图的宽高比）
            let cropWidth: CGFloat
            let cropHeight: CGFloat
            
            if isSquareFormat {
                // 1:1 模式
                cropWidth = min(imageSize.width, imageSize.height)
                cropHeight = cropWidth
            } else {
                // 3:4 模式
                if imageSize.width / imageSize.height > 3.0 / 4.0 {
                    // 图片较宽，以高度为基准
                    cropHeight = imageSize.height
                    cropWidth = cropHeight * 3.0 / 4.0
                } else {
                    // 图片较高，以宽度为基准
                    cropWidth = imageSize.width
                    cropHeight = cropWidth * 4.0 / 3.0
                }
            }
            
            // 计算裁剪区域
            let cropRect = CGRect(
                x: centerX - cropWidth / 2,
                y: centerY - cropHeight / 2,
                width: cropWidth,
                height: cropHeight
            )
            
            // 创建裁剪后的图片
            guard let cgImage = originalImage.cgImage,
                  let croppedCGImage = cgImage.cropping(to: cropRect) else { return }
            let croppedImage = UIImage(cgImage: croppedCGImage, scale: scale, orientation: .up)
            
            // 创建最终图片（添加边框）
            UIGraphicsBeginImageContextWithOptions(CGSize(width: cropWidth, height: cropHeight), false, scale)
            defer { UIGraphicsEndImageContext() }
            
            // 绘制裁剪后的图片
            croppedImage.draw(in: CGRect(origin: .zero, size: CGSize(width: cropWidth, height: cropHeight)))
            
            // 添加白色边框
            let borderWidth: CGFloat = 30 * scale
            let borderRect = CGRect(x: borderWidth/2, y: borderWidth/2,
                                  width: cropWidth - borderWidth,
                                  height: cropHeight - borderWidth)
            let borderPath = UIBezierPath(rect: borderRect)
            UIColor.white.setStroke()
            borderPath.lineWidth = borderWidth
            borderPath.stroke()
            
            // 获取结果图像
            guard let processedImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
            
            // 应用像素化效果
            if cameraManager.pixelSize > 0,
               let pixelatedImage = PixelFilter.applyMosaicEffect(image: processedImage, blockSize: cameraManager.pixelSize) {
                self.lastPhoto = pixelatedImage
                saveImage(pixelatedImage)
            } else {
                self.lastPhoto = processedImage
                saveImage(processedImage)
            }
        }
    }
    
    private func loadLastPhoto() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        if let lastAsset = fetchResult.firstObject {
            self.lastPhotoAsset = lastAsset
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestImage(
                for: lastAsset,
                targetSize: CGSize(width: 64, height: 64),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                self.lastPhoto = image
            }
        }
    }
    
    private func saveImage(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    if success {
                        loadLastPhoto() // 更新最近照片预览
                    }
                }
            }
        }
    }
    
    private func openLastPhoto(asset: PHAsset) {
        // 尝试使用多个可能的 URL Scheme
        let urlSchemes = ["photos://", "photos-redirect://", "x-apple-camera://"]
        
        for scheme in urlSchemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        
        // 如果所有 URL Scheme 都失败，使用备用方案
        guard let window = UIApplication.shared.windows.first,
              let rootViewController = window.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: rootViewController)
    }
}

// 添加一个协调器来处理 PHPicker 的回调
class PHPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    static let shared = PHPickerCoordinator()
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
    }
}

class ImagePickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = ImagePickerDelegate()
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // 不要关闭，让用户查看照片
        if let asset = info[.phAsset] as? PHAsset {
            // 用户选择了照片，不做任何操作让用户继续查看
            return
        }
        // 如果没有获取到 asset，才关闭选择器
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

@available(iOS 14, *)
struct PHPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerView
        
        init(_ parent: PHPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
        }
    }
}

struct ImagePreviewView: View {
    @Environment(\.presentationMode) var presentationMode
    let image: UIImage
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationBarItems(
                trailing: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("完成")
                        .foregroundColor(.white)
                }
            )
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}

class PhotoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    static let shared = PhotoPickerDelegate()
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // 不要立即关闭，让用户查看照片
        if results.isEmpty {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ContentView()
}
