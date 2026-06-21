#include <metal_stdlib>
using namespace metal;

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

struct VertexIn {
    float4 pos [[attribute(0)]];
    float4 color [[attribute(1)]];
};

float function_to_graph(float x, float z) {
    // __BODY__
    // ^ this gets replaced by "return \(real_expression);"
    return 0;
    // ^ 'default function' place holder
}

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

kernel void generateGrid(constant int      &line_count     [[buffer(0)]],
                         constant int      &segment_count  [[buffer(1)]],
                         constant float    &line_width     [[buffer(2)]],
                         device   VertexIn *vertices       [[buffer(3)]],
                         device   uint     *indices        [[buffer(4)]],
                         uint3 id [[thread_position_in_grid]]) {
    
    int line = id.x;
    int segment = id.y;
    bool along_x = id.z == 0;
    float x, z;
    
    if (along_x) {
        x = 2.0 * float(segment) / float(segment_count - 1) - 1.0;
        z = 2.0 * float(line)    / float(line_count - 1)    - 1.0;
    } else {
        z = 2.0 * float(segment) / float(segment_count - 1) - 1.0;
        x = 2.0 * float(line)    / float(line_count - 1)    - 1.0;
    }
    
    float x1, x2, z1, z2;
    
    if (along_x) {
        x1 = x;
        x2 = x;
        
        z1 = z - line_width;
        z2 = z + line_width;
    } else {
        x1 = x - line_width;
        x2 = x + line_width;
        
        z1 = z;
        z2 = z;
    }
    float y1 = function_to_graph(x1, z1) + 0.01;
    float y2 = function_to_graph(x2, z2) + 0.01;
    
    auto wrap = [segment_count](int l, int s) {
        return l * segment_count + s;
    };
    
    // 2 vertices for each thread
    device VertexIn *vs = vertices + 4 * wrap(line, segment);
    
    if (along_x) {
        // `vs[0]` and `vs[1]`
        vs[0].pos = float4(x1, y1, z1, 1);
        vs[1].pos = float4(x2, y2, z2, 1);
        vs[0].color = float4(0, 0, 0, 1);
        vs[1].color = float4(0, 0, 0, 1);
    } else {
        // `vs[2]` and `vs[3]`
        vs[2].pos = float4(x1, y1, z1, 1);
        vs[3].pos = float4(x2, y2, z2, 1);
        vs[2].color = float4(0, 0, 0, 1);
        vs[3].color = float4(0, 0, 0, 1);
    }
    
    if (segment == segment_count - 1) {
        // the last vertex of a line cannot be connected to 'the next vertex'
        return;
    }
    
    // 1 quad for every thread
    device uint *is = indices + 2 * 6 * wrap(line, segment);
    
    int offset_index = along_x ? 0 : 6;
    int offset_vertex = along_x ? 0 : 2;
    
    for (int i = 0; i < 6; i++) {
        is[i + offset_index] = 4 * wrap(line, segment + quad_indices[i][0]) + quad_indices[i][1] + offset_vertex;
    }
}
