#include <metal_stdlib>
using namespace metal;

kernel void pixelate(texture2d<float, access::read> inTexture [[texture(0)]],
                    texture2d<float, access::write> outTexture [[texture(1)]],
                    constant float &blockSize [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    
    const uint2 textureSize = uint2(inTexture.get_width(), inTexture.get_height());
    if (gid.x >= textureSize.x || gid.y >= textureSize.y) {
        return;
    }
    
    // 计算当前像素所在的块
    const uint blockSizeInt = uint(blockSize);
    const uint2 blockStart = uint2(gid.x / blockSizeInt, gid.y / blockSizeInt) * blockSizeInt;
    const uint2 blockEnd = min(blockStart + uint2(blockSizeInt), textureSize);
    
    // 计算块内所有像素的平均颜色
    float4 sum = float4(0);
    uint count = 0;
    
    for (uint y = blockStart.y; y < blockEnd.y; y++) {
        for (uint x = blockStart.x; x < blockEnd.x; x++) {
            sum += inTexture.read(uint2(x, y));
            count++;
        }
    }
    
    float4 averageColor = sum / count;
    outTexture.write(averageColor, gid);
} 