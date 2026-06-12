#ifndef HITTABLE_HPP
#define HITTABLE_HPP

#include "ray.hpp"

struct hit_record
{
    point3 p;
    vec3 normal;
    bool front_face;
    double t;

    __device__ inline void set_face_normal(const ray &r, const vec3 &outward_normal)
    {
        front_face = dot(r.direction(), outward_normal) < 0;
        normal = front_face ? outward_normal : -outward_normal;
    }
};

class hittable
{
public:
    // 【修正】デストラクタにも必ず __device__ をつける
    __device__ virtual ~hittable() {}
    __device__ virtual bool hit(
        const ray &r, double t_min, double t_max, hit_record &rec) const = 0;
};

#endif