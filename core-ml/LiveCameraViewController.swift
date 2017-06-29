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
    
    @IBOutlet weak var genderClassLabel: UILabel!
    @IBOutlet weak var genderProbLabel: UILabel!
    @IBOutlet weak var ageClassLabel: UILabel!
    @IBOutlet weak var ageProbLabel: UILabel!
    
    private var camera: LiveCamera!
    
    private let inputImageScale = 227
    private let displayView = UIView()
    
    private let ageModel = try! VNCoreMLModel(for: AgeNet().model)
    private let genderModel = try! VNCoreMLModel(for: GenderNet().model)
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.statusBarStyle = .lightContent
        setupDisplayView()
        camera = LiveCamera(view: displayView)
        camera.delegate = self
    }
    
    private func setupDisplayView() {
        displayView.frame = view.bounds
        view.insertSubview(displayView, at: 0)
        displayView.setNeedsLayout()
    }
    
    // MARK: - CoreML & Vision utils
    
    func createAgeRequest() -> VNCoreMLRequest {
        return VNCoreMLRequest(model: ageModel, completionHandler: onClassification)
    }
    
    func createGenderRequest() -> VNCoreMLRequest {
        return VNCoreMLRequest(model: genderModel, completionHandler: onClassification)
    }
    
    func onClassification(request: VNRequest, error: Error?) {
        guard
            let results = request.results as? [VNClassificationObservation],
            let result = results.first
        else {
                return
        }
        DispatchQueue.main.async { [weak self] in
            if results.count == 2 { // Gender
                self?.updateGender(label: result.identifier, confidence: result.confidence)
            } else { // Age
                self?.updateAge(label: result.identifier, confidence: result.confidence)
            }
        }
    }
    
    func updateAge(label: String, confidence: Float) {
        print(#function)
        print(label)
    }
    
    func updateGender(label: String, confidence: Float) {
        print(#function)
        print(label)
    }
}

extension LiveCameraViewController: LiveCameraDelegate {
    
    func didUpdateBuffer(_ buffer: CMSampleBuffer, on camera: LiveCamera) {
        let image = UIImage(buffer: CMSampleBufferGetImageBuffer(buffer)!)?
            .rescaled(width: inputImageScale, height: inputImageScale)
            .cgImage
        let handler = VNImageRequestHandler(cgImage: image!)
        try? handler.perform([createAgeRequest(), createGenderRequest()])
    }
}
