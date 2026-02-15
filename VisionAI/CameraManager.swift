import SwiftUI
import AVFoundation

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isRunning = false
    @Published var error: String?

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var photoCaptureDelegate: PhotoCaptureDelegate?

    override init() {
        super.init()
        #if !targetEnvironment(macCatalyst)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        #endif
        checkPermissions()
    }
    
    deinit {
        #if !targetEnvironment(macCatalyst)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        #endif
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupCamera()
                } else {
                    DispatchQueue.main.async {
                        self?.error = "Camera access denied"
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.error = "Camera access denied. Please enable in System Settings > Privacy > Camera."
            }
        @unknown default:
            break
        }
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            // Set session preset
            self.session.sessionPreset = .photo

            // Find camera device
            let device: AVCaptureDevice?
            #if targetEnvironment(macCatalyst)
            device = AVCaptureDevice.default(for: .video)
            #else
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video)
            #endif
            
            guard let captureDevice = device else {
                DispatchQueue.main.async {
                    self.error = "No camera found"
                }
                self.session.commitConfiguration()
                return
            }
            
            print("[Camera] Using device: \(captureDevice.localizedName)")
            
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    print("[Camera] Cannot add input")
                    DispatchQueue.main.async { self.error = "Cannot configure camera input" }
                    self.session.commitConfiguration()
                    return
                }
            } catch {
                print("[Camera] Input error: \(error)")
                DispatchQueue.main.async { self.error = "Camera input error: \(error.localizedDescription)" }
                self.session.commitConfiguration()
                return
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                #if !targetEnvironment(macCatalyst)
                self.photoOutput.isHighResolutionCaptureEnabled = true
                #endif
            }

            self.session.commitConfiguration()
            
            // Auto-start camera after setup
            self.session.startRunning()
            print("[Camera] Session started successfully")
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    func startCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        }
    }

    func stopCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }

    func switchCamera() {
        #if targetEnvironment(macCatalyst)
        return
        #else
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else {
                self.session.commitConfiguration()
                return
            }
            self.session.removeInput(currentInput)
            
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
               let newInput = try? AVCaptureDeviceInput(device: newDevice) {
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                }
            } else {
                self.session.addInput(currentInput)
            }
            
            if let connection = self.photoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                connection.isVideoMirrored = (newPosition == .front)
            }
            
            self.session.commitConfiguration()
        }
        #endif
    }

    func capturePhoto() async throws -> UIImage {
        // Ensure session is running
        guard session.isRunning else {
            throw NSError(domain: "CameraError", code: -2, userInfo: [NSLocalizedDescriptionKey: "摄像头未运行"])
        }
        
        // Ensure photo output has a valid connection
        guard photoOutput.connection(with: .video) != nil else {
            throw NSError(domain: "CameraError", code: -3, userInfo: [NSLocalizedDescriptionKey: "摄像头连接无效"])
        }
        
        let settings = AVCapturePhotoSettings()
        
        #if !targetEnvironment(macCatalyst)
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = currentVideoOrientation()
            }
        }
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate { image in
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(domain: "CameraError", code: -1, userInfo: [NSLocalizedDescriptionKey: "拍照失败，未获取到图片"]))
                }
            }
            
            self.photoCaptureDelegate = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
    
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        #if targetEnvironment(macCatalyst)
        return .portrait
        #else
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return .portrait
        }
        #endif
    }
}

// MARK: - Photo Capture Delegate

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("[Camera] Photo capture error: \(error)")
            completion(nil)
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        
        let fixedImage = image.fixedOrientation()
        completion(fixedImage)
    }
}

// MARK: - Camera Preview View

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

class VideoPreviewView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(previewLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        
        #if !targetEnvironment(macCatalyst)
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
             let deviceOrientation = UIDevice.current.orientation
             switch deviceOrientation {
             case .portrait: connection.videoOrientation = .portrait
             case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
             case .landscapeLeft: connection.videoOrientation = .landscapeRight
             case .landscapeRight: connection.videoOrientation = .landscapeLeft
             default: break
             }
        }
        #endif
    }
}
