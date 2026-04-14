//
//  CameraView.swift
//  Garden Management
//
//  Created by Brendon Kelly on 7/4/2026.
//

import SwiftUI
import Photos

struct CapturedPhoto {
    let imageData: Data
    let assetIdentifier: String?
}

#if os(iOS)
import UIKit

struct CameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var capturedPhotos: [CapturedPhoto]
    var saveToPhotoLibrary: Bool = true
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    if parent.saveToPhotoLibrary {
                        saveImageToPhotoLibrary(image, imageData: imageData)
                    } else {
                        parent.capturedPhotos.append(CapturedPhoto(imageData: imageData, assetIdentifier: nil))
                    }
                }
            }
            
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
        
        private func saveImageToPhotoLibrary(_ image: UIImage, imageData: Data) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized else {
                    print("Photo library access denied")
                    // Still add photo with data but no identifier
                    DispatchQueue.main.async {
                        self.parent.capturedPhotos.append(CapturedPhoto(imageData: imageData, assetIdentifier: nil))
                    }
                    return
                }
                
                var assetIdentifier: String?
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    assetIdentifier = request.placeholderForCreatedAsset?.localIdentifier
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("Successfully saved photo to library with identifier: \(assetIdentifier ?? "none")")
                            self.parent.capturedPhotos.append(CapturedPhoto(imageData: imageData, assetIdentifier: assetIdentifier))
                        } else {
                            print("Error saving photo: \(error?.localizedDescription ?? "unknown")")
                            // Still add photo with data but no identifier
                            self.parent.capturedPhotos.append(CapturedPhoto(imageData: imageData, assetIdentifier: nil))
                        }
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

struct CameraButton: View {
    @Binding var showingCamera: Bool
    @Binding var capturedPhotos: [CapturedPhoto]
    
    var body: some View {
        Button {
            checkCameraPermission()
        } label: {
            Label("Take Photo", systemImage: "camera")
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        showingCamera = true
                    }
                }
            }
        case .denied, .restricted:
            // Show alert to user
            print("Camera access denied. Please enable in Settings.")
        @unknown default:
            break
        }
    }
}

import AVFoundation

#endif
