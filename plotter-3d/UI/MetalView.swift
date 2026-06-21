//
//  MetalView.swift
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    
    var cam_pitch: Float
    var cam_yaw: Float
    var fun: String
    var smoothGradient: Bool
    
    var resolution_graph: Float
    var resolution_grid_lines: Float
    var resolution_grid_segments: Float
    
    func makeNSView(context: Context) -> some NSView {
        let view = MetalMtkView()
        context.coordinator.renderer = Renderer(
            view: view,
            fun_str: fun,
            resolution_graph: Int(resolution_graph),
            resolution_grid_lines: Int(resolution_grid_lines),
            resolution_grid_segments: Int(resolution_grid_segments),
            smoothGradient: smoothGradient,
            cam_dist: 5,
            cam_pitch: cam_pitch,
            cam_yaw: cam_yaw,
        )
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let r = context.coordinator.renderer else {
            print("no coordinator")
            return
        }
        
        // have to modify buffer data (push once)
        r.updateMeshPipeline(fun)
        r.setResolutions(
            resolution_graph: Int(resolution_graph),
            resolution_grid_lines: Int(resolution_grid_lines),
            resolution_grid_segments: Int(resolution_grid_segments),
        )
        
        // automatically updated (polled every frame)
        r.cam_pitch = cam_pitch
        r.cam_yaw = cam_yaw
        r.smoothGradient = smoothGradient
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var renderer: Renderer?
    }
}
