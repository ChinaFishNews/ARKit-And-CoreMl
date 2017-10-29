//
//  ViewController.swift
//  ARKit And CoreMl
//
//  Created by 新闻 on 2017/10/18.
//  Copyright © 2017年 Lvmama. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    // 创建模型
    var resentModel = Resnet50()
    // 点击之后的结果
    var hitTestResult: ARHitTestResult!
    // 分析结果(数组)
    var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // 给场景添加手势
        registerGestureRecognizers()
    }
    
    // 给场景添加手势
    func registerGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target:self, action:#selector(tapped))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    // 点击场景
    @objc func tapped(tapGesture:UITapGestureRecognizer) {
        // 清空场景中视图
        for node in self.sceneView.scene.rootNode.childNodes {
            node.removeFromParentNode()
        }
        
        let sceneView = tapGesture.view as! ARSCNView
//        let touchLocation = sceneView.center
        let touchLocation = tapGesture.location(in: self.sceneView)
        guard let currentFrame = sceneView.session.currentFrame else {
            fatalError("当前没有像素")
        }
        // 识别物件的特征点
        let hitTestResults = sceneView.hitTest(touchLocation, types: .featurePoint)
        if hitTestResults.isEmpty { return }
        guard let hitTestResult = hitTestResults.first else {
            fatalError("不是第一物件")
        }
        // 拿到点击的结果
        self.hitTestResult = hitTestResult;
        // 将拿到的图片转成像素
        let pixelBuffer = currentFrame.capturedImage;
        
        // 通过Vision处理
        performVisonRequest(pixelBuffer: pixelBuffer)
    }
    
    // 通过Vision处理
    func performVisonRequest(pixelBuffer:CVPixelBuffer) {
        let visionModel = try! VNCoreMLModel(for:self.resentModel.model)
        let request:VNCoreMLRequest = VNCoreMLRequest(model:visionModel) { request,error in
            if error != nil { return }
            guard let observations = request.results else {
                fatalError("没有结果")
            }
            // 对结果中的第一个进行分析
            let observation = observations.first as! VNClassificationObservation
            print("name is \(observation.identifier) \n confidence is \(observation.confidence)")
            
            DispatchQueue.main.async {
               //刷新UI
                self.displayPredictions(text: "\(observation.identifier)")
            }
        }
        request.imageCropAndScaleOption = .centerCrop;
        // 拿到结果
        visionRequests = [request]
        // 将拿到的结果左右翻转
        let imageRequestHandler:VNImageRequestHandler = VNImageRequestHandler(cvPixelBuffer:pixelBuffer,orientation:.upMirrored,options:[:])
        // 处理所有的结果
        DispatchQueue.global().async {
            try? imageRequestHandler.perform(self.visionRequests)
        }
    }
    
    // 展示预测结果
    func displayPredictions(text:String)  {
        let parentNode = SCNNode()
        
        // 1cm的小球底座
        let sphere = SCNSphere(radius:0.01)
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = UIColor.orange
        sphere.firstMaterial = sphereMaterial
        // 创建一个球状的节点
        let sphereNode = SCNNode(geometry:sphere)
        parentNode.addChildNode(sphereNode)
        
        // 文字展示
        let textGeo = SCNText(string:text,extrusionDepth:0)
        textGeo.alignmentMode = kCAAlignmentCenter
        textGeo.firstMaterial?.diffuse.contents = UIColor.orange
        textGeo.firstMaterial?.specular.contents = UIColor.white
        textGeo.firstMaterial?.isDoubleSided = true
        textGeo.font = UIFont(name:"Futura",size:0.20)
        
        print("x=\(self.hitTestResult.worldTransform.columns.3.x)")
        print("y=\(self.hitTestResult.worldTransform.columns.3.y)")
        print("z=\(self.hitTestResult.worldTransform.columns.3.z)")
        
        // 创建文字节点
        let textNode = SCNNode(geometry:textGeo)
        textNode.position = SCNVector3(x:self.hitTestResult.worldTransform.columns.3.x,
                                       y:self.hitTestResult.worldTransform.columns.3.y,
                                       z:self.hitTestResult.worldTransform.columns.3.z)
        textNode.scale = SCNVector3Make(0.2,0.2,0.2)
        parentNode.addChildNode(textNode)
        
        // 把模型展示在我们点击的位置
        parentNode.position = SCNVector3(x:self.hitTestResult.worldTransform.columns.3.x,
                                         y:self.hitTestResult.worldTransform.columns.3.y,
                                         z:self.hitTestResult.worldTransform.columns.3.z)
        // 展示AR结果
        self.sceneView.scene.rootNode.addChildNode(parentNode)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
