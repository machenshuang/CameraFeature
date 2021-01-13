//
//  CameraViewController.swift
//  AVCamera
//
//  Created by 马陈爽 on 2021/1/12.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {
    
    private var spinner: UIActivityIndicatorView!
    @IBOutlet weak var preview: PreviewView!
    @IBOutlet weak var cameraBtn: UIButton!
    @IBOutlet weak var photoBtn: UIButton!
    
    var bracketedEnable = false
    var livePhotoEnable = false
    var thumbnailEnable = false
    var sceneMonitoring = false

    
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var setupResult: SessionSetupResult = .success
    @objc dynamic private let photoOutput = AVCapturePhotoOutput()
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera,
                                                                                             .builtInDualWideCamera,
                                                                                             .builtInDualCamera,
                                                                                             .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
    
    private let depthVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera,
                                                                                                  .builtInDualCamera,
                                                                                                  .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    private var keyValueObservations = [NSKeyValueObservation]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cameraBtn.isEnabled = false
        self.photoBtn.isEnabled = false
        
        preview.session = self.session
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            self.sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            self.setupResult = .notAuthorized
        }
        
        self.sessionQueue.async { [weak self] in
            guard let `self` = self else { return }
            self.configureSession()
        }
        
        self.spinner = UIActivityIndicatorView(style: .large)
        self.spinner.color = UIColor.yellow
        self.preview.addSubview(self.spinner)
        
    }
    
    deinit {
        if self.sceneMonitoring {
            for keyValueObservation in self.keyValueObservations {
                keyValueObservation.invalidate()
            }
            self.keyValueObservations.removeAll()
        }
    }
    
    private func configureSession() {
        if self.setupResult != .success {
            return
        }
        
        self.session.beginConfiguration()
        self.session.sessionPreset = .photo
        
        // Add video input.
        do {
            let defaultVideoDevice = self.getCaptureDevice(with: .back)
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                self.setupResult = .configurationFailed
                self.session.commitConfiguration()
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    let initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    self.preview.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                }
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        if self.session.canAddOutput(self.photoOutput) {
            self.session.addOutput(self.photoOutput)
            
            self.photoOutput.isHighResolutionCaptureEnabled = true
            if self.livePhotoEnable {
                self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported
            }
            
            if self.sceneMonitoring {
                let photoSettings = AVCapturePhotoSettings()
                photoSettings.flashMode = .on
                self.photoOutput.photoSettingsForSceneMonitoring = photoSettings
                let flashKeyValueObservation = self.photoOutput.observe(\.isFlashScene, options: .new) { (_, change) in
                    guard let open = change.newValue else { return }
                    debugPrint("闪光灯的推荐状态：\(open ? "打开" : "关闭")")
                }
                self.keyValueObservations.append(flashKeyValueObservation)
            }
            
            //self.photoOutput.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported
            //self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = self.photoOutput.isPortraitEffectsMatteDeliverySupported
            ///self.photoOutput.enabledSemanticSegmentationMatteTypes = self.photoOutput.availableSemanticSegmentationMatteTypes
            
            //self.photoOutput.maxPhotoQualityPrioritization = .quality
//            livePhotoMode = photoOutput.isLivePhotoCaptureSupported ? .on : .off
//            depthDataDeliveryMode = photoOutput.isDepthDataDeliverySupported ? .on : .off
//            portraitEffectsMatteDeliveryMode = photoOutput.isPortraitEffectsMatteDeliverySupported ? .on : .off
//            photoQualityPrioritizationMode = .balanced
            
            DispatchQueue.main.async {
                [self.cameraBtn, self.photoBtn].forEach {
                    $0.isEnabled = true
                }
            }
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.sessionQueue.async { [weak self] in
            guard let `self` = self else { return }
            switch self.setupResult {
            case .success:
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.sessionQueue.async { [weak self] in
            guard let `self` = self else { return }
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    @IBAction func capturePhoto(_ sender: UIButton) {
        let videoPreviewLayerOrientation = preview.videoPreviewLayer.connection?.videoOrientation
        
        self.sessionQueue.async { [weak self] in
            guard let `self` = self else { return }
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
            }
            var photoSettings = AVCapturePhotoSettings()
            
            // Capture HEIF photos when supported. Enable auto-flash and high-resolution photos.
            if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.bracketedEnable {
                let bracketedStillImageSettings = [AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: -1),
                                                   AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 0),
                                                   AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 1)]
                photoSettings = AVCapturePhotoBracketSettings.init(rawPixelFormatType: 0, processedFormat: nil, bracketedSettings: bracketedStillImageSettings)
            }

            photoSettings.isHighResolutionPhotoEnabled = true
            if self.thumbnailEnable && !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
            }
            // Live Photo capture is not supported in movie mode.
            if self.livePhotoEnable && self.photoOutput.isLivePhotoCaptureSupported {
                let livePhotoMovieFileName = NSUUID().uuidString
                let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
                photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
            }
            
//
//            photoSettings.isDepthDataDeliveryEnabled = (self.depthDataDeliveryMode == .on
//                && self.photoOutput.isDepthDataDeliveryEnabled)
//
//            photoSettings.isPortraitEffectsMatteDeliveryEnabled = (self.portraitEffectsMatteDeliveryMode == .on
//                && self.photoOutput.isPortraitEffectsMatteDeliveryEnabled)
//
//            if photoSettings.isDepthDataDeliveryEnabled {
//                if !self.photoOutput.availableSemanticSegmentationMatteTypes.isEmpty {
//                    photoSettings.enabledSemanticSegmentationMatteTypes = self.selectedSemanticSegmentationMatteTypes
//                }
//            }
//
//            photoSettings.photoQualityPrioritization = self.photoQualityPrioritizationMode
            
            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings) {
                DispatchQueue.main.async {
                    self.preview.videoPreviewLayer.opacity = 0
                    UIView.animate(withDuration: 0.25) {
                        self.preview.videoPreviewLayer.opacity = 1
                    }
                }
            } livePhotoCaptureHandler: { (capturing) in
                
            } completionHandler: { [weak self](photoCaptureProcessor) in
                guard let `self` = self else { return }
                self.sessionQueue.async {
                    self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                }
            } photoProcessingHandler: { (animate) in
                DispatchQueue.main.async {
                    if animate {
                        self.spinner.hidesWhenStopped = true
                        self.spinner.center = CGPoint(x: self.preview.frame.size.width / 2.0, y: self.preview.frame.size.height / 2.0)
                        self.spinner.startAnimating()
                    } else {
                        self.spinner.stopAnimating()
                    }
                }
            }

            
            // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
            self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        }
    }
    
    @IBAction func changeCamera(_ sender: UIButton) {
        [self.cameraBtn, self.photoBtn].forEach {
            $0.isEnabled = false
        }
        
        self.sessionQueue.async { [weak self] in
            guard let `self` = self else { return }
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            let preferredPosition: AVCaptureDevice.Position
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
            case .back:
                preferredPosition = .front
            @unknown default:
                print("Unknown capture position. Defaulting to back, dual-camera.")
                preferredPosition = .back
            }
            let devices = self.videoDeviceDiscoverySession.devices
            if let videoDevice = devices.first(where: { $0.position == preferredPosition }) {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.session.beginConfiguration()
                    self.session.removeInput(self.videoDeviceInput)
                    
                    if self.session.canAddInput(videoDeviceInput) {
                        self.session.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.session.addInput(self.videoDeviceInput)
                    }
                
//                    self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported
//                    self.photoOutput.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported
//                    self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = self.photoOutput.isPortraitEffectsMatteDeliverySupported
//                    self.photoOutput.enabledSemanticSegmentationMatteTypes = self.photoOutput.availableSemanticSegmentationMatteTypes
//                    self.selectedSemanticSegmentationMatteTypes = self.photoOutput.availableSemanticSegmentationMatteTypes
//                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                    
                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }
            DispatchQueue.main.async {
                self.cameraBtn.isEnabled = true
                self.photoBtn.isEnabled = true
                
            }
        }
    }
    
    private func getCaptureDevice(with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = self.videoDeviceDiscoverySession.devices
        return devices.first { $0.position == position }
    }

}

private enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}
