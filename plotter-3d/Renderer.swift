//
//  Renderer.swift
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

import Foundation
import MetalKit
import SwiftUI

import simd


class Renderer: NSObject, MTKViewDelegate {
    private let view: MetalMtkView
    
    private let device: MTLDevice
    private let lib: MTLLibrary
    private let commandQueue: MTLCommandQueue
    
    // render pipeline
    private var renderPSO: MTLRenderPipelineState!
    private var vertexBuffer_graphContinuous: MTLBuffer!
    private var vertexBuffer_graphDiscrete: MTLBuffer!
    private var indexBuffer_graph: MTLBuffer!
    private var vertexBuffer_grid: MTLBuffer!
    private var indexBuffer_grid: MTLBuffer!
    private var vertexBuffer_x_z_plane: MTLBuffer!
    private var indexBuffer_x_z_plane: MTLBuffer!
    private var depthTexture: MTLTexture!
    private var depthState: MTLDepthStencilState!
    
    // mesh compute pipeline
    private var computePSO_vertices: MTLComputePipelineState!
    private var computePSO_reduceArray: MTLComputePipelineState!
    private var computePSO_colorVertices: MTLComputePipelineState!
    private var computePSO_grid: MTLComputePipelineState!
    
    private var axes: [Line3d] = []
    
    var settings: Binding<Settings>
    var previousPushSettings: PushSettings
    
    // helpers
    var pullSets: PullSettings { settings.pull.wrappedValue }
    var pushSets: PushSettings { settings.push.wrappedValue }
    
    init(view: MetalMtkView, settings: Binding<Settings>) {
        self.view = view
        self.settings = settings
        self.previousPushSettings = settings.push.wrappedValue
        
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
        
        let attachment = pipelineDescriptor.colorAttachments[0]!
        attachment.isBlendingEnabled = true

        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add

        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha

        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        renderPSO = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func setupComputePipeline() {
        computePSO_reduceArray = try! device.makeComputePipelineState(function: lib.makeFunction(name: "reduceArray")!)
        computePSO_colorVertices = try! device.makeComputePipelineState(function: lib.makeFunction(name: "colorVertices")!)
    }
    
    func setupBuffers() {
        setupAxes()
        setup_x_z_plane_grid()
        setupBuffer_x_z_plane()
        _ = updateMeshPipeline()
    }
    
    func updateMeshPipeline() -> Bool {
        let sourceURL: URL = Bundle.main.url(
            forResource: "MeshGenerationTemplate",
            withExtension: "metal"
        )!
        
        var source = try! String(contentsOf: sourceURL, encoding: .utf8)
        
        source.replace("// __BODY__", with: "return \(pushSets.fun);")
        
        guard let library = try? device.makeLibrary(source: source, options: nil) else {
            // malformed function expression from user could lead to syntax error etc.
            return false
        }
        
        let fun_mesh = library.makeFunction(name: "generateMesh")!
        let fun_grid = library.makeFunction(name: "generateGrid")!
        computePSO_vertices = try! device.makeComputePipelineState(function: fun_mesh)
        computePSO_grid = try! device.makeComputePipelineState(function: fun_grid)
        
        setupBuffers_Graph()
        
        return true
    }
    
    func setupBuffers_Graph() {
        let clock = ContinuousClock()
        let start = clock.now
        
        // graph mesh
        let vertex_count_graph: Int = pushSets.resolution_graph * pushSets.resolution_graph
        let quad_count_graph: Int = (pushSets.resolution_graph - 1) * (pushSets.resolution_graph - 1)
        
        // grid mesh
        let vertex_count_grid: Int = 4 * pushSets.resolution_grid_lines * pushSets.resolution_grid_segments * 2
        let quad_count_grid: Int = 2 * pushSets.resolution_grid_lines * pushSets.resolution_grid_segments
        
        // variables to pass to shaders
        var resolution_graph_int32 = Int32(pushSets.resolution_graph)
        var grid_line_count_int32 = Int32(pushSets.resolution_grid_lines)
        var grid_segment_count_int32 = Int32(pushSets.resolution_grid_segments)
        
        // threads per group and threads per grid
        let max_threads = computePSO_vertices.threadExecutionWidth
        let max_threads_sqrt = Int(Float(max_threads).squareRoot())
        let threads_per_group_1d   = MTLSize(width: max_threads           , height: 1                       , depth: 1)
        let threads_per_group_2d   = MTLSize(width: max_threads_sqrt      , height: max_threads_sqrt        , depth: 1)
        let threads_per_grid_graph = MTLSize(width: pushSets.resolution_graph      , height: pushSets.resolution_graph        , depth: 1)
        let threads_per_grid_grid  = MTLSize(width: pushSets.resolution_grid_lines , height: pushSets.resolution_grid_segments, depth: 2)
        
        let minMaxBufA = device.makeBuffer(length: 2 * 4 * vertex_count_graph)!
        let minMaxBufB = device.makeBuffer(length: 2 * 4 * vertex_count_graph)!
        var is_A_src = true
        
        vertexBuffer_graphContinuous = device.makeBuffer(length: vertex_count_graph * MemoryLayout<Vertex>.stride)
        vertexBuffer_graphDiscrete   = device.makeBuffer(length: vertex_count_graph * MemoryLayout<Vertex>.stride)
        vertexBuffer_grid            = device.makeBuffer(length: vertex_count_grid  * MemoryLayout<Vertex>.stride)
        
        indexBuffer_graph = device.makeBuffer(length: quad_count_graph * 6 * 4)
        indexBuffer_grid  = device.makeBuffer(length: quad_count_grid  * 4 * 2 * 6 * 4)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        // generate the vertices
        encoder.setComputePipelineState(computePSO_vertices)
        encoder.setBytes(&resolution_graph_int32, length: 4, index: 0)
        encoder.setBuffer(vertexBuffer_graphContinuous, offset: 0, index: 1)
        encoder.setBuffer(indexBuffer_graph, offset: 0, index: 2)
        encoder.setBuffer(minMaxBufA, offset: 0, index: 3)
        encoder.dispatchThreads(threads_per_grid_graph, threadsPerThreadgroup: threads_per_group_2d)
        // discrete
        encoder.setBuffer(vertexBuffer_graphDiscrete, offset: 0, index: 1)
        encoder.dispatchThreads(threads_per_grid_graph, threadsPerThreadgroup: threads_per_group_2d)
        
        // generate the grid
        encoder.setComputePipelineState(computePSO_grid)
        encoder.setBytes(&grid_line_count_int32,    length: 4, index: 0)
        encoder.setBytes(&grid_segment_count_int32, length: 4, index: 1)
        encoder.setBytes(&settings.push.grid_thickness.wrappedValue,  length: 4, index: 2)
        encoder.setBuffer(vertexBuffer_grid, offset: 0, index: 3)
        encoder.setBuffer(indexBuffer_grid,  offset: 0, index: 4)
        encoder.dispatchThreads(threads_per_grid_grid, threadsPerThreadgroup: threads_per_group_2d)

        // get the min and max values for y in the vertex array
        // reduce the min/max array until only one entry is left
        var min_max_entries = Int32(vertex_count_graph)
        while min_max_entries > 1 {
            let threads_per_grid = MTLSize(width: Int(min_max_entries), height: 1, depth: 1)
            
            encoder.setComputePipelineState(computePSO_reduceArray)
            encoder.setBytes(&min_max_entries, length: 4, index: 0)
            encoder.setBuffer(is_A_src ? minMaxBufA : minMaxBufB, offset: 0, index: 1)
            encoder.setBuffer(is_A_src ? minMaxBufB : minMaxBufA, offset: 0, index: 2)
            encoder.dispatchThreads(threads_per_grid, threadsPerThreadgroup: threads_per_group_1d)
            
            min_max_entries = (min_max_entries + 1) / 2
            is_A_src.toggle()
        }
        
        // :(
        var int8_true: UInt8 = 1
        var int8_false: UInt8 = 0
        
        // color continuous
        encoder.setComputePipelineState(computePSO_colorVertices)
        encoder.setBuffer(is_A_src ? minMaxBufA : minMaxBufB, offset: 0, index: 0)
        encoder.setBytes(&resolution_graph_int32, length: 4, index: 1)
        encoder.setBytes(&int8_true, length: 1, index: 2)
        encoder.setBuffer(vertexBuffer_graphContinuous, offset: 0, index: 3)
        encoder.dispatchThreads(threads_per_grid_graph, threadsPerThreadgroup: threads_per_group_2d)
        // color discrete
        encoder.setBytes(&int8_false, length: 1, index: 2)
        encoder.setBuffer(vertexBuffer_graphDiscrete, offset: 0, index: 3)
        encoder.dispatchThreads(threads_per_grid_graph, threadsPerThreadgroup: threads_per_group_2d)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        print("buffer generation ~ \(clock.now - start)")
    }
    
    func setupBuffer_x_z_plane() {
        let color = SIMD4<Float>(0.7, 0.7, 0.7, 0.8)
        
        let vertices: [Vertex] = [
            Vertex(pos: [-1.5, 0, -1.5, 1], col: color),
            Vertex(pos: [-1.5, 0,  1.5, 1], col: color),
            Vertex(pos: [ 1.5, 0,  1.5, 1], col: color),
            Vertex(pos: [ 1.5, 0, -1.5, 1], col: color),
        ]
        
        let indices: [UInt32] = [
            0, 2, 1, // triangle #1
            0, 3, 2, // triangle #2
        ]
        
        vertexBuffer_x_z_plane = device.makeBuffer(
            bytes: vertices,
            length: 4 * MemoryLayout<Vertex>.stride,
            options: .storageModeShared,
        )
        
        indexBuffer_x_z_plane = device.makeBuffer(
            bytes: indices,
            length: 6 * 4,
            options: .storageModeShared,
        )
    }
    
    func setupAxes() {
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
    }
    
    func setup_x_z_plane_grid() {
        let line_count = 10
        
        for f in stride(from: Float(-1.5), through: 1.5, by: 3.0 / Float(line_count)) {
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
    
    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let draw = view.currentDrawable
        else {
            print("something went wrong")
            return
        }
        
        if previousPushSettings != pushSets {
            previousPushSettings = pushSets
            settings.pull.compiled.wrappedValue = updateMeshPipeline()
        }
        
        pass.depthAttachment.texture = depthTexture
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1.0
        
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        
        let cam_pos = SIMD3<Float>(
            pullSets.cam_dist * cos(pullSets.cam_pitch) * sin(pullSets.cam_yaw),
            pullSets.cam_dist * sin(pullSets.cam_pitch),
            pullSets.cam_dist * cos(pullSets.cam_pitch) * cos(pullSets.cam_yaw),
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
        var mvp = projection * view * model
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)!
        encoder.setRenderPipelineState(renderPSO)
        encoder.setDepthStencilState(depthState)
        

        // bind mvp-matrix to slot 1 once only
        encoder.setVertexBytes(
            &mvp,
            length: MemoryLayout<matrix_float4x4>.stride,
            index: 1
        )
            
        encoder.setVertexBuffer(
            pullSets.smoothGradient ? vertexBuffer_graphContinuous : vertexBuffer_graphDiscrete,
            offset: 0,
            index: 0,
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
            indexBufferOffset: 0,
        )
        
        axes.forEach { $0.draw(encoder) }
        
        encoder.setVertexBuffer(vertexBuffer_x_z_plane, offset: 0, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint32,
            indexBuffer: indexBuffer_x_z_plane,
            indexBufferOffset: 0,
        )
        
        encoder.endEncoding()
        commandBuffer.present(draw)
        commandBuffer.commit()
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
