#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <iostream>
#include <cstring>
#include <GL\glut.h>
using namespace std;
//ERRORS
static void HandleError(cudaError_t err,
	const char *file,
	int line) {
	if (err != cudaSuccess) {
		cout << cudaGetErrorString(err) << "in" << file << "at" << line << "line" << endl;
		exit(EXIT_FAILURE);
	}
}
#define HANDLE_ERROR( err ) (HandleError( err, __FILE__, __LINE__ ))
//CPUBitmap
struct CPUBitmap {
	unsigned char    *pixels;
	int     x, y;
	void    *dataBlock;
	void(*bitmapExit)(void*);

	CPUBitmap(int width, int height, void *d = NULL) {
		pixels = new unsigned char[width * height * 4];
		x = width;
		y = height;
		dataBlock = d;
	}

	~CPUBitmap() {
		delete[] pixels;
	}

	unsigned char* get_ptr(void) const { return pixels; }
	long image_size(void) const { return x * y * 4; }

	void display_and_exit(void(*e)(void*) = NULL) {
		CPUBitmap**   bitmap = get_bitmap_ptr();
		*bitmap = this;
		bitmapExit = e;
		// a bug in the Windows GLUT implementation prevents us from
		// passing zero arguments to glutInit()
		int c = 1;
		char* dummy = "";
		glutInit(&c, &dummy);
		glutInitDisplayMode(GLUT_SINGLE | GLUT_RGBA);
		glutInitWindowSize(x, y);
		glutCreateWindow("bitmap");
		glutKeyboardFunc(Key);
		glutDisplayFunc(Draw);
		glutMainLoop();
	}

	// static method used for glut callbacks
	static CPUBitmap** get_bitmap_ptr(void) {
		static CPUBitmap   *gBitmap;
		return &gBitmap;
	}

	// static method used for glut callbacks
	static void Key(unsigned char key, int x, int y) {
		switch (key) {
		case 27:
			CPUBitmap * bitmap = *(get_bitmap_ptr());
			if (bitmap->dataBlock != NULL && bitmap->bitmapExit != NULL)
				bitmap->bitmapExit(bitmap->dataBlock);
			exit(0);
		}
	}

	// static method used for glut callbacks
	static void Draw(void) {
		CPUBitmap*   bitmap = *(get_bitmap_ptr());
		glClearColor(0.0, 0.0, 0.0, 1.0);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawPixels(bitmap->x, bitmap->y, GL_RGBA, GL_UNSIGNED_BYTE, bitmap->pixels);
		glFlush();
	}
};
#define DIM 800
struct  cuComplex
{
	float r;
	float i;
	__device__ cuComplex(float a, float b) : r(a), i(b) {
	//	r = a;
	//	i = b;
	}
	__device__ float magnitude2() {
		return r * r + i * i;
	}
	__device__ cuComplex operator * (const cuComplex& a) {
		return cuComplex(r*a.r - i*a.i, i*a.r + r*a.i);
	}
	__device__ cuComplex operator + (const cuComplex& a) {
		return cuComplex(r + a.r, i + a.i);
	}
};
__device__ int julia(int x, int y) {
	const float scale = 1.5;
	float jx = scale * (float)(DIM / 2 - x)/(DIM / 2);
	float jy = scale * (float)(DIM / 2 - y)/(DIM / 2);
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
__global__ void kernel(unsigned char * ptr) {
	int x = blockIdx.x;
	int y = blockIdx.y;
	int offset = x + y * gridDim.x;

	int juliaValue = julia(x, y);
	ptr[offset * 4 + 0] = 255 * juliaValue;
	ptr[offset * 4 + 1] = 0;
	ptr[offset * 4 + 2] = 0;
	ptr[offset * 4 + 3] = 255;
}
int main()
{	
	CPUBitmap bitmap(DIM, DIM);
	unsigned char * dev_bitmap = bitmap.get_ptr();
	cudaMalloc((void**)&dev_bitmap, bitmap.image_size());
	dim3 grid(DIM, DIM);
	kernel<<<grid,1>>>(dev_bitmap);
	cudaMemcpy(bitmap.get_ptr(), dev_bitmap, bitmap.image_size(), cudaMemcpyDeviceToHost);
	bitmap.display_and_exit();
	cudaFree(dev_bitmap);
    return 0;
}