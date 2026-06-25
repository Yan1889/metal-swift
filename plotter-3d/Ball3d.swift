//
//  Ball3d.swift
//  plotter-3d
//
//  Created by Yan Amin on 24.06.26.
//

import Metal
import simd

class Ball3d: DrawableObject {
    private let vertexBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    
    public var radius: Float
    public var pos: SIMD4<Float>
    
    init(
        radius: Float,
        pos: SIMD4<Float>,
        color: SIMD4<Float>,
        resolution: Int,
        device: MTLDevice,
    ) {
        self.radius = radius
        self.pos = pos
        
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        
        for i in 0..<UInt32(resolution) {
            for j in 0..<UInt32(resolution) {
                let long = Float(i) / Float(resolution - 1) * .pi * 2
                let lat  = Float(j) / Float(resolution - 1) * .pi
                
                let x = sin(lat) * cos(long)
                let y = cos(lat)
                let z = sin(lat) * sin(long)
                
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
        
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride
        )!
        
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * 4
        )!
    }
    
    func encode(encoder: MTLRenderCommandEncoder, projection_view: float4x4) {
        let S = make_scalation_matrix(radius, radius, radius)
        let R = matrix_identity_float4x4
        let T = make_translation_matrix(pos.x, pos.y, pos.z)
        let model = T * R * S
        var mvp = projection_view * model
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&mvp, length: 4 * 4 * 4, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexBuffer.length / 4,
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0,
        )
    }
}
