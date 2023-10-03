// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import AVFoundation
import Vision
import Combine
import LocalAuthentication

public class VisionLock: NSObject, ObservableObject {
    
    @Published private var facePresent: Bool = false
    private var oldValue: Bool = false
    private var observers = Set<AnyCancellable>()
    
    private var session: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var captureDeviceResolution: CGSize = CGSize()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    public override init() {
        super.init()
        setupObservers()
        setupNotifications()
    }
    
    public func start() async throws {
        do {
            endMonitoring()
            if try await LAContext().faceID(reason: "Making sure it's you!") {
                try beginMonitoring()
            }
        } catch {
            throw error
        }
    }
    
    private func beginMonitoring() throws {
        session = try setupAVCaptureSession()
        prepareVisionRequest()
        session?.startRunning()
    }
    
    private func endMonitoring() {
        trackingRequests = nil
        detectionRequests = nil
        videoDataOutputQueue = nil
        videoDataOutput = nil
        captureDeviceResolution = .init()
        captureDevice = nil
        session = nil
    }
}

// MARK: - Observers and Notifications
extension VisionLock {
    private func setupObservers() {
        $facePresent.sink { newValue in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, newValue != self.oldValue else { return }
                if !newValue {
                    Task { [weak self] in
                        NotificationCenter.default.post(name: .faceNotPresent, object: nil)
                        try? await self?.start()
                    }
                } else {
                    NotificationCenter.default.post(name: .facePresent, object: nil)
                }
                self.oldValue = newValue
            }
        }.store(in: &observers)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.endMonitoring()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            Task { [weak self] in
                try? await self?.start()
            }
        }
    }
}

// MARK: - AVCapture Setup
extension VisionLock {
    private func setupAVCaptureSession() throws -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        let inputDevice = try configureFrontCamera(for: captureSession)
        configureVideoDataOutput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
        return captureSession
    }
    
    private func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            let deviceFormatDescription = deviceFormat.formatDescription
            let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
            if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                highestResolutionFormat = deviceFormat
                highestResolutionDimensions = candidateDimensions
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    private func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            let deviceInput = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
            
            if let highestResolution = highestResolution420Format(for: device) {
                try device.lockForConfiguration()
                device.activeFormat = highestResolution.format
                device.unlockForConfiguration()
                
                return (device, highestResolution.resolution)
            }
            return (device, .init(width: 420, height: 420))
        }
        throw NSError(domain: "No Device Found", code: 1, userInfo: nil)
    }
    
    private func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        let videoDataOutputQueue = DispatchQueue(label: "com.example.apple-samplecode.VisionFaceTrack")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        captureDevice = inputDevice
        captureDeviceResolution = resolution
    }
}

// MARK: - Vision Handling
extension VisionLock {
    private func prepareVisionRequest() {
        var requests = [VNTrackObjectRequest]()
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest, let results = faceDetectionRequest.results else { return }
            DispatchQueue.main.async {
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        self.detectionRequests = [faceDetectionRequest]
        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension VisionLock: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        do {
            var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
            let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
            if cameraIntrinsicData != nil {
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
            }
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let exifOrientation = CGImagePropertyOrientation.upMirrored
            guard let requests = self.trackingRequests, !requests.isEmpty else {
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestHandlerOptions)
                guard let detectRequests = self.detectionRequests else { return }
                try imageRequestHandler.perform(detectRequests)
                return
            }
            
            try self.sequenceRequestHandler.perform(requests, on: pixelBuffer, orientation: exifOrientation)
            var newTrackingRequests = [VNTrackObjectRequest]()
            for trackingRequest in requests {
                guard let results = trackingRequest.results else { return }
                guard let observation = results[0] as? VNDetectedObjectObservation else { return }
                if !trackingRequest.isLastFrame {
                    if observation.confidence > 0.3 {
                        trackingRequest.inputObservation = observation
                    } else {
                        trackingRequest.isLastFrame = true
                    }
                    newTrackingRequests.append(trackingRequest)
                }
            }
            DispatchQueue.main.async {
                self.facePresent = newTrackingRequests.count == 1
            }
        } catch {
            return
        }
    }
}
