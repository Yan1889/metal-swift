//
//  ContentView.swift
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

import SwiftUI

struct ContentView: View {
    
    @State var last_point: CGPoint?
    
    @State var cam_pitch: Float = 0
    @State var cam_yaw: Float = 0
    
    @State var fun: String = "x * x - z * z + 1"
    @State var smoothGradient = true
    
    @State var resolution_graph: Float = 100
    @State var resolution_grid_lines: Float = 10
    @State var resolution_grid_segments: Float = 100
    
    var body: some View {
        HStack {
            SettingsPanel(
                smoothGradient: $smoothGradient,
                resolution_graph: $resolution_graph,
                resolution_grid_lines: $resolution_grid_lines,
                resolution_grid_segments: $resolution_grid_segments,
                fun: $fun,
            )
                .frame(width: 500)
                .padding()
            
            MetalView(
                cam_pitch: cam_pitch,
                cam_yaw: cam_yaw,
                fun: fun,
                smoothGradient: smoothGradient,
                resolution_graph: resolution_graph,
                resolution_grid_lines: resolution_grid_lines,
                resolution_grid_segments: resolution_grid_segments,
            )
                .frame(width: 800, height: 800)
                .gesture(
                    DragGesture()
                        .onChanged { e in
                            cam_yaw -= Float((e.location.x - (last_point ?? e.startLocation).x) / 900.0)
                            cam_pitch += Float((e.location.y - (last_point ?? e.startLocation).y) / 900.0)
                            last_point = e.location
                        }
                        .onEnded { _ in
                            last_point = nil
                        }
                )
        }
    }
}

#Preview {
    ContentView()
}
