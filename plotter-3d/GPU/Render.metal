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
