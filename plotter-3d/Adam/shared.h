//
//  shared.h
//  blackhole
//
//  Created by Adam Zhakenov on 23.06.26.
//

#pragma once

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;
#define F2 float2
#else
#include <simd/simd.h>
#define F2 simd_float2
#endif

// ── Window ──────────────────────────────
#define WINDOW_W          1080
#define WINDOW_H          720

// ── Black hole ──────────────────────────
#define G_MASS            400000.0f
#define R_G               10.0f        // Schwarzschild radius
#define SOFTENING         0.5f

// ── Simulation ──────────────────────────
#define PARTICLES_AMOUNT  (1024 * 1024 * 2)

struct Particle {
    F2 pos;
    F2 vel;
    F2 acc;
};

#undef F2
