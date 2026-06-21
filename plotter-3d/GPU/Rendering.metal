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

struct VertexUniforms {
    float4x4 mvp_matrix;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                              constant VertexUniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    out.pos = uniforms.mvp_matrix * in.pos;
    out.color = in.color;
    return out;
}

fragment float4 fragmentShader(VertexOut v [[stage_in]]) {
    return v.color;
}
