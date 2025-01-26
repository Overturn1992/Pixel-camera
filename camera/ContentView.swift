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
    @State private var pixelSize: Float = 8.0
    @State private var lastPhoto: UIImage?
    @State private var showingCapturedImage = false
    @State private var isSaving = false
    @State private var sliderPosition: CGFloat = 0.5
    @State private var lastPhotoAsset: PHAsset?
    @State private var showingImagePicker = false
    @State private var showingFullImage = false
    @State private var fullSizeImage: UIImage?
    @State private var isSquareFormat = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session, isSquare: isSquareFormat)
                    .edgesIgnoringSafeArea(.all)
                    .padding(.top, 60)
                
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
                        .padding(.leading, 20)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // 进度条控制栏
                    VStack(spacing: 0) {
                        // 像素化程度数字
                        Text("\(Int(pixelSize))")
                            .font(.custom("Goldman-Regular", size: 24))
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        HStack {
                            // 左侧网格图标
                            Image(systemName: "square.grid.3x3")
                                .foregroundColor(.white)
                            
                            // 进度条
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // 进度条背景
                                    Image("ProgressBar")
                                        .resizable()
                                        .frame(height: 20)
                                    
                                    // 滑块
                                    Image("ProgressSlider")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .offset(x: sliderPosition * (geometry.size.width - 20))
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    let newPosition = value.location.x / (geometry.size.width - 20)
                                                    sliderPosition = min(max(newPosition, 0), 1)
                                                    pixelSize = Float(sliderPosition * 16) // 0-16的范围
                                                }
                                        )
                                }
                            }
                            .frame(height: 20)
                            
                            // 右侧网格图标
                            Image(systemName: "square.grid.3x3.fill")
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                    
                    // 底部控制栏
                    HStack(spacing: 80) {
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
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                        } else {
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 32, height: 32)
                        }
                        
                        // 中间拍照按钮
                        Button(action: {
                            takePhoto()
                        }) {
                            Image("ShutterButton")
                                .resizable()
                                .frame(width: 84, height: 84)
                        }
                        
                        // 右侧比例切换按钮
                        Button(action: {
                            isSquareFormat.toggle()
                        }) {
                            Image(isSquareFormat ? "RatioButton1x1" : "RatioButton3x4")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: isSquareFormat ? 32 : 42.67) // 3:4 比例时高度为 32 * 4/3
                        }
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
        .sheet(isPresented: $showingCapturedImage) {
            if let image = lastPhoto {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    
                    HStack {
                        Button("重拍") {
                            showingCapturedImage = false
                        }
                        .padding()
                        
                        Button(action: {
                            saveImage(image)
                        }) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("保存")
                            }
                        }
                        .padding()
                        .disabled(isSaving)
                    }
                }
            }
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
        cameraManager.takePhoto { imageData in
            guard let imageData = imageData,
                  let image = UIImage(data: imageData)?.fixOrientation() else { return }
            
            if pixelSize == 0 {
                // 不进行像素化
                self.lastPhoto = image
            } else if let pixelatedImage = PixelFilter.applyMosaicEffect(image: image, blockSize: pixelSize) {
                self.lastPhoto = pixelatedImage
            }
            self.showingCapturedImage = true
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
        isSaving = true
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        isSaving = false
                        if success {
                            showingCapturedImage = false
                        }
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
