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

constant int quad_indices[6][2] = {
    // triangle #1
    {0, 0},
    {1, 0},
    {1, 1},
    // triangle #2
    {0, 0},
    {0, 1},
    {1, 1},
};

kernel void generateMesh(constant int    &resolution [[buffer(0)]],
                         device VertexIn *vertices   [[buffer(1)]],
                         device uint     *indices    [[buffer(2)]],
                         device float2   *min_max    [[buffer(3)]],
                         uint2 id [[thread_position_in_grid]]) {
    // 'indices' of this vertex
    int i = id.y;
    int j = id.x;

    // vertex for this thread
    int idx = i * resolution + j;
    device VertexIn &v = vertices[idx];
    
    // coordinate for this vertex
    float x = 2.0 * id.x / (resolution - 1) - 1.0;
    float z = 2.0 * id.y / (resolution - 1) - 1.0;
    float y = function_to_graph(x, z);
    v.pos = float4(x, y, z, 1.0);
    min_max[idx] = float2(y, y);

    if (i == resolution - 1 || j == resolution - 1) {
        // skip indices for those edges indices
        return;
    }
    
    // each thread is responsible for one quad
    // 1 quad = 2 triangles = 6 indices
    int startIdx = 6 * (i * (resolution - 1) + j);

    for (int k = 0; k < 6; k++) {
        indices[startIdx + k] = (i + quad_indices[k][0]) * resolution + (j + quad_indices[k][1]);
    }
}

kernel void generateGrid(constant int      &line_count   [[buffer(0)]],
                         constant float    &line_width   [[buffer(1)]],
                         device   VertexIn *vertices     [[buffer(2)]],
                         device   uint     *indices      [[buffer(3)]],
                         uint2 id [[thread_position_in_grid]]) {
    int i = id.y;
    int j = id.x;
    
    // 4 vertices for every thread (`vs[0...3]`)
    device VertexIn *vs = vertices + 4 * (i * line_count + j);
    
    float x = 2.0 * id.x / (line_count - 1.0) - 1.0;
    float z = 2.0 * id.y / (line_count - 1.0) - 1.0;
    
    float y = function_to_graph(x, z) + 0.01;
    vs[0].pos = float4(x - line_width, y, z - line_width, 1);
    vs[1].pos = float4(x + line_width, y, z - line_width, 1);
    vs[2].pos = float4(x + line_width, y, z + line_width, 1);
    vs[3].pos = float4(x - line_width, y, z + line_width, 1);
    
    vs[0].color = float4(0, 0, 0, 1);
    vs[1].color = float4(0, 0, 0, 1);
    vs[2].color = float4(0, 0, 0, 1);
    vs[3].color = float4(0, 0, 0, 1);
    
    // indices
    if (i == line_count - 1 || j == line_count - 1) {
        return;
    }
    
    device uint *startIndex = indices + 12 * (i * line_count + j);
    
    int start0 = 4 * ((i + 0) * line_count + j + 0);
    int startR = 4 * ((i + 0) * line_count + j + 1);
    int startU = 4 * ((i + 1) * line_count + j + 0);
    
    // quad #1, triangle #1
    startIndex[0] = start0 + 0;
    startIndex[1] = startR + 0;
    startIndex[2] = startR + 3;
    // quad #1, triangle #2
    startIndex[3] = start0 + 0;
    startIndex[4] = start0 + 3;
    startIndex[5] = startR + 3;
    // quad #2, triangle #1
    startIndex[6] = start0 + 2;
    startIndex[7] = startU + 1;
    startIndex[8] = startU + 0;
    // quad #2, triangle #2
    startIndex[9]  = start0 + 2;
    startIndex[10] = start0 + 3;
    startIndex[11] = startU + 0;
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
