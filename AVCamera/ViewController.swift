//
//  ViewController.swift
//  AVCamera
//
//  Created by 马陈爽 on 2021/1/10.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    private let cellId = "UITableViewCellId"
    
    private let features: [CameraFeatures] = [.photoOutput, .bracketed]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellId)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return features.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellId, for: indexPath)
        cell.textLabel?.text = features[indexPath.row].rawValue
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let feature = self.features[indexPath.row]
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "CameraViewController") as! CameraViewController
        vc.modalPresentationStyle = .fullScreen
        switch feature {
        case .photoOutput:
            break
        case .bracketed:
            vc.bracketedEnable = true
        }
        self.present(vc, animated: true, completion: nil)
    }
    
    
}

enum CameraFeatures: String {
    case photoOutput = "AVCapturePhotoOutput 生命周期"
    case bracketed = "分级捕获"
    
}

