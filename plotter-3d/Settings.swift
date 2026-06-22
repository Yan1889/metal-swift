//
//  Settings.swift
//  plotter-3d
//
//  Created by Yan Amin on 22.06.26.
//

struct Settings {
    var push: PushSettings
    var pull: PullSettings
}

struct PushSettings: Equatable {
    var resolution_graph: Int
    var resolution_grid_lines: Int
    var resolution_grid_segments: Int
    var fun: String
    var color: ColorSettings
}

enum ColorSettings: Equatable {
    case Custom(SIMD4<Float>)
    case Continuous
    case Discrete
}

struct PullSettings {
    var cam_pitch: Float
    var cam_yaw: Float
    var cam_dist: Float
    var smoothGradient: Bool
}
