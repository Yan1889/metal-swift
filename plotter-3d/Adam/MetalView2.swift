//
//  MetalView.swift
//  blackhole
//
//  Created by Adam Zhakenov on 23.06.26.
//

import SwiftUI
import MetalKit
import AppKit

struct MetalView2: NSViewRepresentable {

    func makeCoordinator() -> Renderer2 {
        Renderer2()
    }

    func makeNSView(context: Context) -> NSView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported")
        }

        // Hosting view that captures keyboard input and contains MTKView
        class HostingView: NSView {
            let mtkView: MTKView
            let renderer: Renderer2

            init(frame: CGRect, device: MTLDevice, renderer: Renderer2) {
                self.mtkView = MTKView(frame: frame, device: device)
                self.renderer = renderer
                super.init(frame: frame)

                mtkView.translatesAutoresizingMaskIntoConstraints = false
                mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
                mtkView.colorPixelFormat = .bgra8Unorm
                mtkView.preferredFramesPerSecond = 60
                mtkView.drawableSize = CGSize(width: 1080, height: 720)
                mtkView.delegate = renderer

                addSubview(mtkView)

                // constrain to edges
                NSLayoutConstraint.activate([
                    mtkView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    mtkView.trailingAnchor.constraint(equalTo: trailingAnchor),
                    mtkView.topAnchor.constraint(equalTo: topAnchor),
                    mtkView.bottomAnchor.constraint(equalTo: bottomAnchor),
                ])
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override var acceptsFirstResponder: Bool { true }

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                window?.makeFirstResponder(self)
            }

            override func keyDown(with event: NSEvent) {
                guard let chars = event.charactersIgnoringModifiers else { return }
                for c in chars { renderer.keyDown(character: String(c)) }
            }

            override func keyUp(with event: NSEvent) {
                guard let chars = event.charactersIgnoringModifiers else { return }
                for c in chars { renderer.keyUp(character: String(c)) }
            }
        }

        let hosting = HostingView(frame: .zero, device: device, renderer: context.coordinator)
        return hosting
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}
