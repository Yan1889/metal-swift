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

public let quad_indices: [[UInt32]] = [
    // triangle #1
    [0, 0],
    [1, 0],
    [1, 1],
    // triangle #2
    [0, 0],
    [0, 1],
    [1, 1],
]

/// returns the mesh of a ball with radius 1
func makeMesh_ball(
    radius: Float,
    pos: SIMD4<Float>,
    color: SIMD4<Float>,
    resolution: Int,
    device: MTLDevice,
) -> (MTLBuffer, MTLBuffer) {
    var vertices: [Vertex] = []
    var indices: [UInt32] = []
    
    for i in 0..<UInt32(resolution) {
        for j in 0..<UInt32(resolution) {
            let long = Float(i) / Float(resolution - 1) * .pi * 2
            let lat  = Float(j) / Float(resolution - 1) * .pi
            
            let x = radius * sin(lat) * cos(long)
            let y = radius * cos(lat)
            let z = radius * sin(lat) * sin(long)
            
            vertices.append(Vertex(
                pos: SIMD4<Float>(x, y, z, 1),
                col: color,
            ))
            
            let r = UInt32(resolution)
            for arr in quad_indices {
                indices.append(((i + arr[0]) % r) * r + (j + arr[1]) % r)
            }
        }
    }
    
    let vertexBuffer = device.makeBuffer(
        bytes: vertices,
        length: vertices.count * MemoryLayout<Vertex>.stride
    )!
    
    let indexBuffer = device.makeBuffer(
        bytes: indices,
        length: indices.count * 4
    )!
    
    return (vertexBuffer, indexBuffer)
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
