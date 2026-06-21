//
//  Shared.metal
//  plotter-3d
//
//  Created by Yan Amin on 21.06.26.
//

#include "Shared.h"

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

float4 brightColor(float t) {
    // Clamp just in case
    float x = max(0.0, min(1.0, t));
    
    // Frequency-shifted phase offsets for R, G, B
    float r = 0.5 + 0.5 * cos(2.0 * M_PI_F * (x + 0.0/3.0));
    float g = 0.5 + 0.5 * cos(2.0 * M_PI_F * (x + 1.0/3.0));
    float b = 0.5 + 0.5 * cos(2.0 * M_PI_F * (x + 2.0/3.0));
    
    return float4(r, g, b, 1.0);
}
