//
//  Shaders.metal
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 pos [[attribute(0)]];
    float4 color [[attribute(1)]];
};

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

struct KernelUniforms {
    int resolution;
    float grid_spacing;
    float grid_line_width;
};

[[visible]] float function_to_graph(float x, float z);

float4 brightColor(float t);

#define GRAY float4(0.5, 0.5, 0.5, 1.0)

kernel void generateMesh(constant KernelUniforms &uniforms [[buffer(0)]],
                         device VertexIn *buf [[buffer(1)]],
                         uint2 id [[thread_position_in_grid]]) {
    int x = id.x;
    int z = id.y;
    int y = function_to_graph(x, z);
    
    int idx = z * uniforms.resolution + y;
    device VertexIn &v = buf[idx];
    v.color = GRAY;
    v.pos = float4(x, y, z, 1.0);
}


float4 brightColor(float t) {
    // Clamp just in case
    float x = max(0.0, min(1.0, t));
    
    // Frequency-shifted phase offsets for R, G, B
    float r = 0.5 + 0.5 * cos(2.0 * M_PI_F * (x + 0.0/3.0));
    float g = 0.5 + 0.5 * cos(2.0 * M_PI_F * (x + 1.0/3.0));
    float b = 0.5 + 0.5 * cos(2.0 * M_PI_F * (x + 2.0/3.0));
    
    return float4(r, g, b, 1.0);
}
