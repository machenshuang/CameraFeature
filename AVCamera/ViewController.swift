//
//  ViewController.swift
//  AVCamera
//
//  Created by 马陈爽 on 2021/1/10.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
    }
}

enum CameraFeatures: String {
    case camera = "人像模式"
    
}

