//
//  ContentView.swift
//  camera
//
//  Created by 刘南府 on 2025/1/22.
//

import SwiftUI
import Photos

// 添加权限声明
extension Bundle {
    static var cameraPermission: String { "需要访问相机来拍摄像素风格的照片" }
    static var photoLibraryPermission: String { "需要访问照片库来保存拍摄的照片" }
}

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingSettings = false
    @State private var pixelSize: Float = 20.0
    @State private var capturedImage: UIImage?
    @State private var showingCapturedImage = false
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    // 像素大小调节滑块
                    HStack {
                        Image(systemName: "square.grid.3x3")
                            .foregroundColor(.white)
                        Slider(value: $pixelSize, in: 5...50)
                            .accentColor(.white)
                        Image(systemName: "square.grid.4x3.fill")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding()
                    
                    // 控制按钮
                    HStack(spacing: 60) {
                        Button(action: {
                            showingSettings.toggle()
                        }) {
                            Image(systemName: "gear")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            takePhoto()
                        }) {
                            Circle()
                                .fill(.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(.black.opacity(0.3), lineWidth: 2)
                                )
                        }
                        
                        Button(action: {
                            // 切换前后摄像头
                        }) {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 30)
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
        .sheet(isPresented: $showingCapturedImage) {
            if let image = capturedImage {
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
    }
    
    private func takePhoto() {
        cameraManager.takePhoto { imageData in
            guard let imageData = imageData,
                  let image = UIImage(data: imageData) else { return }
            
            // 应用像素化效果
            if let pixelatedImage = PixelFilter.applyMosaicEffect(image: image, blockSize: pixelSize) {
                DispatchQueue.main.async {
                    self.capturedImage = pixelatedImage
                    self.showingCapturedImage = true
                }
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
}

#Preview {
    ContentView()
}
