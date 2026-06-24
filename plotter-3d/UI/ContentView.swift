//
//  ContentView.swift
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

import SwiftUI

struct ContentView: View {
    
    @State var isBlackHole = false
    
    @State var last_point: CGPoint?
    
    @State var settings = Settings(
        push: PushSettings(
            resolution_graph: 100,
            resolution_grid_lines: 10,
            resolution_grid_segments: 100,
            grid_thickness: 0.01,
            fun: "x * x - z * z + 1",
        ),
        pull: PullSettings(
            cam_pitch: 0,
            cam_yaw: 0,
            cam_dist: 5,
            compiled: true,
        )
    )
    
    var switchText: String {
        isBlackHole ? "function plotter" : "black hole simulation"
    }
    
    var body: some View {
        Button("Switch to \(switchText)") {
            isBlackHole.toggle()
        }
        if isBlackHole {
            BlackHole()
        } else {
            HStack {
                SettingsPanel(settings: $settings)
                    .frame(width: 500)
                    .padding()
                
                MetalView(settings: $settings)
                    .frame(width: 800, height: 800)
                    .gesture(
                        DragGesture()
                            .onChanged { e in
                                settings.pull.cam_yaw -= Float((e.location.x - (last_point ?? e.startLocation).x) / 900.0)
                                settings.pull.cam_pitch += Float((e.location.y - (last_point ?? e.startLocation).y) / 900.0)
                                last_point = e.location
                            }
                            .onEnded { _ in
                                last_point = nil
                            }
                    )
            }
        }
    }
}

#Preview {
    ContentView()
}
