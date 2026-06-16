//
//  MetalView.swift
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    
    var cam_pitch: Float = 0
    var cam_yaw: Float = 0
    
    func makeNSView(context: Context) -> some NSView {
        let view = MetalMtkView()
        context.coordinator.renderer = Renderer(view: view)
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        context.coordinator.renderer?.cam_pitch = cam_pitch
        context.coordinator.renderer?.cam_yaw = cam_yaw
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var renderer: Renderer?
    }
}
