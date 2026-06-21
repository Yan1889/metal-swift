//
//  Shared.h
//  plotter-3d
//
//  Created by Yan Amin on 21.06.26.
//

#ifndef SHARED_H
#define SHARED_H

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 pos [[attribute(0)]];
    float4 color [[attribute(1)]];
};

extern constant int quad_indices[6][2];

float4 brightColor(float t);

#endif
