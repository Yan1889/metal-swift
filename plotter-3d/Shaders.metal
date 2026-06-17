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



float4 brightColor(float t);

#define GRAY float4(0.5, 0.5, 0.5, 1.0)
#define ORANGE float4(1.0, 0.6, 0.0, 1.0)

float function_to_graph(float x, float z) {
    return x * x + z * z;
}

kernel void generateMesh(constant KernelUniforms &uniforms [[buffer(0)]],
                         device VertexIn *buf [[buffer(1)]],
                         uint2 id [[thread_position_in_grid]]) {
    
    // unpack uniforms
    int resolution = uniforms.resolution;
    float grid_spacing = uniforms.grid_spacing;
    float grid_line_width = uniforms.grid_line_width;
    
    // vertex for this thread
    device VertexIn &v = buf[id.x * resolution + id.y];
    
    // coordinate for this vertex
    float x = 2.0 * id.x / resolution - 1.0;
    float z = 2.0 * id.y / resolution - 1.0;
    float y = function_to_graph(x, z);
    v.pos = float4(x, y, z, 1.0);
    
    // color for this vertex
    float dx = abs(x - floor(x / grid_spacing) * grid_spacing);
    float dz = abs(z - floor(z / grid_spacing) * grid_spacing);
    dx = min(dx, grid_spacing - dx);
    dz = min(dz, grid_spacing - dz);
    bool is_gray = dx < grid_line_width || dz < grid_line_width;
    v.color = is_gray ? GRAY : ORANGE;
}

kernel void generateIndices(constant KernelUniforms &uniforms [[buffer(0)]],
                            device uint *buf [[buffer(1)]],
                            uint2 id [[thread_position_in_grid]]) {
    // the only uniform we need here
    int resolution = uniforms.resolution;
    
    int i = id.x;
    int j = id.y;
    
    // each thread is responsible for one quad
    // 1 quad = 2 triangles = 6 indices
    int startIdx = 6 * (i * resolution + j);
    
    int diffs[6][2] = {
        // triangle #1
        {0, 0},
        {1, 0},
        {1, 1},
        // triangle #2
        {0, 0},
        {0, 1},
        {1, 1},
    };
    
    for (int k = 0; k < 6; k++) {
        buf[startIdx + k] = (i + diffs[k][0]) * resolution + (j + diffs[k][1]);
    }
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
