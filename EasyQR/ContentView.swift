import SwiftUI
import AVFoundation
import PhotosUI
import Combine

struct ContentView: View {
    @State private var scannedText: String = ""
    @State private var isScanning: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showQRCodeSheet: Bool = false
    @State private var qrCodes: [UIImage] = []
    @State private var currentQRIndex: Int = 0
    @State private var isGenerating: Bool = false
    @State private var showCopyNotification: Bool = false
    @State private var showEmptyTextNotification: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    
    private var isChinese: Bool {
        Bundle.main.preferredLocalizations.first?.prefix(2) == "zh"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Scanning Window Area
            ZStack {
                QRScannerView(scannedText: $scannedText, isScanning: $isScanning)
                    .overlay(
                        Group {
                            if !isScanning {
                                Color.black.opacity(0.5)
                                    .overlay(
                                        Text(isChinese ? "请点击'扫描'进行扫描" : "Click 'Scan' to start scanning")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .medium))
                                    )
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Image picker button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            hideKeyboard()
                            showImagePicker = true
                        }) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.accentColor))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.4)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .onTapGesture {
                hideKeyboard()
            }
            
            // 2. Editable Text Area
            TextEditor(text: $scannedText)
                .frame(height: UIScreen.main.bounds.height * 0.3)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            Spacer()
            
            // 3. Button Area
            HStack(spacing: 20) {
                VStack {
                    Button(action: {
                        hideKeyboard()
                        isGenerating = true
                        generateQRCodes()
                    }) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 28))
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    Text(isChinese ? "制作" : "Make")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                VStack {
                    Button(action: {
                        hideKeyboard()
                        scannedText = ""
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 28))
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    Text(isChinese ? "清除" : "Clear")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                VStack {
                    Button(action: {
                        hideKeyboard()
                        UIPasteboard.general.string = scannedText
                        showCopyNotification = true
                        // Hide notification after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopyNotification = false
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 28))
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    Text(isChinese ? "复制" : "Copy")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                VStack {
                    Button(action: {
                        hideKeyboard()
                        isScanning = true
                    }) {
                        ZStack {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                            
                            // Horizontal bar in the center
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 28, height: 2)
                        }
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                    Text(isChinese ? "扫描" : "Scan")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 34 : 0)
        }
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = height
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(scannedText: $scannedText)
        }
        .sheet(isPresented: $showQRCodeSheet) {
            QRCodeDisplayView(qrCodes: qrCodes, currentIndex: $currentQRIndex)
        }
        .overlay(
            Group {
                if showCopyNotification {
                    Text(isChinese ? "已复制到剪贴板" : "Copied to clipboard")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .animation(.easeInOut, value: showCopyNotification)
                }
                
                if showEmptyTextNotification {
                    Text(isChinese ? "请输入文本内容" : "Please enter text content")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .animation(.easeInOut, value: showEmptyTextNotification)
                }
            }
        )
        .onChange(of: scannedText) { oldValue, newValue in
            if !newValue.isEmpty {
                isScanning = false
            }
        }
        .onChange(of: qrCodes) { oldValue, newValue in
            if !newValue.isEmpty {
                isGenerating = false
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func generateQRCodes() {
        guard !scannedText.isEmpty else { 
            // Show notification when text is empty
            showEmptyTextNotification = true
            isGenerating = false
            // Hide notification after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showEmptyTextNotification = false
            }
            return 
        }
        
        // Clear existing QR codes before generating new ones
        qrCodes.removeAll()
        
        let data = scannedText.data(using: .utf8)!
        let chunkSize = 400
        let chunks = stride(from: 0, to: data.count, by: chunkSize).map {
            data.subdata(in: $0..<min($0 + chunkSize, data.count))
        }
        
        var generatedQRCodes: [UIImage] = []
        
        for (_, chunk) in chunks.enumerated() {
            if let qrFilter = CIFilter(name: "CIQRCodeGenerator") {
                qrFilter.setValue(chunk, forKey: "inputMessage")
                qrFilter.setValue("M", forKey: "inputCorrectionLevel")
                
                if let qrImage = qrFilter.outputImage {
                    let transform = CGAffineTransform(scaleX: 10, y: 10)
                    let scaledQrImage = qrImage.transformed(by: transform)
                    let context = CIContext()
                    if let cgImage = context.createCGImage(scaledQrImage, from: scaledQrImage.extent) {
                        let uiImage = UIImage(cgImage: cgImage)
                        generatedQRCodes.append(uiImage)
                    }
                }
            }
        }
        
        // Update state on the main thread
        DispatchQueue.main.async {
            if !generatedQRCodes.isEmpty {
                self.qrCodes = generatedQRCodes
                self.currentQRIndex = 0
                self.showQRCodeSheet = true
            }
            self.isGenerating = false
        }
    }
}

struct QRScannerView: UIViewRepresentable {
    @Binding var scannedText: String
    @Binding var isScanning: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let captureSession = AVCaptureSession()
        
        // Configure capture session
        captureSession.beginConfiguration()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return view }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return view
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return view
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return view
        }
        
        captureSession.commitConfiguration()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Store the preview layer and capture session in the coordinator
        context.coordinator.previewLayer = previewLayer
        context.coordinator.captureSession = captureSession
        
        // Start capture session on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer's frame when the view's bounds change
        context.coordinator.previewLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: QRScannerView
        var previewLayer: AVCaptureVideoPreviewLayer?
        var captureSession: AVCaptureSession?
        
        init(_ parent: QRScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if !parent.isScanning { return }
            
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                
                // Add haptic feedback for successful scan
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                if !parent.scannedText.isEmpty {
                    parent.scannedText += stringValue
                } else {
                    parent.scannedText = stringValue
                }
                parent.isScanning = false
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var scannedText: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
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
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if let image = image as? UIImage {
                        if let ciImage = CIImage(image: image) {
                            let context = CIContext()
                            let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
                            let features = detector?.features(in: ciImage)
                            
                            if let feature = features?.first as? CIQRCodeFeature {
                                DispatchQueue.main.async {
                                    // Add haptic feedback for successful scan
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    if !self.parent.scannedText.isEmpty {
                                        self.parent.scannedText += feature.messageString ?? ""
                                    } else {
                                        self.parent.scannedText = feature.messageString ?? ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct QRCodeDisplayView: View {
    let qrCodes: [UIImage]
    @Binding var currentIndex: Int
    @Environment(\.presentationMode) var presentationMode
    @State private var showSaveNotification: Bool = false
    
    var body: some View {
        VStack {
            TabView(selection: $currentIndex) {
                ForEach(0..<qrCodes.count, id: \.self) { index in
                    VStack {
                        Image(uiImage: qrCodes[index])
                            .resizable()
                            .scaledToFit()
                            .padding()
                        
                        Text("\(index + 1)/\(qrCodes.count)")
                            .font(.title3)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            
            HStack(spacing: 60) {
                Button(action: {
                    saveQRCodes()
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 28))
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28))
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .overlay(
            Group {
                if showSaveNotification {
                    Text(Bundle.main.preferredLocalizations.first?.prefix(2) == "zh" ? "已保存到相册" : "Saved to Photos")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .animation(.easeInOut, value: showSaveNotification)
                }
            }
        )
    }
    
    private func saveQRCodes() {
        for (_, qrCode) in qrCodes.enumerated() {
            UIImageWriteToSavedPhotosAlbum(qrCode, nil, nil, nil)
        }
        showSaveNotification = true
        // Hide notification after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveNotification = false
        }
    }
}

// MARK: - Keyboard Height Publisher
extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    return keyboardFrame.cgRectValue.height
                }
                return 0
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> CGFloat in
                return 0
            }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
} 
