import SwiftUI
import UIKit

struct ImagePickerView: View {
    @Binding var isPresented: Bool
    let onImageSelected: (UIImage) -> Void
    
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("Select Image")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("dark"))
                    .padding(.top, 20)
                
                // Image preview area
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                } else {
                    Rectangle()
                        .fill(Color("shade2"))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundColor(Color("shade6"))
                                Text("No image selected")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color("shade6"))
                            }
                        )
                        .padding(.horizontal, 20)
                }
                
                // Photo picker button
                Button {
                    AppLogger.log(tag: "LOG-APP: ImagePickerView", message: "chooseFromLibrary() tapped")
                    showImagePicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16))
                        Text("Choose from Library")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color("blue"))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    // Cancel button
                    Button("Cancel") {
                        AppLogger.log(tag: "LOG-APP: ImagePickerView", message: "cancel() tapped")
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("dark"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color("shade2"))
                    .cornerRadius(8)
                    
                    // Send button
                    Button("Send Image") {
                        AppLogger.log(tag: "LOG-APP: ImagePickerView", message: "sendImage() tapped")
                        if let image = selectedImage {
                            onImageSelected(image)
                            isPresented = false
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(selectedImage != nil ? Color("blue") : Color("shade4"))
                    .cornerRadius(8)
                    .disabled(selectedImage == nil)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color("Background Color"))
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerController { image in
                selectedImage = image
                AppLogger.log(tag: "LOG-APP: ImagePickerView", message: "onImageSelected() image loaded successfully")
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - UIImagePickerController Wrapper
struct ImagePickerController: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @objc(ImagePickerControllerCoordinator)
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerController
        
        init(_ parent: ImagePickerController) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    ImagePickerView(
        isPresented: .constant(true),
        onImageSelected: { image in
            print("Image selected: \(image)")
        }
    )
} 