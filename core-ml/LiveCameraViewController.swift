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
    
    private var isMale = true
    
    private var camera: LiveCamera!
    
    private let inputImageScale = 227
    private let displayView = UIView()
    
    private let ageModel = try! VNCoreMLModel(for: AgeNet().model)
    private let genderModel = try! VNCoreMLModel(for: GenderNet().model)
    
    private let color0Gender = UIColor(colorLiteralRed: 137.0 / 255.0, green: 139.0 / 255.0, blue: 252.0 / 255.0, alpha: 1.0)
    private let color1Gender = UIColor(colorLiteralRed: 244.0 / 255.0, green: 144.0 / 255.0, blue: 191.0 / 255.0, alpha: 1.0)
    
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
        var editedLabel = label
        [" ", "(", ")"].forEach {
            editedLabel = editedLabel.replacingOccurrences(of: $0, with: "")
        }
        let ranges = editedLabel.split(separator: ",")
        let genderText = NSAttributedString(string: isMale ? "And he's " : "And she's ")
        let coloredPrediction = NSAttributedString(
            string: "\(ranges[0])-\(ranges[1])",
            attributes: [.foregroundColor : isMale ? color0Gender : color1Gender]
        )
        let dot = NSAttributedString(string: ".")
        
        let combination = NSMutableAttributedString(attributedString: genderText)
        combination.append(coloredPrediction)
        combination.append(dot)
        
        ageClassLabel.attributedText = combination
        ageProbLabel.text = "This I am \(Int(confidence * 100.0))% sure."
    }
    
    func updateGender(label: String, confidence: Float) {
        isMale = label == "Male"
        
        let genderText = NSAttributedString(string: isMale ? "He is " : "She is ")
        let coloredPrediction = NSAttributedString(
            string: isMale ? "man" : "woman",
            attributes: [.foregroundColor : isMale ? color0Gender : color1Gender]
        )
        let dot = NSAttributedString(string: ".")
        
        let combination = NSMutableAttributedString(attributedString: genderText)
        combination.append(coloredPrediction)
        combination.append(dot)
        
        genderClassLabel.attributedText = combination
        genderProbLabel.text = "I'm \(Int(confidence * 100.0))% sure."
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
