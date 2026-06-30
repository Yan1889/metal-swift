//
//  Renderer.swift
//  blackhole
//
//  Created by Adam Zhakenov on 23.06.26.
//

import MetalKit
import QuartzCore
import AppKit

final class Renderer2: NSObject, MTKViewDelegate {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // Compute pipelines
    private let computeInitPipeline: MTLComputePipelineState
    private let computeUpdatePipeline: MTLComputePipelineState

    // Particle storage
    private let particleBuffer: MTLBuffer
    private let particleCount: Int = 200_000   // reasonable default for desktop

    // Timing
    private var lastTime: CFTimeInterval = CACurrentMediaTime()

    // Window constants (match shared.h)
    private let windowW: Float = 1080.0
    private let windowH: Float = 720.0

    // Spacecraft state (stored in particle index 0)
    private var spacecraftPos = SIMD2<Float>(0.5 * 1080.0, 0.5 * 720.0)
    private var spacecraftVel = SIMD2<Float>(0, 0)
    private var thrust: Float = 800.0
    private var keyState: Set<String> = []

    override init() {

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("No Metal device")
        }

        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("No command queue")
        }

        self.commandQueue = commandQueue

        // Load shaders from Shaders.metal
        let library = device.makeDefaultLibrary()!

        let vertexFunction = library.makeFunction(name: "vertex_main")!
        let fragmentFunction = library.makeFunction(name: "fragment_main")!

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Create render pipeline
        self.pipelineState = try! device.makeRenderPipelineState(
            descriptor: pipelineDescriptor
        )

        // Create compute pipelines
        let initFunc = library.makeFunction(name: "init")!
        let updateFunc = library.makeFunction(name: "paczynski_wiita_update")!

        self.computeInitPipeline = try! device.makeComputePipelineState(function: initFunc)
        self.computeUpdatePipeline = try! device.makeComputePipelineState(function: updateFunc)

        // Allocate particle buffer: each particle holds pos, vel, acc (float2 each) -> 6 floats
        let particleSize = MemoryLayout<Float>.stride * 6
        let bufferLength = particleCount * particleSize
        guard let buffer = device.makeBuffer(length: bufferLength, options: .storageModeShared) else {
            fatalError("Failed to allocate particle buffer")
        }

        self.particleBuffer = buffer

        super.init()

        // Run the init compute kernel once to populate particles
        let cmd = commandQueue.makeCommandBuffer()!
        let encoder = cmd.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(computeInitPipeline)
        encoder.setBuffer(particleBuffer, offset: 0, index: 0)

        var pcount32 = UInt32(particleCount)
        encoder.setBytes(&pcount32, length: MemoryLayout<UInt32>.size, index: 1)

        // Dispatch threads
        let w = computeInitPipeline.threadExecutionWidth
        let threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        cmd.commit()
        // Ensure initialization completes before first render to avoid rendering uninitialized data
        cmd.waitUntilCompleted()

        // Ensure spacecraft initial particle (index 0) is initialized in buffer
        writeSpacecraftToBuffer()
    }

    func mtkView(_ view: MTKView,
                 drawableSizeWillChange size: CGSize) {
        // nothing needed for now
    }

    // MARK: - Input handling (called from hosting view)
    func keyDown(character: String) {
        keyState.insert(character.lowercased())
    }

    func keyUp(character: String) {
        keyState.remove(character.lowercased())
    }

    // MARK: - Update / Draw
    func draw(in view: MTKView) {

        guard
            let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }

        // Compute step: update particle simulation
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(computeUpdatePipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)

        // delta time
        let now = CACurrentMediaTime()
        var dt = Float(now - lastTime)
        if dt <= 0 { dt = 1.0/60.0 }
        // clamp dt to avoid huge jumps when app was backgrounded
        dt = min(dt, 1.0/30.0)
        lastTime = now

        computeEncoder.setBytes(&dt, length: MemoryLayout<Float>.size, index: 1)

        var pcount32 = UInt32(particleCount)
        computeEncoder.setBytes(&pcount32, length: MemoryLayout<UInt32>.size, index: 2)

        // Build controls struct to send key state + thrust to GPU
        struct GPUControls {
            var keys: UInt32
            var thrust: Float
            var pad: UInt32
        }

        var keysMask: UInt32 = 0
        if keyState.contains("w") { keysMask |= 1 }
        if keyState.contains("s") { keysMask |= 2 }
        if keyState.contains("a") { keysMask |= 4 }
        if keyState.contains("d") { keysMask |= 8 }

        var controls = GPUControls(keys: keysMask, thrust: thrust, pad: 0)
        computeEncoder.setBytes(&controls, length: MemoryLayout<GPUControls>.size, index: 3)

        let w = computeUpdatePipeline.threadExecutionWidth
        let threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()

        // Render step
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)

        // Draw particles as points; vertexCount = particleCount
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)

        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func applyInput(dt: Float) {
        var ax: Float = 0
        var ay: Float = 0
        if keyState.contains("w") { ay -= 1 }
        if keyState.contains("s") { ay += 1 }
        if keyState.contains("a") { ax -= 1 }
        if keyState.contains("d") { ax += 1 }

        let len = sqrt(ax*ax + ay*ay)
        if len > 0.0 {
            ax /= len
            ay /= len
        }

        let acc = SIMD2<Float>(ax * thrust, ay * thrust)
        spacecraftVel += acc * dt

        // simple damping
        spacecraftVel *= 0.995

        spacecraftPos += spacecraftVel * dt

        // clamp to window
        spacecraftPos.x = min(max(spacecraftPos.x, 0.0), windowW)
        spacecraftPos.y = min(max(spacecraftPos.y, 0.0), windowH)
    }

    private func writeSpacecraftToBuffer() {
        let floatPtr = particleBuffer.contents().assumingMemoryBound(to: Float.self)
        // particle 0 layout: pos.x, pos.y, vel.x, vel.y, acc.x, acc.y
        floatPtr[0] = spacecraftPos.x
        floatPtr[1] = spacecraftPos.y
        floatPtr[2] = spacecraftVel.x
        floatPtr[3] = spacecraftVel.y
        floatPtr[4] = 0.0
        floatPtr[5] = 0.0
    }
}
