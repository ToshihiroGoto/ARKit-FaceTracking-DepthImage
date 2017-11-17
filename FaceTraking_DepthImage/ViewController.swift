//
//  ViewController.swift
//  FaceTraking
//
//  Created by Toshihiro Goto on 2017/11/15.
//  Copyright © 2017年 Toshihiro Goto. All rights reserved.
//

import UIKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // ARSCNView
    @IBOutlet var sceneView: ARSCNView!
    
    // UIImageView - Depth Image
    @IBOutlet weak var depthImageView: UIImageView!
    
    // Face Tracking の起点となるノードとジオメトリを格納するノード
    private var faceNode = SCNNode()
    private var virtualFaceNode = SCNNode()
    
    // シリアルキューの設定
    private let serialQueue = DispatchQueue(label: "com.test.FaceTracking.serialSceneKitQueue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Face Tracking が使えなければ、これ以下の命令を実行を実行しない
        guard ARFaceTrackingConfiguration.isSupported else { return }
    
        // Face Tracking アプリの場合、画面を触らない状況が続くため画面ロックを止める
        UIApplication.shared.isIdleTimerDisabled = true
        
        // ARSCNView と ARSession のデリゲート、周囲の光の設定
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // virtualFaceNode に ARSCNFaceGeometry を設定する
        let device = sceneView.device!
        let maskGeometry = ARSCNFaceGeometry(device: device)!
        
        maskGeometry.firstMaterial?.diffuse.contents = UIColor.lightGray
        maskGeometry.firstMaterial?.lightingModel = .physicallyBased
        
        virtualFaceNode.geometry = maskGeometry
        
        // トラッキングの初期化を実行
        resetTracking()
        
        // タップジェスチャ設定を呼び出す
        self.addTapGesture()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return true
    }

    // この ViewController が表示された場合にトラッキングの初期化する
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        resetTracking()
    }

    // この ViewController が非表示になった場合にセッションを止める
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    // Face Tracking の設定を行い
    // オプションにトラッキングのリセットとアンカーを全て削除してセッション開始
    func resetTracking() {
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // Face Tracking の起点となるノードの初期設定
    private func setupFaceNodeContent() {
        // faceNode 以下のチルドノードを消す
        for child in faceNode.childNodes {
            child.removeFromParentNode()
        }
        
        // マスクのジオメトリの入った virtualFaceNode をノードに追加する
        faceNode.addChildNode(virtualFaceNode)
    }
    
    // MARK: - ARSCNViewDelegate
    /// ARNodeTracking 開始
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        faceNode = node
        serialQueue.async {
            self.setupFaceNodeContent()
        }
    }
    
    /// ARNodeTracking 更新。ARSCNFaceGeometry の内容を変更する
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }

        let geometry = virtualFaceNode.geometry as! ARSCNFaceGeometry
        geometry.update(from: faceAnchor.geometry)
    }
    
    // MARK: - ARSessionDelegate
    /// エラーと中断処理
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            // 中断復帰後トラッキングを再開させる
            self.resetTracking()
        }
    }
    
    /// Depth Image の取得
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        //　15 fps で返り、それ以外は nil を返すため判別する
        guard let depth = frame.capturedDepthData?.depthDataMap else { return }
        
        //　CIImage で取得し傾きを変更する
        let ciImage = CIImage.init(cvImageBuffer: depth)
        depthImageView.image = UIImage.init(ciImage:
            ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!)
        )
    }
}

// MARK: - UIImagePickerController

extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    // タップジェスチャ設定
    func addTapGesture(){
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    // タップジェスチャ動作時の関数
    @objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        
        if (UIImagePickerController.isSourceTypeAvailable(.photoLibrary) != false) {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            self.present(picker, animated:true, completion:nil)
        }else{
            print("fail")
        }
    }
    
    // フォトライブラリで画像選択時の処理
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        // オリジナルサイズの画像を選択
        let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage
        
        // マスクにテクスチャを反映させる
        virtualFaceNode.geometry?.firstMaterial?.diffuse.contents = pickedImage

        // UIImagePickerController を閉じる
        dismiss(animated: true, completion: nil)
    }
    
    // フォトライブラリでキャンセルタップ時の処理
    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // UIImagePickerController を閉じる
        dismiss(animated: true, completion: nil)
    }
}
