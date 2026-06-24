//
//  MetalView.swift
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
    
    @Binding var settings: Settings
    
    func makeNSView(context: Context) -> some NSView {
        let view = MetalMtkView()
        view.callback = { x in
            settings.pull.cam_dist += x
        }
        context.coordinator.renderer = Renderer(view: view, settings: $settings)
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var renderer: Renderer?
    }
}
