//
//  Rendering.metal
//  plotter-3d
//
//  Created by Yan Amin on 21.06.26.
//

#include "Shared.h"

// --- only for balls ---

struct BallVertexOut {
    float4 pos [[position]];
    float size [[point_size]];
};

vertex BallVertexOut vertexBall(constant float4x4 &projection_view [[buffer(0)]],
                                constant float2   &viewportSize [[buffer(1)]],
                                constant float    &radius [[buffer(2)]],
                                constant float4   *positions [[buffer(3)]],
                                uint vid [[vertex_id]]) {
    
    BallVertexOut out;
    out.pos = projection_view * positions[vid];
    float dist = out.pos.w;
    out.size = radius * viewportSize.y * projection_view[1][1] / dist;
    
    return out;
}

fragment float4 fragmentBall(float2 coord [[point_coord]]) {
    float2 centered = 2.0 * coord - 1.0;
    if (dot(centered, centered) > 1) {
        discard_fragment();
    }
    return float4(1); // white
}

// --- default ---

struct VertexOut {
    float4 pos [[position]];
    float4 color;
};


vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                              constant float4x4 &mvp [[buffer(1)]]) {
    VertexOut out;
    out.pos = mvp * in.pos;
    out.color = in.color;
    return out;
}

fragment float4 fragmentShader(VertexOut v [[stage_in]]) {
    return v.color;
}
