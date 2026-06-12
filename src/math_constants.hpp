#ifndef MATH_CONSTANTS_HPP
#define MATH_CONSTANTS_HPP

#include <cmath>
#include <cstdlib>

// 【修正】マクロ依存を避け、確実な巨大な数値を無限大として定義
__device__ const double infinity = 1e30;
__device__ const double pi = 3.1415926535897932385;

// ユーティリティ関数
__host__ __device__ inline double degrees_to_radians(double degrees)
{
    return degrees * pi / 180.0;
}

// 共通ヘッダー
#include "ray.hpp"
#include "vec3.hpp"

#endif