//
//  MetalMtkView.swift
//  plotter-3d
//
//  Created by Yan Amin on 16.06.26.
//

import MetalKit

class MetalMtkView: MTKView {
    var renderer: Renderer?
    
    var callback: ((Float) -> Void)?
    
    override func scrollWheel(with event: NSEvent) {
        callback?(-Float(event.deltaY) * 0.01)
    }
}
