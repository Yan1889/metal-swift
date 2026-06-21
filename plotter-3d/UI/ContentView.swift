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
    
    @State var fun: String = "x * x + z * z"
    
    var body: some View {
        VStack {
            SidePanel(fun: $fun)
                .frame(height: 50)
            
            MetalView(cam_pitch: cam_pitch, cam_yaw: cam_yaw, fun: fun)
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
