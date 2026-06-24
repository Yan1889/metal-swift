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
    
    var body: some View {
        VStack {
            HStack {
                Text("f(x, z) = ")
                TextField("type an expression", text: $settings.push.fun)
                if settings.pull.compiled {
                    Label("", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            
            Spacer()
            
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
            
            HStack {
                Text("Grid Thickness:")
                Slider(
                    value: $settings.push.grid_thickness,
                    in: 0...0.05
                )
                TextField(
                    "",
                    value: $settings.push.grid_thickness,
                    format: .number.precision(.fractionLength(3))
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
