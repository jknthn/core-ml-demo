import UIKit
import AVFoundation
import CoreGraphics
import CoreML

class LiveCameraViewController: UIViewController {
    
    private var session: AVCaptureSession!
    
    private let ageNet = AgeNet()
    private let genderNet = GenderNet()
    
    private let inputImageScale = 227
    
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
        predictionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        predictionLabel.numberOfLines = 0
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
        let rescaledBuffer = createCVPixelBuffer(from: rescaled)!
        
        let age = try! ageNet.prediction(data: rescaledBuffer)
        let a = predictAge(data: age.prob)
        let gender = try! genderNet.prediction(data: rescaledBuffer)
        let g = predictGender(data: gender.prob)
        DispatchQueue.main.async {
            self.predictionLabel.text = "Gender: \(g.0), prob: \(Int(g.1 * 100))%\nAge: \(a.0), prob: \(Int(g.1 * 100))%"
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
    
    private func predictGender(data: MLMultiArray) -> (String, Double) {
        let genders = ["Male", "Female"]
        var probs: [Double] = []
        for i in 0..<genders.count {
            probs.append(data[i].doubleValue)
        }
        let maxProb = probs.max()!
        let index = probs.index(of: maxProb)!
        
        return (genders[index], maxProb)
    }
    
    private func predictAge(data: MLMultiArray) -> (String, Double) {
        let ages = ["(0, 2)", "(4, 6)", "(8, 12)", "(15, 20)", "(25, 32)", "(38, 43)", "(48, 53)", "(60, 100)"]
        var probs: [Double] = []
        for i in 0..<ages.count {
            probs.append(data[i].doubleValue)
        }
        let maxProb = probs.max()!
        let index = probs.index(of: maxProb)!
        
        return (ages[index], maxProb)
    }
    
}
