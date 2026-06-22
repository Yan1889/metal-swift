//
//  SettingsPanel.swift
//  plotter-3d
//
//  Created by Yan Amin on 21.06.26.
//

import Foundation
import SwiftUI


struct SettingsPanel: View {
    
    @Binding var settings: Settings
    
    var isCustomColor: Bool {
        get {
            switch settings.push.color {
            case .Custom(_): true
            default: false
            }
        }
        set {
            
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("f(x, z) = ")
                TextField("type an expression", text: $settings.push.fun)
                
                
                /*
                Toggle(
                    "custom:",
                    isOn: Binding(
                        get: { getIsCustomColor() },
                        set: { setIsCustomColor($0) }
                    )
                )
                .toggleStyle(.switch)
                
                ColorPicker("my picker", selection: $color)
                    .frame(width: 30)
                    .opacity(.Custom(_) ~= settings.push.color ? 0 : 1)
                */
            }
            
            Spacer()
            
            Toggle("Smooth Gradient", isOn: $settings.pull.smoothGradient)
                .toggleStyle(.switch)
            
            HStack {
                Text("Graph Resolution:")
                Slider(
                    value: Binding(
                        get: { log(Double(settings.push.resolution_graph)) },
                        set: { settings.push.resolution_graph = Int(exp(Double($0))) }
                    ),
                    in: 1...7
                )
                TextField(
                    "",
                    value: $settings.push.resolution_graph,
                    format: .number
                )
                    .fixedSize()
            }
            
            HStack {
                Text("Grid Line Count:")
                Slider(
                    value: Binding(
                        get: { log(Double(settings.push.resolution_grid_lines)) },
                        set: { settings.push.resolution_grid_lines = Int(exp(Double($0))) }
                    ),
                    in: 1...7
                )
                TextField(
                    "",
                    value: $settings.push.resolution_grid_lines,
                    format: .number
                )
                    .fixedSize()
            }
            
            HStack {
                Text("Grid Line Segment Count:")
                Slider(
                    value: Binding(
                        get: { log(Double(settings.push.resolution_grid_segments)) },
                        set: { settings.push.resolution_grid_segments = Int(exp(Double($0))) }
                    ),
                    in: 1...7
                )
                TextField(
                    "",
                    value: $settings.push.resolution_grid_segments,
                    format: .number
                )
                    .fixedSize()
            }
        }
    }
    
    func floatBinding(i: Binding<Int>) -> Binding<Float> {
        Binding(
            get: { Float(i.wrappedValue) },
            set: { i.wrappedValue = Int($0) }
        )
    }
}
