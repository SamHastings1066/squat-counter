//
//  ViewController.swift
//  Squat Counter
//
//  Created by sam hastings on 08/07/2023.
//

import UIKit
import AVFoundation
import MLImage
import MLKit

class ViewController: UIViewController {
    
    
    private var isUsingFrontCamera = true
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
    private var lastFrame: CMSampleBuffer?
    
    //private var captureSession: AVCaptureSession?
//    private var videoOutput: AVCaptureVideoDataOutput?
    
//    private var poseDetector: PoseDetector? = nil
//    private var previewLayer: AVCaptureVideoPreviewLayer!
//    private lazy var captureSession = AVCaptureSession()
//    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
//    private var lastFrame: CMSampleBuffer?
    
    private lazy var previewOverlayView: UIImageView = {

      precondition(isViewLoaded)
      let previewOverlayView = UIImageView(frame: .zero)
      previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
      previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
      return previewOverlayView
    }()

    private lazy var annotationOverlayView: UIView = {
      precondition(isViewLoaded)
      let annotationOverlayView = UIView(frame: .zero)
      annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
      return annotationOverlayView
    }()
    
    private var poseDetector: PoseDetector? = nil

    //MARK: - IBOutlets
    
    @IBOutlet weak var cameraView: UIView!
    
    //MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setUpPreviewOverlayView()
        setUpAnnotationOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
        
//        // Base pose detector with streaming, when depending on the PoseDetection SDK
//        let options = PoseDetectorOptions()
//        options.detectorMode = .stream
//        poseDetector = PoseDetector.poseDetector(options: options)
        let options = PoseDetectorOptions()
        self.poseDetector = PoseDetector.poseDetector(options: options)
        
        //setupCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)

      startSession()
    }

    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)

      stopSession()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()

      previewLayer.frame = cameraView.frame
    }
    
    
    //MARK: - On-device detection
    
    
    private func detectPose(in image: MLImage, width: CGFloat, height: CGFloat) {
      if let poseDetector = self.poseDetector {
        var poses: [Pose] = []
        var detectionError: Error?
        do {
          poses = try poseDetector.results(in: image)
        } catch let error {
          detectionError = error
        }
        weak var weakSelf = self
        DispatchQueue.main.sync {
          guard let strongSelf = weakSelf else {
            print("Self is nil!")
            return
          }
          strongSelf.updatePreviewOverlayViewWithLastFrame()
          if let detectionError = detectionError {
            print("Failed to detect poses with error: \(detectionError.localizedDescription).")
            return
          }
          guard !poses.isEmpty else {
            print("Pose detector returned no results.")
            return
          }

          // Pose detected. Currently, only single person detection is supported.
          poses.forEach { pose in
            let poseOverlayView = UIUtilities.createPoseOverlayView(
              forPose: pose,
              inViewWithBounds: strongSelf.annotationOverlayView.bounds,
              lineWidth: Constant.lineWidth,
              dotRadius: Constant.smallDotRadius,
              positionTransformationClosure: { (position) -> CGPoint in
                return strongSelf.normalizedPoint(
                  fromVisionPoint: position, width: width, height: height)
              }
            )
            strongSelf.annotationOverlayView.addSubview(poseOverlayView)
            
//            let leftHip = pose.landmark(ofType: .leftHip)
//            let leftKnee = pose.landmark(ofType: .leftKnee)
//
//            let hipPosition = leftHip.position
//            let kneePosition = leftKnee.position
//
//            // We only care about 2D (x and y) here
//            let deltaY = kneePosition.y - hipPosition.y
//            let deltaX = kneePosition.x - hipPosition.x
//              
//            // Compute the angle in degrees
//            let angleInDegrees = atan2(deltaY, deltaX) * 180.0 / .pi
//
//            // Note: The result of atan2(y, x) is the angle in radians counterclockwise from the x-axis to the point (x, y).
//            // If the person is standing upright and the camera is at a normal angle, the hip will usually be higher in the image than the knee, meaning the y value will be smaller (since in most computer graphics coordinate systems, y values get larger going down the screen). Therefore, deltaY might often be negative, and the resulting angle might be more than 180. You may need to subtract the result from 360 to get the angle relative to a horizontal line.
//            
//            let correctedAngle = 360 - angleInDegrees
//            print("Angle between femur and horizontal is \(correctedAngle)")
              

//                          // Example: get the left shoulder landmark
//                          let leftShoulder = pose.landmark(ofType: .leftShoulder)
//                          // Use the landmark for something, e.g.:
//                          print("Left shoulder position: \(leftShoulder.position)")
//                          print("Left shoulder in frame likelihood: \(leftShoulder.inFrameLikelihood)")
              ////            print(pose.landmarks)

          }
        }
      }
    }
    

    
    //MARK: - Private
    
    private func setUpCaptureSessionOutput() {
      weak var weakSelf = self
      sessionQueue.async {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        strongSelf.captureSession.beginConfiguration()
        // When performing latency tests to determine ideal capture settings,
        // run the app in 'release' mode to get accurate performance metrics
        strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.medium

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
          (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
        output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
        guard strongSelf.captureSession.canAddOutput(output) else {
          print("Failed to add capture session output.")
          return
        }
        strongSelf.captureSession.addOutput(output)
        strongSelf.captureSession.commitConfiguration()
      }
    }

    private func setUpCaptureSessionInput() {
      weak var weakSelf = self
      sessionQueue.async {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        let cameraPosition: AVCaptureDevice.Position = strongSelf.isUsingFrontCamera ? .front : .back
        guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
          print("Failed to get capture device for camera position: \(cameraPosition)")
          return
        }
        do {
          strongSelf.captureSession.beginConfiguration()
          let currentInputs = strongSelf.captureSession.inputs
          for input in currentInputs {
            strongSelf.captureSession.removeInput(input)
          }

          let input = try AVCaptureDeviceInput(device: device)
          guard strongSelf.captureSession.canAddInput(input) else {
            print("Failed to add capture session input.")
            return
          }
          strongSelf.captureSession.addInput(input)
          strongSelf.captureSession.commitConfiguration()
        } catch {
          print("Failed to create capture device input: \(error.localizedDescription)")
        }
      }
    }
    
    private func startSession() {
      weak var weakSelf = self
      sessionQueue.async {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        strongSelf.captureSession.startRunning()
      }
    }

    private func stopSession() {
      weak var weakSelf = self
      sessionQueue.async {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        strongSelf.captureSession.stopRunning()
      }
    }
    
    private func setUpPreviewOverlayView() {
      cameraView.addSubview(previewOverlayView)
      NSLayoutConstraint.activate([
        previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
        previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
        previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
        previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),

      ])
    }

    private func setUpAnnotationOverlayView() {
      cameraView.addSubview(annotationOverlayView)
      NSLayoutConstraint.activate([
        annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
        annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
        annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
        annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
      ])
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
      if #available(iOS 10.0, *) {
        let discoverySession = AVCaptureDevice.DiscoverySession(
          deviceTypes: [.builtInWideAngleCamera],
          mediaType: .video,
          position: .unspecified
        )
        return discoverySession.devices.first { $0.position == position }
      }
      return nil
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
      guard let lastFrame = lastFrame,
        let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
      else {
        return
      }
      self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
      self.removeDetectionAnnotations()
    }
    
    private func removeDetectionAnnotations() {
      for annotationView in annotationOverlayView.subviews {
        annotationView.removeFromSuperview()
      }
    }
    
    private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
      guard let imageBuffer = imageBuffer else {
        return
      }
      let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
      let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
      previewOverlayView.image = image
    }
    
    private func normalizedPoint(
      fromVisionPoint point: VisionPoint,
      width: CGFloat,
      height: CGFloat
    ) -> CGPoint {
      let cgPoint = CGPoint(x: point.x, y: point.y)
      var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
      normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
      return normalizedPoint
    }
}

//MARK: - Extensions



extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("Failed to get image buffer from sample buffer.")
      return
    }

    lastFrame = sampleBuffer
    let visionImage = VisionImage(buffer: sampleBuffer)
    let orientation = UIUtilities.imageOrientation(
      fromDevicePosition: isUsingFrontCamera ? .front : .back
    )
    visionImage.orientation = orientation

    guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
      print("Failed to create MLImage from sample buffer.")
      return
    }
    inputImage.orientation = orientation

    let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
    let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
      
    detectPose(in: inputImage, width: imageWidth, height: imageHeight)

  }
}


//MARK: - Constants

//TODO: remove unused constants
private enum Constant {
//  static let alertControllerTitle = "Vision Detectors"
//  static let alertControllerMessage = "Select a detector"
//  static let cancelActionTitleText = "Cancel"
  static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
  static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
//  static let noResultsMessage = "No Results"
//  static let localModelFile = (name: "bird", type: "tflite")
//  static let labelConfidenceThreshold = 0.75
  static let smallDotRadius: CGFloat = 4.0
  static let lineWidth: CGFloat = 3.0
//  static let originalScale: CGFloat = 1.0
//  static let padding: CGFloat = 10.0
//  static let resultsLabelHeight: CGFloat = 200.0
//  static let resultsLabelLines = 5
//  static let imageLabelResultFrameX = 0.4
//  static let imageLabelResultFrameY = 0.1
//  static let imageLabelResultFrameWidth = 0.5
//  static let imageLabelResultFrameHeight = 0.8
//  static let segmentationMaskAlpha: CGFloat = 0.5
}
