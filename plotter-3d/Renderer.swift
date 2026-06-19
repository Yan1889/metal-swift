//
//  Renderer.swift
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

import Foundation
import MetalKit

import simd


class Renderer: NSObject, MTKViewDelegate {
    private let view: MetalMtkView
    
    private let device: MTLDevice
    private let lib: MTLLibrary
    private let commandQueue: MTLCommandQueue
    
    // render pipeline
    private var renderPSO: MTLRenderPipelineState!
    private var vertexBuffer_graph: MTLBuffer!
    private var indexBuffer_graph: MTLBuffer!
    private var vertexBuffer_grid: MTLBuffer!
    private var indexBuffer_grid: MTLBuffer!
    private var depthTexture: MTLTexture!
    private var depthState: MTLDepthStencilState!
    
    // mesh compute pipeline
    private var computePSO_vertices: MTLComputePipelineState!
    private var computePSO_reduceArray: MTLComputePipelineState!
    private var computePSO_colorVertices: MTLComputePipelineState!
    private var computePSO_grid: MTLComputePipelineState!
    
    private var axes: [Line3d] = []
    
    private var zoom: Float = 1
    
    init(view: MetalMtkView) {
        self.view = view
        device = MTLCreateSystemDefaultDevice()!
        lib = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
        
        super.init()
        
        setupView()
        setupComputePipeline()
        setupRenderPipeline()
        setupBuffers()
        
        mtkView(view, drawableSizeWillChange: view.drawableSize)
        
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        
        depthState = device.makeDepthStencilState(descriptor: depthDesc)
    }
    
    func setupView() {
        view.delegate = self
        view.renderer = self
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
        view.depthStencilPixelFormat = .depth32Float
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
    
    struct Vertex {
        let pos: SIMD4<Float>
        let col: SIMD4<Float>
    }
    
    func setupRenderPipeline() {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].format = .float4
        
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].format = .float4
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.vertexFunction = lib.makeFunction(name: "vertexShader")!
        pipelineDescriptor.fragmentFunction = lib.makeFunction(name: "fragmentShader")!
        
        renderPSO = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func setupComputePipeline() {
        computePSO_vertices = try! device.makeComputePipelineState(function: lib.makeFunction(name: "generateMesh")!)
        computePSO_reduceArray = try! device.makeComputePipelineState(function: lib.makeFunction(name: "reduceArray")!)
        computePSO_colorVertices = try! device.makeComputePipelineState(function: lib.makeFunction(name: "colorVertices")!)
        computePSO_grid = try! device.makeComputePipelineState(function: lib.makeFunction(name: "generateGrid")!)
    }
    
    func setupBuffers() {
        let clock = ContinuousClock()
        let start = clock.now
        
        let resolution:      Int = 300
        var grid_line_count: Int = 10
        let vertex_count_graph: Int = resolution            * resolution
        let vertex_count_grid:  Int = grid_line_count       * grid_line_count * 4
        let quad_count_graph:   Int = (resolution - 1)      * (resolution - 1)
        let quad_count_grid:    Int = grid_line_count       * grid_line_count
        
        
        // variables to pass to shaders
        var resolution_int32 = Int32(resolution)
        var grid_line_width: Float = 0.003
        
        let max_threads = computePSO_vertices.threadExecutionWidth
        let max_threads_sqrt = Int(Float(max_threads).squareRoot())
        let threads_per_group_1d   = MTLSize(width: max_threads     , height: 1               , depth: 1)
        let threads_per_group_2d   = MTLSize(width: max_threads_sqrt, height: max_threads_sqrt, depth: 1)
        let threads_per_grid_graph = MTLSize(width: resolution      , height: resolution      , depth: 1)
        let threads_per_grid_grid  = MTLSize(width: grid_line_count , height: grid_line_count , depth: 1)
        
        let minMaxBufA = device.makeBuffer(length: 2 * 4 * vertex_count_graph)!
        let minMaxBufB = device.makeBuffer(length: 2 * 4 * vertex_count_graph)!
        var is_A_src = true
        
        vertexBuffer_graph = device.makeBuffer(length: vertex_count_graph * MemoryLayout<Vertex>.stride)
        vertexBuffer_grid  = device.makeBuffer(length: vertex_count_grid  * MemoryLayout<Vertex>.stride)
        indexBuffer_graph  = device.makeBuffer(length: quad_count_graph * 6 * 4)
        indexBuffer_grid   = device.makeBuffer(length: quad_count_grid  * 2 * 6 * 4)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        // generate the vertices
        encoder.setComputePipelineState(computePSO_vertices)
        encoder.setBytes(&resolution_int32, length: 4, index: 0)
        encoder.setBuffer(vertexBuffer_graph, offset: 0, index: 1)
        encoder.setBuffer(indexBuffer_graph, offset: 0, index: 2)
        encoder.setBuffer(minMaxBufA, offset: 0, index: 3)
        encoder.dispatchThreads(threads_per_grid_graph, threadsPerThreadgroup: threads_per_group_2d)
        
        // generate the grid
        encoder.setComputePipelineState(computePSO_grid)
        encoder.setBytes(&grid_line_count,  length: 4, index: 0)
        encoder.setBytes(&grid_line_width,  length: 4, index: 1)
        encoder.setBuffer(vertexBuffer_grid, offset: 0, index: 2)
        encoder.setBuffer(indexBuffer_grid,  offset: 0, index: 3)
        encoder.dispatchThreads(threads_per_grid_grid, threadsPerThreadgroup: threads_per_group_2d)

        // get the min and max values for y in the vertex array
        // reduce the min/max array until only one entry is left
        var min_max_entries = Int32(vertex_count_graph)
        while min_max_entries > 1 {
            
            min_max_entries = (min_max_entries + 1) / 2
            let threads_per_grid = MTLSize(width: Int(min_max_entries), height: 1, depth: 1)

            encoder.setComputePipelineState(computePSO_reduceArray)
            encoder.setBytes(&min_max_entries, length: 4, index: 0)

            if is_A_src {
                encoder.setBuffer(minMaxBufA, offset: 0, index: 1)
                encoder.setBuffer(minMaxBufB, offset: 0, index: 2)
                encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_group_1d)
            } else {
                encoder.setBuffer(minMaxBufB, offset: 0, index: 1)
                encoder.setBuffer(minMaxBufA, offset: 0, index: 2)
                encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_group_1d)
            }
            
            is_A_src.toggle()
        }
        
        encoder.setComputePipelineState(computePSO_colorVertices)
        encoder.setBuffer(is_A_src ? minMaxBufA : minMaxBufB, offset: 0, index: 0)
        encoder.setBytes(&resolution_int32, length: 4, index: 1)
        encoder.setBuffer(vertexBuffer_graph, offset: 0, index: 2)
        encoder.dispatchThreads(threads_per_grid_graph, threadsPerThreadgroup: threads_per_group_2d)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        print("buffer generation ~ \(clock.now - start)")
        print("sizeof(vertex buffer) ~ \(vertexBuffer_graph.length / 1_000_000)MB")
        print("sizeof(index buffer) ~ \(indexBuffer_graph.length / 1_000_000)MB")
        
        axes = [
            Line3d(
                start: [-1.5, 0, 0],
                end: [1.5, 0, 0],
                thickness: 0.02,
                device: device,
                corner_count: 8,
                color: [1, 0, 0, 1],
            ),
            Line3d(
                start: [0, -1.5, 0],
                end: [0, 1.5, 0],
                thickness: 0.02,
                device: device,
                corner_count: 8,
                color: [0, 1, 0, 1],
            ),
            Line3d(
                start: [0, 0, -1.5],
                end: [0, 0, 1.5],
                thickness: 0.02,
                device: device,
                corner_count: 8,
                color: [0, 0, 1, 1],
            )
        ]
        
        for f in stride(from: Float(-1.5), through: 1.5, by: 0.2) {
            let arr = [
                (SIMD3<Float>(f  , 0, 1.5), SIMD3<Float>(   f, 0, -1.5)),
                (SIMD3<Float>(1.5, 0, f  ), SIMD3<Float>(-1.5, 0, f)),
            ]
            
            for (start, end) in arr {
                axes.append(Line3d(
                    start: start,
                    end: end,
                    thickness: 0.003,
                    device: device,
                    corner_count: 8,
                    color: [0.5, 0.5, 0.5, 1],
                ))
            }
        }
    }
    
    struct VertexUniforms {
        let mvp_matrix: simd_float4x4
    }
    
    var time_acc: Float = 0
    
    // roll will not change and stay 0
    var cam_pitch: Float = 0
    var cam_yaw: Float = 0
    var cam_dist: Float = 5
    
    
    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let draw = view.currentDrawable
        else {
            print("something went wrong")
            return
        }
        
        pass.depthAttachment.texture = depthTexture
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1.0
        
        time_acc += 0.016
        
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        
        let cam_pos = SIMD3<Float>(
            cam_dist * cos(cam_pitch) * sin(cam_yaw),
            cam_dist * sin(cam_pitch),
            cam_dist * cos(cam_pitch) * cos(cam_yaw),
        )
        
        let model = matrix_identity_float4x4
        let view = lookAt(
            eye: cam_pos,
            center: SIMD3<Float>(0,0,0),
            up: SIMD3<Float>(0,1,0)
        )
        
        let projection = make_perspective_matrix(
            fovY: .pi / 3,
            aspect: 1,
            near: 0.1,
            far: 100,
        )
        var uniforms_vertex = VertexUniforms(mvp_matrix: projection * view * model)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)!
        encoder.setRenderPipelineState(renderPSO)
        encoder.setDepthStencilState(depthState)
        
        encoder.setVertexBuffer(vertexBuffer_graph, offset: 0, index: 0)
        encoder.setVertexBytes(
            &uniforms_vertex,
            length: MemoryLayout<VertexUniforms>.stride,
            index: 1
        )
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexBuffer_graph.length / 4,
            indexType: .uint32,
            indexBuffer: indexBuffer_graph,
            indexBufferOffset: 0,
        )
        
        encoder.setVertexBuffer(vertexBuffer_grid, offset: 0, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexBuffer_grid.length / 4,
            indexType: .uint32,
            indexBuffer: indexBuffer_grid,
            indexBufferOffset: 0
        )
        
        axes.forEach { $0.draw(encoder) }
        
        encoder.endEncoding()
        commandBuffer.present(draw)
        commandBuffer.commit()
    }
    
    func brightColor(_ t: Float) -> SIMD4<Float> {
        // return SIMD4<Float>(0.8, 0.5, 0.0, 1)
        
        // Clamp just in case
        let x = max(0, min(1, t))
        
        // Frequency-shifted phase offsets for R, G, B
        let r = 0.5 + 0.5 * cos(2.0 * .pi * (x + 0.0/3.0))
        let g = 0.5 + 0.5 * cos(2.0 * .pi * (x + 1.0/3.0))
        let b = 0.5 + 0.5 * cos(2.0 * .pi * (x + 2.0/3.0))
        
        return SIMD4<Float>(r, g, b, 1.0)
    }
    
    func make_translation_matrix(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
        return matrix_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1),
        )
    }
    
    func make_rotation_matrix(_ angle: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
        matrix_float4x4(simd_quatf(angle: angle, axis: simd_normalize(axis)))
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
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        
        desc.usage = [.renderTarget]
        desc.storageMode = .private
        
        depthTexture = device.makeTexture(descriptor: desc)
    }
}
