import UIKit
import AVFoundation
import CoreGraphics

class LiveCameraViewController: UIViewController {
    
    private var session: AVCaptureSession!
    
    private let classifier = Resnet50()
    private let inputImageScale = 224
    
    private let predictionLabel = UILabel()
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLabel()
        setupCamera()
    }
    
    private func setupLabel() {
        predictionLabel.textColor = .black
        predictionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(predictionLabel)
        predictionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        predictionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20.0).isActive = true
    }
    
    private func setupCamera() {
        var frontCameraDevice: AVCaptureDevice!
        var backCameraDevice: AVCaptureDevice!
        session = AVCaptureSession()
        
        let availableCameraDevices = AVCaptureDevice.devices(for: .video) as [AVCaptureDevice]
        for device in availableCameraDevices {
            if device.position == .back {
                backCameraDevice = device
            } else if device.position == .front {
                frontCameraDevice = device
            }
        }
        
        var possibleCameraInput: AnyObject?
        do {
            possibleCameraInput = try AVCaptureDeviceInput.init(device: backCameraDevice)
        } catch let error as NSError{
            print(error)
        }
        
        if let backCameraInput = possibleCameraInput as? AVCaptureDeviceInput {
            if session.canAddInput(backCameraInput) {
                session.addInput(backCameraInput)
            }
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session) as AVCaptureVideoPreviewLayer
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate", qos: DispatchQoS.userInitiated))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        session.sessionPreset = .photo
        let sessionQueue = DispatchQueue(label: "com.example.camera.capture.session", qos: DispatchQoS.userInitiated)
        sessionQueue.async {
            self.session.startRunning()
        }
    }
}

extension LiveCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let rescaled = rescaledImageRectangle(createUIImage(from: imageBuffer), dimension: inputImageScale)
        let rescaledBuffer = createCVPixelBuffer(from: rescaled)
        
        guard let prediction = try? classifier.prediction(image: rescaledBuffer!) else { return }
        DispatchQueue.main.async {
            self.predictionLabel.text = prediction.classLabel
        }
    }
    
    private func createUIImage(from buffer: CVImageBuffer?) -> UIImage {
        let ciImage = CIImage(cvImageBuffer: buffer!)
        let ciContext = CIContext(options: nil)
        let videoImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer!), height: CVPixelBufferGetHeight(buffer!)))
        return UIImage(cgImage: videoImage!)
    }
    
    private func rescaledImageRectangle(_ image: UIImage, dimension: Int) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: dimension, height: dimension), true, 1.0)
        image.draw(in: CGRect(x: 0, y: 0, width: dimension, height: dimension))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private func createCVPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}
