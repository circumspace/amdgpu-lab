#!/usr/bin/env bash
# Checks rocprofv3 on benchmark-host's card with a vector-add kernel, inside a throwaway copy of the production image.
# Needs only a few MB of VRAM, so it runs next to production.
set -euo pipefail
IMG=localhost/llm-swap:262-b11804
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
cat > "$W/vadd.hip" <<'HIP'
#include <hip/hip_runtime.h>
#include <cstdio>
__global__ void vadd(const float *a, const float *b, float *c, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i < n) c[i] = a[i] + b[i];
}
int main() {
  const int n = 1 << 20;
  float *a, *b, *c;
  hipMalloc(&a, n * 4); hipMalloc(&b, n * 4); hipMalloc(&c, n * 4);
  for (int r = 0; r < 100; ++r) hipLaunchKernelGGL(vadd, dim3(n / 256), dim3(256), 0, 0, a, b, c, n);
  hipDeviceSynchronize();
  printf("done\n");
}
HIP
podman run --rm --device /dev/dri --device /dev/kfd -e HSA_OVERRIDE_GFX_VERSION=10.3.0 \
  -v "$W:/w:z" -w /w --entrypoint sh "$IMG" -c '
    apt-get update -qq >/dev/null && apt-get install -y -qq libdw1t64 >/dev/null
    hipcc --offload-arch=gfx1030 -O2 vadd.hip -o vadd 2>/dev/null
    rocprofv3 --kernel-trace --hip-runtime-trace --stats -d trace -o run --output-format csv -- ./vadd
    rocprofv3 --pmc SQ_WAVES GRBM_GUI_ACTIVE -d pmc -o run --output-format csv -- ./vadd
    cat $(find trace -name "*kernel_stats.csv")
    head -2 $(find pmc -name "*counter_collection.csv")'
