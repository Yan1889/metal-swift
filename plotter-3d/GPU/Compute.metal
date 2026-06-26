//
//  Shaders.metal
//  plotter-3d
//
//  Created by Yan Amin on 13.06.26.
//

#include "Shared.h"

kernel void initBalls(constant int &ball_side_count [[buffer(0)]],
                      device float4 *positions      [[buffer(1)]],
                      device float4 *velocities     [[buffer(2)]],
                      uint id [[thread_position_in_grid]]) {
    
    float x = 2.0 * float(id / ball_side_count) / ball_side_count - 1;
    float z = 2.0 * float(id % ball_side_count) / ball_side_count - 1;
    
    positions[id] = float4(x, 2, z, 1);
    velocities[id] = float4(0, 0, 0, 0);
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

kernel void colorVertices(constant float2 *min_max  [[buffer(0)]],
                          constant int &resolution  [[buffer(1)]],
                          device VertexIn *vertices [[buffer(4)]],
                          uint2 id [[thread_position_in_grid]]) {
    
    
    
    device VertexIn &v = vertices[id.y * resolution + id.x];
    float min_y = min_max[0][0];
    float max_y = min_max[0][1];
    float t = (v.pos.y - min_y) / (max_y - min_y);
    v.color = brightColor(t);
}
