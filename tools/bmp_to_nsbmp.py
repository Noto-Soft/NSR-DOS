import struct
from PIL import Image
import sys

def convert_bmp_to_raw(input_path, output_path, use_default_vga=False, small=False, mono=False):
    img = Image.open(input_path)

    if img.mode != 'P' and not mono:
        raise ValueError("Image must be paletted (indexed) for BM/CM/4M formats")

    width, height = img.size
    pixel_data = list(img.getdata())

    # Header
    if mono:
        header = b'MM'
    elif small:
        header = b'4M'
    else:
        header = b'BM' if use_default_vga else b'CM'

    header += struct.pack('<H', width)
    header += struct.pack('<H', height)

    with open(output_path, 'wb') as f:
        f.write(header)

        if mono:
            # 1bpp format (with 2-color palette)
            palette = img.getpalette()
            if palette is None:
                # default black & white palette (scaled to 6-bit VGA values)
                palette = [0, 0, 0, 63, 63, 63]
            else:
                needed = 2 * 3  # two colors (RGB each)
                palette = palette[:needed] + [0] * (needed - len(palette))
                palette = [v // 4 for v in palette]  # scale 0-255 -> 0-63
            f.write(bytearray(palette))  # write color0 + color1

            # Pack pixels (1bpp)
            packed_pixels = bytearray()
            for y in range(height):
                row = pixel_data[y * width : (y + 1) * width]
                byte_val = 0
                bit_count = 0
                for p in row:
                    bit = p & 1  # palette index (0 or 1)
                    byte_val = (byte_val << 1) | bit
                    bit_count += 1
                    if bit_count == 8:
                        packed_pixels.append(byte_val)
                        byte_val = 0
                        bit_count = 0
                if bit_count > 0:  # pad remaining bits in row
                    byte_val <<= (8 - bit_count)
                    packed_pixels.append(byte_val)
            f.write(packed_pixels)

        elif small:
            # 16-color 4bpp format
            palette = img.getpalette()
            if palette is None:
                raise ValueError("No palette found in image")
            needed = 16 * 3
            palette = palette[:needed] + [0] * (needed - len(palette))
            palette = [v // 4 for v in palette]
            f.write(bytearray(palette))

            packed_pixels = bytearray()
            for i in range(0, len(pixel_data), 2):
                p1 = pixel_data[i] & 0x0F
                if i + 1 < len(pixel_data):
                    p2 = pixel_data[i + 1] & 0x0F
                else:
                    p2 = 0
                packed_pixels.append((p1 << 4) | p2)
            f.write(packed_pixels)

        else:
            # 256-color 8bpp format
            if not use_default_vga:
                palette = img.getpalette()
                if palette is None:
                    raise ValueError("No palette found in image")
                needed = 256 * 3
                palette = palette[:needed] + [0] * (needed - len(palette))
                palette = [v // 4 for v in palette]
                f.write(bytearray(palette))
            f.write(bytearray(pixel_data))

    print(f"[OK] Converted {input_path} to {output_path}")


# --- CLI handling ---
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python bmp2raw.py input.bmp output.raw [-v] [-s] [-m]")
        sys.exit(1)

    use_default_vga = '-v' in sys.argv
    small = '-s' in sys.argv
    mono = '-m' in sys.argv
    args = [arg for arg in sys.argv[1:] if arg not in ['-v', '-s', '-m']]

    input_path = args[0]
    output_path = args[1]

    convert_bmp_to_raw(input_path, output_path, use_default_vga, small, mono)
