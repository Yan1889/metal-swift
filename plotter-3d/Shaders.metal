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

float4 brightColor(float t);

#define GRAY float4(0.5, 0.5, 0.5, 1.0)
#define ORANGE float4(1.0, 0.6, 0.0, 1.0)

float function_to_graph(float x, float z) {
    return x * x + z * z;
    // return sin(20 * (x * x + z * z));
    // return sin(15 * x) + sin(15 * z);
}

kernel void generateMesh(constant int &resolution [[buffer(0)]],
                         device VertexIn *vertices [[buffer(1)]],
                         device float2 *min_max [[buffer(2)]],
                         uint2 id [[thread_position_in_grid]]) {
    // vertex for this thread
    int idx = id.y * resolution + id.x;
    device VertexIn &v = vertices[idx];
    
    // coordinate for this vertex
    float x = 2.0 * id.x / (resolution - 1) - 1.0;
    float z = 2.0 * id.y / (resolution - 1) - 1.0;
    float y = function_to_graph(x, z);
    v.pos = float4(x, y, z, 1.0);
    min_max[idx] = float2(y, y);
    
    //
}

kernel void generateIndices(constant int &resolution [[buffer(0)]],
                            device uint *buf [[buffer(1)]],
                            uint2 id [[thread_position_in_grid]]) {
    int i = id.y;
    int j = id.x;
    
    // each thread is responsible for one quad
    // 1 quad = 2 triangles = 6 indices
    int startIdx = 6 * (i * (resolution - 1) + j);
    
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

kernel void reduceArray(constant int &entries [[buffer(0)]],
                        constant float2 *src [[buffer(1)]],
                        device float2 *dest [[buffer(2)]],
                        uint id [[thread_position_in_grid]]) {
    if (2 * id + 1 == uint(entries)) {
        // `2 * id` is the last entry in the array
        dest[id] = src[2 * id];
    } else {
        float mini = min(src[2 * id][0], src[2 * id + 1][0]);
        float maxi = max(src[2 * id][1], src[2 * id + 1][1]);
        dest[id] = float2(mini, maxi);
    }
}

kernel void colorVertices(constant float2 *min_max [[buffer(0)]],
                          constant int &resolution [[buffer(1)]],
                          device VertexIn *vertices [[buffer(2)]],
                          uint2 id [[thread_position_in_grid]]) {
    device VertexIn &v = vertices[id.y * resolution + id.x];
    float min_y = min_max[0][0];
    float max_y = min_max[0][1];
    v.color = brightColor((v.pos.y - min_y) / (max_y - min_y));
}
