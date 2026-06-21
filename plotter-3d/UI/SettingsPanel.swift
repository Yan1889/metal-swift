//
//  SettingsPanel.swift
//  plotter-3d
//
//  Created by Yan Amin on 21.06.26.
//

import SwiftUI

struct SettingsPanel: View {
    
    @Binding var smoothGradient: Bool

    @Binding var resolution_graph: Float
    @Binding var resolution_grid_lines: Float
    @Binding var resolution_grid_segments: Float
    
    @Binding var fun: String
    
    @State var color: CGColor = .black
    
    @State var customColor = false
    
    var body: some View {
        VStack {
            HStack {
                Text("f(x, z) = ")
                TextField("type an expression", text: $fun)
                Toggle("custom:", isOn: $customColor)
                    .toggleStyle(.switch)
                ColorPicker("my picker", selection: $color)
                    .frame(width: 30)
                    .opacity(customColor ? 1 : 0)
            }
            
            Spacer()
            
            Text("--- Settings ---")
                .font(.title)
            
            Toggle("Smooth Gradient", isOn: $smoothGradient)
                .toggleStyle(.switch)
            
            Slider(value: $resolution_graph, in: 2...100)
            Slider(value: $resolution_grid_lines, in: 2...100)
            Slider(value: $resolution_grid_segments, in: 2...100)
        }
    }
}
