#include "math_constants.hpp"
#include "hittable_list.hpp"
#include "sphere.hpp"
#include "color.hpp"

#include <iostream>

// --- ここから追加：CUDAの沈黙エラーを捕捉するマクロ ---
#define checkCudaErrors(val) check_cuda( (val), #val, __FILE__, __LINE__ )
void check_cuda(cudaError_t result, char const *const func, const char *const file, int const line) {
    if (result != cudaSuccess) {
        std::cerr << "CUDA error = " << static_cast<unsigned int>(result) << " at " <<
        file << ":" << line << " '" << func << "' \n";
        std::cerr << "Error String: " << cudaGetErrorString(result) << "\n";
        cudaDeviceReset();
        exit(99);
    }
}
// --- ここまで ---

__device__ color ray_color(const ray &r, hittable **world)
{
    hit_record rec;
    if ((*world)->hit(r, 0.0, infinity, rec))
    {
        return 0.5 * (rec.normal + color(1, 1, 1));
    }

    vec3 unit_direction = unit_vector(r.direction());
    auto t = 0.5 * (unit_direction.y() + 1.0);
    return (1.0 - t) * color(1.0, 1.0, 1.0) + t * color(0.5, 0.7, 1.0);
}

__global__ void render(color *fb, int max_x, int max_y, vec3 lower_left_corner, vec3 horizontal, vec3 vertical, vec3 origin, hittable **world)
{
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;

    if ((i >= max_x) || (j >= max_y)) return;

    int pixel_index = j * max_x + i;
    auto u = double(i) / (max_x - 1);
    auto v = double(j) / (max_y - 1);
    ray r(origin, lower_left_corner + u * horizontal + v * vertical - origin);
    
    fb[pixel_index] = ray_color(r, world);
}

__global__ void create_world(hittable **d_list, hittable **d_world)
{
    if (threadIdx.x == 0 && blockIdx.x == 0)
    {
        d_list[0] = new sphere(point3(0, 0, -1), 0.5);
        d_list[1] = new sphere(point3(0, -100.5, -1), 100);
        *d_world = new hittable_list(d_list, 2);
    }
}

__global__ void free_world(hittable **d_list, hittable **d_world)
{
    if (threadIdx.x == 0 && blockIdx.x == 0)
    {
        delete ((sphere *)d_list[0]);
        delete ((sphere *)d_list[1]);
        delete *d_world;
    }
}

int main()
{
    const auto aspect_ratio = 16.0 / 9.0;
    const int image_width = 256;
    const int image_height = static_cast<int>(image_width / aspect_ratio);
    const int num_pixels = image_width * image_height;
    size_t fb_size = num_pixels * sizeof(color);

    color *fb;
    checkCudaErrors(cudaMallocManaged((void **)&fb, fb_size));

    hittable **d_list;
    checkCudaErrors(cudaMalloc((void **)&d_list, 2 * sizeof(hittable *)));
    hittable **d_world;
    checkCudaErrors(cudaMalloc((void **)&d_world, sizeof(hittable *)));

    std::cerr << "Creating world on GPU..." << std::endl;
    create_world<<<1, 1>>>(d_list, d_world);
    checkCudaErrors(cudaGetLastError()); // カーネル起動直後のエラー確認
    checkCudaErrors(cudaDeviceSynchronize()); // 完了待機時のエラー確認

    auto viewport_height = 2.0;
    auto viewport_width = aspect_ratio * viewport_height;
    auto focal_length = 1.0;

    auto origin = point3(0, 0, 0);
    auto horizontal = vec3(viewport_width, 0, 0);
    auto vertical = vec3(0, viewport_height, 0);
    auto lower_left_corner = origin - horizontal / 2 - vertical / 2 - vec3(0, 0, focal_length);

    int tx = 8;
    int ty = 8;
    dim3 blocks(image_width / tx + 1, image_height / ty + 1);
    dim3 threads(tx, ty);

    std::cerr << "Rendering on GPU..." << std::endl;
    render<<<blocks, threads>>>(fb, image_width, image_height, lower_left_corner, horizontal, vertical, origin, d_world);
    checkCudaErrors(cudaGetLastError()); 
    checkCudaErrors(cudaDeviceSynchronize()); 

    std::cout << "P3\n" << image_width << ' ' << image_height << "\n255\n";
    for (int j = image_height - 1; j >= 0; --j)
    {
        for (int i = 0; i < image_width; ++i)
        {
            size_t pixel_index = j * image_width + i;
            write_color(std::cout, fb[pixel_index]);
        }
    }
    std::cerr << "Done.\n";

    free_world<<<1, 1>>>(d_list, d_world);
    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());
    
    checkCudaErrors(cudaFree(d_list));
    checkCudaErrors(cudaFree(d_world));
    checkCudaErrors(cudaFree(fb));

    return 0;
}