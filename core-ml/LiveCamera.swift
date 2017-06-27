//
//  LiveCamera.swift
//  core-ml
//
//  Created by jeremi on 27/06/2017.
//  Copyright © 2017 jk. All rights reserved.
//

import AVFoundation
import UIKit

protocol LiveCameraDelegate: class {
    func didUpdateBuffer(_ buffer: CMSampleBuffer, on camera: LiveCamera)
}

class LiveCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var delegate: LiveCameraDelegate?
    private var session: AVCaptureSession!
    
    init(view: UIView) {
        super.init()
        
        var backCameraDevice: AVCaptureDevice!
        session = AVCaptureSession()
        
        let availableCameraDevices = AVCaptureDevice.devices(for: .video) as [AVCaptureDevice]
        for device in availableCameraDevices {
            if device.position == .back {
                backCameraDevice = device
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
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
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
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.didUpdateBuffer(sampleBuffer, on: self)
    }
}

