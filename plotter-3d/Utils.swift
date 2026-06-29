//
//  Utils.swift
//  plotter-3d
//
//  Created by Yan Amin on 24.06.26.
//

import simd
import Metal

struct Vertex {
    let pos: SIMD4<Float>
    let col: SIMD4<Float>
}

func make_translation_matrix(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
    matrix_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(x, y, z, 1),
    )
}

func make_rotation_matrix(_ angle: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    matrix_float4x4(simd_quatf(angle: angle, axis: simd_normalize(axis)))
}

func make_scalation_matrix(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
    matrix_float4x4(
        SIMD4<Float>(x, 0, 0, 0),
        SIMD4<Float>(0, y, 0, 0),
        SIMD4<Float>(0, 0, z, 0),
        SIMD4<Float>(0, 0, 0, 1),
    )
}

func make_perspective_matrix(fovY: Float,
                             aspect: Float,
                             near: Float,
                             far: Float) -> simd_float4x4 {
    
    let yScale = 1 / tan(fovY * 0.5)
    let xScale = yScale / aspect
    
    let zRange = far - near
    let zScale = -(far + near) / zRange
    let wzScale = -(2 * far * near) / zRange
    
    return simd_float4x4(
        SIMD4<Float>(xScale, 0,      0,  0),
        SIMD4<Float>(0,      yScale, 0,  0),
        SIMD4<Float>(0,      0,      zScale, -1),
        SIMD4<Float>(0,      0,      wzScale, 0)
    )
}

func lookAt(
    eye: SIMD3<Float>,
    center: SIMD3<Float>,
    up: SIMD3<Float>
) -> simd_float4x4 {
    
    let f = simd_normalize(center - eye)
    let s = simd_normalize(simd_cross(f, up))
    let u = simd_cross(s, f)
    
    return simd_float4x4(
        SIMD4<Float>( s.x,  u.x, -f.x, 0),
        SIMD4<Float>( s.y,  u.y, -f.y, 0),
        SIMD4<Float>( s.z,  u.z, -f.z, 0),
        SIMD4<Float>(
            -simd_dot(s, eye),
             -simd_dot(u, eye),
             simd_dot(f, eye),
             1
        )
    )
}
