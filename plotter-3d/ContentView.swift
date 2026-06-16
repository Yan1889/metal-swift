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
    
    var body: some View {
        MetalView(cam_pitch: cam_pitch, cam_yaw: cam_yaw)
            .frame(width: 900, height: 900)
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

#Preview {
    ContentView()
}
