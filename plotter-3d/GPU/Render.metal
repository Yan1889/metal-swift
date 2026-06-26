//
//  Rendering.metal
//  plotter-3d
//
//  Created by Yan Amin on 21.06.26.
//

#include "Shared.h"

struct VertexOut {
    float4 pos [[position]];
    float4 color;
};

vertex VertexOut ballsShader(VertexIn in [[stage_in]],
                       constant float4x4 &projection_view [[buffer(1)]],
                       constant float4   *positions [[buffer(2)]],
                       uint id [[instance_id]]) {
    
    VertexOut out;
    out.pos = projection_view * float4(in.pos.xyz + positions[id].xyz, 1.0);
    out.color = in.color;
    return out;
}

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
