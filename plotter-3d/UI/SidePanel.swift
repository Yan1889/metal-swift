//
//  SidePanel.swift
//  plotter-3d
//
//  Created by Yan Amin on 20.06.26.
//

import SwiftUI

struct SidePanel: View {
    
    @State var text: String = "x"
    
    var body: some View {
        
        HStack {
            Text("f(x, z) = ")
            TextField("x + z", text: $text)
                .onChange(of: text) {
                    guard let tokens = Lexer.tokenize(text) else {
                        print("error lex")
                        return
                    }
                    print(tokens)
                    
                    guard let tree = Parser.parse(tokens) else {
                        print("error parse")
                        return
                    }
                    print(tree)
                }
        }
        .padding()
    }
}
