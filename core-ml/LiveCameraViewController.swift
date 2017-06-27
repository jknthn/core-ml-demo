//
//  LiveCameraViewController.swift
//  core-ml
//
//  Created by jeremi on 07/06/2017.
//  Copyright © 2017 jk. All rights reserved.
//

import UIKit
import CoreML
import Vision
import CoreMedia

class LiveCameraViewController: UIViewController {
    
    private var ageRequest: VNCoreMLRequest = {
        let model = try! VNCoreMLModel(for: AgeNet().model)
        return VNCoreMLRequest(model: model) { request, error in
            if let observation = request.results?.first as? VNClassificationObservation {
                print(observation.identifier)
                print(observation.confidence)
            }
        }
    }()
    
    private var genderRequest: VNCoreMLRequest = {
        let model = try! VNCoreMLModel(for: GenderNet().model)
        return VNCoreMLRequest(model: model) { request, error in
            if let observation = request.results?.first as? VNClassificationObservation {
                print(observation.identifier)
                print(observation.confidence)
            }
        }
    }()
    
    private var camera: LiveCamera!
    
    private let inputImageScale = 227
    private let predictionLabel = UILabel()
    private let displayView = UIView()
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDisplayView()
        setupLabel()
        camera = LiveCamera(view: displayView)
        camera.delegate = self
    }
    
    private func setupLabel() {
        predictionLabel.textColor = .white
        predictionLabel.font = UIFont.systemFont(ofSize: 20.0, weight: .light)
        predictionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(predictionLabel)
        predictionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        predictionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        predictionLabel.numberOfLines = 0
    }
    
    private func setupDisplayView() {
        displayView.frame = view.bounds
        view.insertSubview(displayView, at: 0)
        displayView.setNeedsLayout()
    }
}

extension LiveCameraViewController: LiveCameraDelegate {
    
    func didUpdateBuffer(_ buffer: CMSampleBuffer, on camera: LiveCamera) {
        let image = UIImage(buffer: CMSampleBufferGetImageBuffer(buffer)!)?
            .rescaled(width: inputImageScale, height: inputImageScale)
            .cgImage
        let handler = VNImageRequestHandler(cgImage: image!)
        try? handler.perform([ageRequest, genderRequest])
        
        
        
//        let agePred = try! ageNet.prediction(data: imageBuffer)
//        let ageString = agePred.classLabel
//        let ageProb = String(format: "%.2f", agePred.prob[ageString]! * 100.0)
//        let genderPred = try! genderNet.prediction(data: imageBuffer)
//        let genderString = genderPred.classLabel
//        let genderProb = String(format: "%.2f", genderPred.prob[genderString]! * 100.0)
        
//        DispatchQueue.main.async {
//            self.predictionLabel.text = """
//            Gender: \(genderString) prob: \(ageProb)%
//            Age: \(ageString) prob: \(genderProb)%
//            """
//        }
    }
}
