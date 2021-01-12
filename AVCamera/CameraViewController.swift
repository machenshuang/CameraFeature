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
    
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var setupResult: SessionSetupResult = .success
    private let photoOutput = AVCapturePhotoOutput()
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    
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
    
    private func configureSession() {
        if self.setupResult != .success {
            return
        }
        
        self.session.beginConfiguration()
        self.session.sessionPreset = .photo
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // Choose the back dual camera, if available, otherwise default to a wide angle camera.
            
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) {
                // If the rear wide angle camera isn't available, default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }
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
            //self.photoOutput.isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureSupported
            //self.photoOutput.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported
            //self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = self.photoOutput.isPortraitEffectsMatteDeliverySupported
            self.photoOutput.enabledSemanticSegmentationMatteTypes = self.photoOutput.availableSemanticSegmentationMatteTypes
            
            //self.photoOutput.maxPhotoQualityPrioritization = .quality
//            livePhotoMode = photoOutput.isLivePhotoCaptureSupported ? .on : .off
//            depthDataDeliveryMode = photoOutput.isDepthDataDeliverySupported ? .on : .off
//            portraitEffectsMatteDeliveryMode = photoOutput.isPortraitEffectsMatteDeliverySupported ? .on : .off
//            photoQualityPrioritizationMode = .balanced
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

}

private enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}
