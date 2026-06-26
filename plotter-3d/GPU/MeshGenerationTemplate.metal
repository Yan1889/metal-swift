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

#define H (1e-5)

float4 graph_normal_at(float x, float z) {
    float y   = function_to_graph(x    , z);
    float y_x = function_to_graph(x + H, z);
    float y_z = function_to_graph(x    , z + H);
    
    float m_x = (y_x - y) / H;
    float m_z = (y_z - y) / H;
    
    return normalize(float4(-m_x, 1, -m_z, 0));
}

kernel void moveBalls(constant float  &gravity    [[buffer(0)]],
                      constant float  &bounciness [[buffer(1)]],
                      device float4 *positions  [[buffer(2)]],
                      device float4 *velocities [[buffer(3)]],
                     uint id [[thread_position_in_grid]]) {
    device float4 &pos = positions[id];
    device float4 &vel = velocities[id];
    
    // numeric integration for position and velocity
    pos += vel * 0.016;
    vel.y += gravity * 0.016;
    
    if (abs(pos.x) > 1 || abs(pos.z) > 1) {
        // ball is out of bounds, do not handle collision anymore
        return;
    }
    
    float y = function_to_graph(pos.x, pos.z);
    
    if (pos.y < y) {
        // collision between ball and graph surface
        float4 normal = graph_normal_at(pos.x, pos.z);
        vel += -dot(vel, normal) * normal * (1 + bounciness);
        
        // position correction
        float dy = y - pos.y;
        pos += dy * normal;
    }
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
        
    auto wrap = [segment_count](int l, int s) {
        return l * segment_count + s;
    };
    
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
    
    float y = function_to_graph(x, z);
    

    
    // 4 vertices for each thread
    device VertexIn *vs = vertices + 2 * 4 * wrap(line, segment);
    
    if (along_x) {
        // x does not change at this vertex
        vs[0].pos = float4(x, y - line_width, z - line_width, 1);
        vs[1].pos = float4(x, y - line_width, z + line_width, 1);
        vs[2].pos = float4(x, y + line_width, z + line_width, 1);
        vs[3].pos = float4(x, y + line_width, z - line_width, 1);
        
        vs[0].color = float4(0, 0, 0, 1);
        vs[1].color = float4(0, 0, 0, 1);
        vs[2].color = float4(0, 0, 0, 1);
        vs[3].color = float4(0, 0, 0, 1);
    } else {
        // z does not change at this vertex
        vs[4].pos = float4(x - line_width, y - line_width, z, 1);
        vs[5].pos = float4(x + line_width, y - line_width, z, 1);
        vs[6].pos = float4(x + line_width, y + line_width, z, 1);
        vs[7].pos = float4(x - line_width, y + line_width, z, 1);
        
        vs[4].color = float4(0, 0, 0, 1);
        vs[5].color = float4(0, 0, 0, 1);
        vs[6].color = float4(0, 0, 0, 1);
        vs[7].color = float4(0, 0, 0, 1);
    }
    
    if (segment == segment_count - 1) {
        // the last vertex of a line cannot be connected to 'the next vertex'
        return;
    }

    // 4 quads for every thread
    device uint *is = indices + 2 * 4 * 6 * wrap(line, segment);
    
    if (!along_x) {
        is += 24;
    }
    
    int offset_vertex = along_x ? 0 : 4;
    
    for (int i = 0; i < 6; i++) {
        for (int j = 0; j < 4; j++) {
            is[i + 6 * j]  = 2 * 4 * wrap(line, segment + quad_indices[i][0]) + (quad_indices[i][1] + j) % 4 + offset_vertex;
        }
    }
}
