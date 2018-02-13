//
//  PrimitivesScene.swift
//  DevAppBeta
//
//  Created by Weihang Liu on 13/2/18.
//  Copyright © 2018 Weihang Liu. All rights reserved.
//

import UIKit
import SceneKit

class PrimitivesScene: SCNScene {
    private let boxGeo = SCNBox(width: 0.5, height: 0.2, length: 1.0, chamferRadius: 10)
    private var boxNode:SCNNode
    
    override init(){
        boxNode = SCNNode(geometry: boxGeo)
        super.init()
        self.initBox()
    }
    
    func initBox(){
        self.rootNode.addChildNode(boxNode)
    }
    
    func rotateNodeWithQuat(quat:[Double]){
        let w = quat[0]
        let x = quat[1]
        let z = -quat[2]
        let y = quat[3]
        let quatadapt = SCNQuaternion(x,y,z,w)
        self.boxNode.orientation = quatadapt
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
