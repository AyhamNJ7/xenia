#include "pixel_formats.hlsli"
#include "texture_load.hlsli"

Buffer<uint4> xe_texture_load_source : register(t0);
RWBuffer<uint4> xe_texture_load_dest : register(u0);

[numthreads(8, 32, 1)]
void main(uint3 xe_thread_id : SV_DispatchThreadID) {
  // 1 thread = 4 DXT3A blocks to 16x4 R8 texels (no need to convert to DXT3
  // because the overhead is the same, 2x, but the size must be 4-aligned).
  uint3 block_index = xe_thread_id << uint3(2, 0, 0);
  [branch] if (any(block_index >= xe_texture_load_size_blocks)) {
    return;
  }
  int3 texel_index_host = int3(block_index) << int3(2, 2, 0);
  int block_offset_host =
      (XeTextureHostLinearOffset(texel_index_host,
                                 xe_texture_load_height_texels,
                                 xe_texture_load_host_pitch, 1u) +
       xe_texture_load_host_base) >> 4;
  int elements_pitch_host = xe_texture_load_host_pitch >> 4;
  int block_offset_guest =
      XeTextureLoadGuestBlockOffset(int3(block_index), 8u, 3u) >> 4;
  uint endian = XeTextureLoadEndian();
  uint4 blocks_01 = XeByteSwap(xe_texture_load_source[block_offset_guest],
                               endian);
  // Odd 2 blocks = even 2 blocks + 32 bytes when tiled.
  block_offset_guest += XeTextureLoadIsTiled() ? 2 : 1;
  uint4 blocks_23 = XeByteSwap(xe_texture_load_source[block_offset_guest],
                               endian);
  xe_texture_load_dest[block_offset_host] =
      XeDXT3FourBlocksRowToA8(uint4(blocks_01.xz, blocks_23.xz));
  [branch] if (++texel_index_host.y < int(xe_texture_load_height_texels)) {
    block_offset_host += elements_pitch_host;
    xe_texture_load_dest[block_offset_host] =
        XeDXT3FourBlocksRowToA8(uint4(blocks_01.xz, blocks_23.xz) >> 16u);
    [branch] if (++texel_index_host.y < int(xe_texture_load_height_texels)) {
      block_offset_host += elements_pitch_host;
      xe_texture_load_dest[block_offset_host] =
          XeDXT3FourBlocksRowToA8(uint4(blocks_01.yw, blocks_23.yw));
      [branch] if (++texel_index_host.y < int(xe_texture_load_height_texels)) {
        block_offset_host += elements_pitch_host;
        xe_texture_load_dest[block_offset_host] =
            XeDXT3FourBlocksRowToA8(uint4(blocks_01.yw, blocks_23.yw) >> 16u);
      }
    }
  }
}
