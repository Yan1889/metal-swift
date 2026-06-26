//
//  Rendering.metal
//  plotter-3d
//
//  Created by Yan Amin on 21.06.26.
//

#include "Shared.h"

// --- only for balls ---

struct BallVertexIn {
    float4 vertPos [[attribute(0)]];
    float4 ballPos [[attribute(1)]];
};

struct BallVertexOut {
    float4 pos [[position]];
};

vertex BallVertexOut vertexBall(BallVertexIn in [[stage_in]],
                                constant float4x4 &projection_view [[buffer(2)]]) {
    
    BallVertexOut out;
    out.pos = projection_view * float4(in.vertPos.xyz + in.ballPos.xyz, 1.0);
    return out;
}

fragment float4 fragmentBall() {
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
