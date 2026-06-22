//
//  SettingsPanel.swift
//  plotter-3d
//
//  Created by Yan Amin on 21.06.26.
//

import SwiftUI

struct SettingsPanel: View {
    
    @Binding var settings: Settings
    
    @State var color: CGColor = .black
    
    @State var customColor = false
    
    var body: some View {
        VStack {
            HStack {
                Text("f(x, z) = ")
                TextField("type an expression", text: $settings.push.fun)
                Toggle("custom:", isOn: $customColor)
                    .toggleStyle(.switch)
                ColorPicker("my picker", selection: $color)
                    .frame(width: 30)
                    .opacity(customColor ? 1 : 0)
            }
            
            Spacer()
            
            Text("--- Settings ---")
                .font(.title)
            
            Toggle("Smooth Gradient", isOn: $settings.pull.smoothGradient)
                .toggleStyle(.switch)
            
            Slider(value: floatBinding(i: $settings.push.resolution_graph), in: 2...100)
            Slider(value: floatBinding(i: $settings.push.resolution_grid_lines), in: 2...100)
            Slider(value: floatBinding(i: $settings.push.resolution_grid_segments), in: 2...100)
        }
    }
    
    func floatBinding(i: Binding<Int>) -> Binding<Float> {
        Binding(
            get: { Float(i.wrappedValue) },
            set: { i.wrappedValue = Int($0) }
        )
    }
}
