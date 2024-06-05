#include <iostream>
#include <fstream>
#include <cuda_runtime.h>

#define DIM 1000

struct cuComplex {
    float r;
    float i;

    __host__ __device__ cuComplex(float a, float b) : r(a), i(b) {}

    __host__ __device__ float magnitude2(void) {
        return r * r + i * i;
    }

    __host__ __device__ cuComplex operator*(const cuComplex& a) {
        return cuComplex(r * a.r - i * a.i, i * a.r + r * a.i);
    }

    __host__ __device__ cuComplex operator+(const cuComplex& a) {
        return cuComplex(r + a.r, i + a.i);
    }
};

__device__ int julia(int x, int y) {
    const float scale = 1.5;
    float jx = scale * (float)(DIM / 2 - x) / (DIM / 2);
    float jy = scale * (float)(DIM / 2 - y) / (DIM / 2);
    cuComplex c(-0.8, 0.156);
    cuComplex a(jx, jy);
    int i = 0;

    for (i = 0; i < 200; i++) {
        a = a * a + c;
        if (a.magnitude2() > 1000)
            return 0;
    }
    return 1;
}

__global__ void kernel(unsigned char *ptr) {
    int x = blockIdx.x;
    int y = blockIdx.y;
    int offset = x + y * gridDim.x;

    int juliaValue = julia(x, y);
    ptr[offset * 4 + 0] = 255 * juliaValue;
    ptr[offset * 4 + 1] = 0;
    ptr[offset * 4 + 2] = 0;
    ptr[offset * 4 + 3] = 255;
}

void saveBMP(const unsigned char *bitmap, int width, int height, const char *filename) {
    std::ofstream ofs(filename, std::ios::out | std::ios::binary);

    if (!ofs) {
        std::cerr << "Could not open file for writing: " << filename << std::endl;
        return;
    }

    unsigned int fileSize = 54 + width * height * 4;
    unsigned char fileHeader[14] = {
        'B', 'M', // BMP signature
        0, 0, 0, 0, // File size in bytes
        0, 0, 0, 0, // Reserved
        54, 0, 0, 0 // Start of pixel data
    };

    unsigned char infoHeader[40] = {
        40, 0, 0, 0, // Info header size
        0, 0, 0, 0, // Width
        0, 0, 0, 0, // Height
        1, 0,       // Number of color planes
        32, 0,      // Bits per pixel
        0, 0, 0, 0, // Compression
        0, 0, 0, 0, // Image size (no compression)
        0, 0, 0, 0, // Horizontal resolution
        0, 0, 0, 0, // Vertical resolution
        0, 0, 0, 0, // Number of colors
        0, 0, 0, 0  // Important colors
    };

    fileHeader[2] = (unsigned char)(fileSize);
    fileHeader[3] = (unsigned char)(fileSize >> 8);
    fileHeader[4] = (unsigned char)(fileSize >> 16);
    fileHeader[5] = (unsigned char)(fileSize >> 24);

    infoHeader[4] = (unsigned char)(width);
    infoHeader[5] = (unsigned char)(width >> 8);
    infoHeader[6] = (unsigned char)(width >> 16);
    infoHeader[7] = (unsigned char)(width >> 24);

    infoHeader[8] = (unsigned char)(height);
    infoHeader[9] = (unsigned char)(height >> 8);
    infoHeader[10] = (unsigned char)(height >> 16);
    infoHeader[11] = (unsigned char)(height >> 24);

    ofs.write(reinterpret_cast<const char *>(fileHeader), sizeof(fileHeader));
    ofs.write(reinterpret_cast<const char *>(infoHeader), sizeof(infoHeader));
    ofs.write(reinterpret_cast<const char *>(bitmap), width * height * 4);

    ofs.close();
}

int main(void) {
    unsigned char *dev_bitmap;
    unsigned char *bitmap = new unsigned char[DIM * DIM * 4];

    cudaMalloc((void**)&dev_bitmap, DIM * DIM * 4);
    dim3 grid(DIM, DIM);
    kernel<<<grid, 1>>>(dev_bitmap);
    cudaMemcpy(bitmap, dev_bitmap, DIM * DIM * 4, cudaMemcpyDeviceToHost);
    cudaFree(dev_bitmap);

    saveBMP(bitmap, DIM, DIM, "julia.bmp");

    delete[] bitmap;

    return 0;
}



