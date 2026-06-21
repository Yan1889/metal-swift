//
//  SidePanel.swift
//  plotter-3d
//
//  Created by Yan Amin on 20.06.26.
//

import SwiftUI

struct SidePanel: View {
    
    @Binding var fun: String
    
    var body: some View {
        
        HStack {
            Text("f(x, z) = ")
            TextField("type an expression", text: $fun)
        }
        .padding()
    }
}
