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
    @State var ballsExpanded = true
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
                    Button("Satellite Dish") { settings.push.fun = "x * x + z * z > 1 ? NAN : 0.125 * (x * x + z * z)" }
                }
                
                Button("Reset") {
                    settings.push.shouldResetBalls = true
                }
            }
            
            Spacer()
            DisclosureGroup("Balls", isExpanded: $ballsExpanded) {
                make_slider(
                    label: "Bounciness:",
                    val: $settings.pull.bounciness,
                    range: 0...1,
                    interpolation: .linear,
                    fromDouble: Float.init,
                    toDouble: Double.init
                )
                
                make_slider(
                    label: "Gravity:",
                    val: $settings.pull.gravity,
                    range: 0.001...10,
                    interpolation: .linear,
                    fromDouble: Float.init,
                    toDouble: Double.init,
                )
                
                make_slider(
                    label: "Ball Radius:",
                    val: $settings.pull.ballRadius,
                    range: 0.001...0.1,
                    interpolation: .exponential,
                    fromDouble: Float.init,
                    toDouble: Double.init
                )
                
                Button {
                    settings.pull.paused.toggle()
                } label: {
                    Image(systemName: settings.pull.paused ? "play.fill" : "pause.fill")
                }
                .fixedSize()
            }
            
            Spacer()
            DisclosureGroup("Graph", isExpanded: $graphExpanded) {
                make_slider(
                    label: "Graph Resolution:",
                    val: $settings.push.resolution_graph,
                    range: 2...1000,
                    interpolation: .exponential,
                    fromDouble: Int.init,
                    toDouble: Double.init,
                )
                
                make_slider(
                    label: "Grid Line Count:",
                    val: $settings.push.resolution_grid_lines,
                    range: 2...1000,
                    interpolation: .exponential,
                    fromDouble: Int.init,
                    toDouble: Double.init,
                )
                
                make_slider(
                    label: "Grid Line Segment Count:",
                    val: $settings.push.resolution_grid_segments,
                    range: 2...1000,
                    interpolation: .exponential,
                    fromDouble: Int.init,
                    toDouble: Double.init,
                )
                
                make_slider(
                    label: "Grid Thickness",
                    val: $settings.push.grid_thickness,
                    range: 0.001...0.05,
                    interpolation: .linear,
                    fromDouble: Float.init,
                    toDouble: Double.init,
                )
            }
        }
    }
    
    enum InterpolationType {
        case linear
        case exponential
    }
    
    func make_slider<I: Numeric>(
        label: String,
        val: Binding<I>,
        range: ClosedRange<I>,
        interpolation: InterpolationType,
        fromDouble: @escaping (Double) -> I,
        toDouble: @escaping (I) -> Double,
    ) -> some View {
        let a = toDouble(range.lowerBound)
        let b = toDouble(range.upperBound)
        
        switch interpolation {
        case .linear:
            guard a != b else {
                fatalError("a != b")
            }
        case .exponential:
            guard a > 0, b > 0, a != b else {
                fatalError("a > 0, b > 0, a != b")
            }
        }
        
        let getDouble = { toDouble(val.wrappedValue) }
        let setDouble = { val.wrappedValue = fromDouble($0) }
        
        return HStack {
            Text(label)
            Slider(
                value: Binding(
                    get: {
                        switch interpolation {
                        case .linear: (getDouble() - a) / (b - a)
                        case .exponential: log(getDouble() / a) / log(b / a)
                        }
                    },
                    set: {
                        switch interpolation {
                        case .linear: setDouble(a + (b - a) * $0)
                        case .exponential: setDouble(a * pow(b / a, $0))
                        }
                    }
                ),
                in: 0...1
            )
            TextField(
                "",
                value: Binding(get: getDouble, set: setDouble),
                format: I.self == Int.self ? .number : .number.precision(.fractionLength(2))
            )
            .monospacedDigit()
            .fixedSize()
        }
    }
}
