//
//  MetalMtkView.swift
//  plotter-3d
//
//  Created by Yan Amin on 16.06.26.
//

import MetalKit

class MetalMtkView: MTKView {
    
    var renderer: Renderer?
    
    override func scrollWheel(with event: NSEvent) {
        let dd = -Float(event.deltaY) * 0.01
        renderer!.cam_dist += dd
    }
}
