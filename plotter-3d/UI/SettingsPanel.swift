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
    
    @State var functionExpanded = true
    @State var physicsExpanded = true
    @State var graphExpanded = true
    
    var body: some View {
        VStack {
            DisclosureGroup("Function", isExpanded: $functionExpanded) {
                HStack {
                    Text("f(x, z) = ")
                    TextField("type an expression", text: $settings.push.fun)
                    Image(systemName: settings.pull.compiled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(settings.pull.compiled ? .green : .red)
                        
                }
                Menu("Select a predefined function") {
                    Button("Bowl") { settings.push.fun = "1 - sqrt(1 - x * x - z * z)" }
                    Button("Vase") { settings.push.fun = "x * x + z * z" }
                    Button("Cone") { settings.push.fun = "sqrt(x * x + z * z)" }
                    Button("Pringles") { settings.push.fun = "x * x - z * z + 1" }
                    Button("Wave (1d)") { settings.push.fun = "sin(x * 20) / 5 + 0.2" }
                    Button("Wave (2d)") { settings.push.fun = "sin((x * x + z * z) * 20) / 5 + 0.2" }
                    Button("Wave (inverted)") { settings.push.fun = "sin(x * z * 20) / 5 + 0.2" }
                }
                
                Button("Reset") {
                    settings.push.shouldReset = true
                }
            }
            
            Spacer()
            DisclosureGroup("Physics", isExpanded: $physicsExpanded) {
                HStack {
                    Text("Bounciness:")
                    Slider(
                        value: $settings.pull.bounciness,
                        in: 0.1...1
                    )
                    TextField(
                        "",
                        value: $settings.pull.bounciness,
                        format: .number.precision(.fractionLength(2))
                    )
                    .fixedSize()
                }
                
                
                HStack {
                    Text("Gravity:")
                    Slider(
                        value: Binding(
                            get: { -settings.pull.gravity },
                            set: { settings.pull.gravity = -$0 }
                        ),
                        in: 0...5
                    )
                    TextField(
                        "",
                        value:  Binding(
                            get: { -settings.pull.gravity },
                            set: { settings.pull.gravity = -$0 }
                        ),
                        format: .number.precision(.fractionLength(2))
                    )
                    .fixedSize()
                }
                
                Button {
                    settings.pull.paused.toggle()
                } label: {
                    Image(systemName: settings.pull.paused ? "play.fill" : "pause.fill")
                }
                .fixedSize()
            }
            
            Spacer()
            DisclosureGroup("Graph", isExpanded: $graphExpanded) {
                HStack {
                    Text("Graph Resolution:")
                    Slider(
                        value: Binding(
                            get: { log(Double(settings.push.resolution_graph)) },
                            set: { settings.push.resolution_graph = Int(exp(Double($0))) }
                        ),
                        in: 1...8
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
    }
}
