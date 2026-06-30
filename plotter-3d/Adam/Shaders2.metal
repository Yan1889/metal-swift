//
//  Shaders.metal
//  blackhole
//
//  Created by Adam Zhakenov on 23.06.26.
//

#include <metal_stdlib>
#include <simd/simd.h>

#include "shared.h"

using namespace metal;

// Fast integer hash, output in [0, 1)
inline float hash1(uint x) {
    x ^= x >> 16;
    x *= 0x45d9f3bu;
    x ^= x >> 16;
    x *= 0xd2a98b26u;
    x ^= x >> 16;
    return float(x) * (1.0f / 4294967296.0f);
}

kernel void init(
    device Particle* particles [[buffer(0)]],
    constant uint& particleCount [[buffer(1)]],
    uint id [[thread_position_in_grid]]
)
{
    if (id >= particleCount) return;
    
    float angle  = hash1(id)              * 6.28318f;
    float radius = 3.0f * R_G + hash1(id ^ 0xDEADBEEFu) * 300.0f;

    float freq = 0.1f;
    for (int a = 0; a < 250; a++) {
        float prev = radius;
        radius += freq * fast::sin(freq * radius);
        if (fast::abs(radius - prev) < 1e-4f) break;  // early exit
    }

    // sincos computes both in one instruction
    float s, c;
    s = fast::sin(angle);   // fast:: is fine here — display only
    c = fast::cos(angle);

    particles[id].pos = float2(
        WINDOW_W * 0.5f + c * radius,
        WINDOW_H * 0.5f + s * radius
    );

    float denom = radius - R_G;
    float orbitalVelocity = fast::sqrt((G_MASS * radius) / (denom * denom));

    particles[id].vel = float2(
        -s * orbitalVelocity,
         c * orbitalVelocity
    );

    particles[id].acc = float2(0.0f);

}
// ─────────────────────────────────────────────
// Compute gravitational acceleration (PW potential)
// ─────────────────────────────────────────────
inline float2 compute_acc(float2 pos, float2 center)
{
    float2 d = center - pos;
    float r  = length(d);

    // Prevent singularity + division blow-up
    r = max(r, R_G + SOFTENING);

    float denom = (r - R_G);
    float denom2 = denom * denom;

    float acc_mag = G_MASS / denom2;

    return (d / r) * acc_mag;
}

// ─────────────────────────────────────────────
// COMPUTE KERNEL – Velocity Verlet integrator
// ─────────────────────────────────────────────
// Controls passed from CPU to compute kernel
struct Controls {
    uint keys;    // bitmask: 1=W,2=S,4=A,8=D
    float thrust;
    uint _pad;
};

kernel void paczynski_wiita_update(
    device Particle* particles [[buffer(0)]],
    constant float& dt         [[buffer(1)]],
    constant uint& particleCount [[buffer(2)]],
    constant Controls& controls [[buffer(3)]],
    uint id [[thread_position_in_grid]]
)
{
    if (id >= particleCount) return;
    
    float2 center = float2((WINDOW_W / 2.0f), (WINDOW_H / 2.0f));
    Particle p = particles[id];

    float r = length(center - p.pos);

    // Regenerate particles
    if (r < R_G * 1.05f)
    {
        float angle  = hash1(id)              * 6.28318f;
        float radius = 3.0f * R_G + hash1(id ^ 0xDEADBEEFu) * 300.0f;

        float freq = 0.1f;
        for (int a = 0; a < 250; a++) {
            float prev = radius;
            radius += freq * fast::sin(freq * radius);
            if (fast::abs(radius - prev) < 1e-4f) break;  // early exit
        }

        // sincos computes both in one instruction
        float s, c;
        s = fast::sin(angle);   // fast:: is fine here — display only
        c = fast::cos(angle);

        particles[id].pos[0] = WINDOW_W * 0.5f + c * radius;
        particles[id].pos[1] = WINDOW_H * 0.5f + s * radius;

        float denom = radius - R_G;
        float orbitalVelocity = fast::sqrt((G_MASS * radius) / (denom * denom));

        particles[id].vel[0] = -s * orbitalVelocity;
        particles[id].vel[1] =  c * orbitalVelocity;

        particles[id].acc[0] = 0.0f;
        particles[id].acc[1] = 0.0f;

        return;
    }

    // ─────────────────────────────
    // 1. Compute current acceleration
    // ─────────────────────────────
    float2 a0 = compute_acc(p.pos, center);

    // ─────────────────────────────
    // 2. Position update (Verlet step 1)
    // ─────────────────────────────
    float2 new_pos = p.pos + p.vel * dt + 0.5f * a0 * dt * dt;

    // ─────────────────────────────
    // 3. Compute new acceleration
    // ─────────────────────────────
    float2 a1 = compute_acc(new_pos, center);

    // ─────────────────────────────
    // 4. Velocity update (Verlet step 2)
    // ─────────────────────────────
    float2 new_vel = p.vel + 0.5f * (a0 + a1) * dt;

    // If this is the spacecraft (id == 0), apply player thrust from controls
    if (id == 0u) {
        float2 ctrl = float2(0.0f);
        if ((controls.keys & 1u) != 0u) { ctrl.y -= 1.0f; } // W
        if ((controls.keys & 2u) != 0u) { ctrl.y += 1.0f; } // S
        if ((controls.keys & 4u) != 0u) { ctrl.x -= 1.0f; } // A
        if ((controls.keys & 8u) != 0u) { ctrl.x += 1.0f; } // D

        float len = length(ctrl);
        if (len > 0.0f) ctrl = ctrl / len;

        // Apply thrust as acceleration over this timestep
        new_vel += ctrl * controls.thrust * dt;

        // Weak damping
        new_vel *= 0.999f;
    }

    // ─────────────────────────────
    // Write back
    // ─────────────────────────────
    p.pos = new_pos;
    p.vel = new_vel;
    p.acc = a1;

    particles[id] = p;
}

// ─────────────────────────────────────────────
//  RENDER PIPELINE – vertex stage
// ─────────────────────────────────────────────
struct VertexOut {
    float4 position   [[position]];
    float  point_size [[point_size]];
    float  speed;          // passed to fragment for colour
    float  isShip;         // 1.0 for spacecraft (vertex id 0)
};

vertex VertexOut vertex_main(
    device const Particle* particles [[buffer(0)]],
    uint vid [[vertex_id]]
) {
    VertexOut out;

    float2 pos = particles[vid].pos;

    // Convert pixel-space (0–800, 0–600) → clip-space (−1 to +1)
    // x: pos/half_width − 1,  y: flipped so +y is up
    constexpr float INV_HALF_W = 2.0f / WINDOW_W;
    constexpr float INV_HALF_H = 2.0f / WINDOW_H;

    out.position = float4(
        pos.x * INV_HALF_W - 1.0f,
        1.0f - pos.y * INV_HALF_H,
        0.0f,
        1.0f
    );

    // Mark spacecraft (vertex 0) and increase size
    if (vid == 0u) {
        out.point_size = 14.0f;
        out.isShip = 1.0f;
    } else {
        out.point_size = 2.5f;
        out.isShip = 0.0f;
    }

    out.speed      = length(particles[vid].vel);

    return out;
}

// ─────────────────────────────────────────────
//  RENDER PIPELINE – fragment stage
// ─────────────────────────────────────────────
fragment float4 fragment_main(
    VertexOut in             [[stage_in]],
    float2    point_coord    [[point_coord]]   // 0–1 within the point sprite
) {
    // If this is the spacecraft, draw a solid green rectangle
    if (in.isShip > 0.5f) {
        float3 col = float3(0.1f, 0.9f, 0.2f);
        return float4(col, 1.0f);
    }

    // Discard corners to get circular particles
    float2 centered = point_coord - 0.5f;
    
    float r2 = dot(centered, centered);
    
    if (r2 > 0.25f)
        discard_fragment();

    // Soft glow falloff
    float alpha = saturate(1.0f - r2 * 4.0f);

    // Map speed to a blue→white→orange colour gradient
    float t = clamp(in.speed / 120.0f, 0.0f, 1.0f);
    float3 cold = float3(0.2f, 0.5f, 1.0f);   // cool blue  – slow
    float3 hot  = float3(1.0f, 0.6f, 0.1f);   // orange     – fast
    float3 col  = mix(cold, hot, t);

    return float4(col * alpha, alpha);
}
