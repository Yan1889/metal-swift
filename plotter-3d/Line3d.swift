//
//  Line3d.swift
//  plotter-3d
//
//  Created by Yan Amin on 24.06.26.
//

import Metal
import simd

struct Vertex {
    let pos: SIMD4<Float>
    let col: SIMD4<Float>
}

class Line3d {
    private let vertexBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    
    private let n: Int
    
    init(start: SIMD3<Float>,
         end: SIMD3<Float>,
         thickness: Float,
         device: MTLDevice,
         corner_count n: Int,
         color: SIMD4<Float>,
    ) {
        self.n = n
        
        let u = simd_normalize(end - start)
        
        // get basis vectors i and j from plane
        let a = SIMD3<Float>.random(in: 0...1)
        let i_hat = normalize(simd_cross(a, u))
        let j_hat = normalize(simd_cross(u, i_hat))
        
        var vertices_start: [Vertex] = []
        var vertices_end: [Vertex] = []
        var indices: [UInt32] = []
        
        for i in 0..<n {
            let angle = Float(i) / Float(n) * 2 * .pi
            let v1 = start + thickness * (i_hat * cos(angle) + j_hat * sin(angle))
            let v2 = end   + thickness * (i_hat * cos(angle) + j_hat * sin(angle))
            vertices_start.append(Vertex(
                pos: SIMD4<Float>(v1.x, v1.y, v1.z, 1),
                col: color,
            ))
            vertices_end.append(Vertex(
                pos: SIMD4<Float>(v2.x, v2.y, v2.z, 1),
                col: color,
            ))
            
            let i = UInt32(i)
            let n = UInt32(n)
            
            let next = (i + 1) % n
            
            indices += [i, next, next + n]
            indices += [i, i + n, next + n]
        }
        
        vertexBuffer = device.makeBuffer(bytes: vertices_start + vertices_end, length: 2 * n * MemoryLayout<Vertex>.stride)!
        indexBuffer = device.makeBuffer(bytes: indices, length: 4 * indices.count)!
    }
    
    func draw(_ encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: n * 6, // each quad has 2 triangles => 6 vertices
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0,
        )
    }
}
