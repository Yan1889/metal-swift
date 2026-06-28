//
//  Renderer.swift
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

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
    private var renderPSO_balls: MTLRenderPipelineState!
    
    private var vertexBuffer_graph    : MTLBuffer!
    private var vertexBuffer_grid     : MTLBuffer!
    private var vertexBuffer_x_z_plane: MTLBuffer!
    private var vertexBuffer_balls    : MTLBuffer!
    private var indexBuffer_graph     : MTLBuffer!
    private var indexBuffer_grid      : MTLBuffer!
    private var indexBuffer_x_z_plane : MTLBuffer!
    private var indexBuffer_balls     : MTLBuffer!
    
    private var ball_velocities: MTLBuffer!
    private var ball_positions : MTLBuffer!
    
    private var depthTexture: MTLTexture!
    private var depthState: MTLDepthStencilState!
    
    // mesh compute pipeline
    private var computePSO_vertices     : MTLComputePipelineState!
    private var computePSO_reduceArray  : MTLComputePipelineState!
    private var computePSO_colorVertices: MTLComputePipelineState!
    private var computePSO_grid         : MTLComputePipelineState!
    private var computePSO_initBalls    : MTLComputePipelineState!
    private var computePSO_moveBalls    : MTLComputePipelineState!

    private var grid_lines_and_axes: [Line3d] = []
    
    private var settings: Binding<Settings>
    private var previousPushSettings: PushSettings
    
    private let ball_resolution: Int = 8
    
    // helpers
    private var pullSets: PullSettings { settings.pull.wrappedValue }
    private var pushSets: PushSettings { settings.push.wrappedValue }
    
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
        setupRenderPipeline_balls()
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
    
    func setupRenderPipeline_balls() {
        let vertexDescriptor = MTLVertexDescriptor()
        // vertex position
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].format = .float4
        // ball position
        vertexDescriptor.attributes[1].bufferIndex = 1
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].format = .float4
        // vertex buffer
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[0].stepRate = 1
        // position buffer
        vertexDescriptor.layouts[1].stride = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[1].stepFunction = .perInstance
        vertexDescriptor.layouts[1].stepRate = 1
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.vertexFunction = lib.makeFunction(name: "vertexBall")!
        pipelineDescriptor.fragmentFunction = lib.makeFunction(name: "fragmentBall")!
        
        let attachment = pipelineDescriptor.colorAttachments[0]!
        attachment.isBlendingEnabled = true

        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add

        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha

        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        renderPSO_balls = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func setupComputePipeline() {
        computePSO_reduceArray = try! device.makeComputePipelineState(function: lib.makeFunction(name: "reduceArray")!)
        computePSO_colorVertices = try! device.makeComputePipelineState(function: lib.makeFunction(name: "colorVertices")!)
        computePSO_initBalls = try! device.makeComputePipelineState(function: lib.makeFunction(name: "initBalls")!)
    }
    
    func setupBuffers() {
        setupBuffer_x_z_plane()
        setup_gridlines_and_axes()
        setupBalls()
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
        
        let fun_balls = library.makeFunction(name: "moveBalls")!
        let fun_mesh  = library.makeFunction(name: "generateMesh")!
        let fun_grid  = library.makeFunction(name: "generateGrid")!
        computePSO_vertices = try! device.makeComputePipelineState(function: fun_mesh)
        computePSO_grid = try! device.makeComputePipelineState(function: fun_grid)
        computePSO_moveBalls = try! device.makeComputePipelineState(function: fun_balls)
        
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
        
        vertexBuffer_graph = device.makeBuffer(length: vertex_count_graph * MemoryLayout<Vertex>.stride)
        vertexBuffer_grid            = device.makeBuffer(length: vertex_count_grid  * MemoryLayout<Vertex>.stride)
        
        indexBuffer_graph = device.makeBuffer(length: quad_count_graph * 6 * 4)
        indexBuffer_grid  = device.makeBuffer(length: quad_count_grid  * 4 * 2 * 6 * 4)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        // generate the vertices
        encoder.setComputePipelineState(computePSO_vertices)
        encoder.setBytes(&resolution_graph_int32, length: 4, index: 0)
        encoder.setBuffer(vertexBuffer_graph, offset: 0, index: 1)
        encoder.setBuffer(indexBuffer_graph, offset: 0, index: 2)
        encoder.setBuffer(minMaxBufA, offset: 0, index: 3)
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
        
        // color vertices
        encoder.setComputePipelineState(computePSO_colorVertices)
        encoder.setBuffer(is_A_src ? minMaxBufA : minMaxBufB, offset: 0, index: 0)
        encoder.setBytes(&resolution_graph_int32, length: 4, index: 1)
        encoder.setBuffer(vertexBuffer_graph, offset: 0, index: 4)
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
    
    func setup_gridlines_and_axes() {
        grid_lines_and_axes = [
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
        
        let line_count = 10
        
        for f in stride(from: Float(-1.5), through: 1.5, by: 3.0 / Float(line_count)) {
            let arr = [
                (SIMD3<Float>(f  , 0, 1.5), SIMD3<Float>(   f, 0, -1.5)),
                (SIMD3<Float>(1.5, 0, f  ), SIMD3<Float>(-1.5, 0, f)),
            ]
            
            for (start, end) in arr {
                grid_lines_and_axes.append(Line3d(
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
    
    func setupBalls() {
        // create a single mesh
        (vertexBuffer_balls, indexBuffer_balls) = makeMesh_ball(
            pos: [0, 0, 0, 1],
            color: [1, 1, 1, 1],
            resolution: ball_resolution,
            device: device,
        )
        
        // init the positions
        ball_positions = device.makeBuffer(length: pushSets.ballCount * 16)
        ball_velocities = device.makeBuffer(length: pushSets.ballCount * 16)
        
        var balls_side_count = Int32(round(sqrt(Float(pushSets.ballCount))))
        var height = settings.push.fallHeight.wrappedValue
        
        if balls_side_count == 1 {
            ball_positions.contents().assumingMemoryBound(to: SIMD4<Float>.self)[0] = [0, height, 0, 0]
            ball_velocities.contents().assumingMemoryBound(to: SIMD4<Float>.self)[0] = [0, 0, 0, 0]
            return
        }
        
        let threads_grid = MTLSize(width: pushSets.ballCount, height: 1, depth: 1)
        let threads_per_group = MTLSize(width: computePSO_initBalls.threadExecutionWidth, height: 1, depth: 1)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        encoder.setComputePipelineState(computePSO_initBalls)
        encoder.setBytes(&balls_side_count, length: 4, index: 0)
        encoder.setBytes(&height, length: 4, index: 1)
        encoder.setBuffer(ball_positions, offset: 0, index: 2)
        encoder.setBuffer(ball_velocities, offset: 0, index: 3)
        encoder.dispatchThreads(threads_grid, threadsPerThreadgroup: threads_per_group)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func moveBalls() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        let threads_grid = MTLSize(width: pushSets.ballCount, height: 1, depth: 1)
        let threads_per_group = MTLSize(width: computePSO_moveBalls.threadExecutionWidth, height: 1, depth: 1)
        
        encoder.setComputePipelineState(computePSO_moveBalls)
        encoder.setBytes(&settings.pull.gravity.wrappedValue, length: 4, index: 0)
        encoder.setBytes(&settings.pull.bounciness.wrappedValue, length: 4, index: 1)
        encoder.setBuffer(ball_positions, offset: 0, index: 2)
        encoder.setBuffer(ball_velocities, offset: 0, index: 3)
        encoder.dispatchThreads(threads_grid, threadsPerThreadgroup: threads_per_group)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
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
        
        if pushSets.shouldResetBalls {
            setupBalls()
            settings.push.shouldResetBalls.wrappedValue = false
        }
        
        if (!pullSets.ballsPaused) {
            moveBalls()
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
        var projection_view = projection * view
        var mvp = projection_view * model
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)!
        encoder.setRenderPipelineState(renderPSO)
        encoder.setDepthStencilState(depthState)
        
        
        encoder.setVertexBuffer(vertexBuffer_graph, offset: 0, index: 0)
        encoder.setVertexBytes(&mvp, length: 4 * 4 * 4, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexBuffer_graph.length / 4,
            indexType: .uint32,
            indexBuffer: indexBuffer_graph,
            indexBufferOffset: 0,
        )
        
        encoder.setVertexBuffer(vertexBuffer_grid, offset: 0, index: 0)
        encoder.setVertexBytes(&mvp, length: 4 * 4 * 4, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexBuffer_grid.length / 4,
            indexType: .uint32,
            indexBuffer: indexBuffer_grid,
            indexBufferOffset: 0,
        )
        
        for l in grid_lines_and_axes {
            l.encode(encoder: encoder, projection_view: projection_view)
        }
        
        // balls
        if (!pullSets.ballsHidden) {
            // switch pipeline
            encoder.setRenderPipelineState(renderPSO_balls)
            
            encoder.setVertexBuffer(vertexBuffer_balls, offset: 0, index: 0)
            encoder.setVertexBuffer(ball_positions, offset: 0, index: 1)
            encoder.setVertexBytes(&projection_view, length: 64, index: 2)
            encoder.setVertexBytes(&settings.pull.ballRadius.wrappedValue, length: 4, index: 3)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6 * ball_resolution * ball_resolution,
                indexType: .uint32,
                indexBuffer: indexBuffer_balls,
                indexBufferOffset: 0,
                instanceCount: pushSets.ballCount,
            )
            
            // switch pipeline back
            encoder.setRenderPipelineState(renderPSO)
        }
        
        encoder.setVertexBuffer(vertexBuffer_x_z_plane, offset: 0, index: 0)
        encoder.setVertexBytes(&mvp, length: 4 * 4 * 4, index: 1)
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
