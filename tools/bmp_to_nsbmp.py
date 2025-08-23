import struct
from PIL import Image
import sys

def convert_bmp_to_nsbmp(input_path, output_path, use_default_vga=False, small=False, mono=False):
    img = Image.open(input_path)

    if img.mode != 'P' and not mono:
        raise ValueError("Image must be paletted (indexed) for paletted NSBMP types")

    width, height = img.size
    pixel_data = list(img.getdata())

    # Always NSBMP 2.0
    header = b'Bm'

    # Determine subtype
    if mono:
        subtype = b'M'   # 1bpp monochrome
    elif small:
        subtype = b'R'   # reduced 4bpp palette
    elif use_default_vga:
        subtype = b'V'   # VGA default palette
    else:
        subtype = b'C'   # custom 8bpp palette

    header += subtype
    header += struct.pack('<H', width)
    header += struct.pack('<H', height)

    with open(output_path, 'wb') as f:
        f.write(header)

        if subtype == b'M':
            # Monochrome palette (2 colors = 6 bytes)
            palette = img.getpalette()
            if palette is None:
                palette = [0, 0, 0, 255, 255, 255]
            needed = 2 * 3
            palette = palette[:needed] + [0] * (needed - len(palette))
            palette = [v // 4 for v in palette]  # scale 0–255 -> 0–63
            f.write(bytearray(palette))

            # Pack pixels into 1bpp
            packed_pixels = bytearray()
            for y in range(height):
                row = pixel_data[y * width : (y + 1) * width]
                byte_val, bit_count = 0, 0
                for p in row:
                    bit = p & 1
                    byte_val = (byte_val << 1) | bit
                    bit_count += 1
                    if bit_count == 8:
                        packed_pixels.append(byte_val)
                        byte_val, bit_count = 0, 0
                if bit_count > 0:
                    byte_val <<= (8 - bit_count)
                    packed_pixels.append(byte_val)
            f.write(packed_pixels)

        elif subtype == b'R':
            # 4bpp palette (16 colors = 48 bytes)
            palette = img.getpalette()
            if palette is None:
                raise ValueError("No palette found in image")
            needed = 16 * 3
            palette = palette[:needed] + [0] * (needed - len(palette))
            palette = [v // 4 for v in palette]
            f.write(bytearray(palette))

            # Pack 4bpp pixels
            packed_pixels = bytearray()
            for i in range(0, len(pixel_data), 2):
                p1 = pixel_data[i] & 0x0F
                p2 = pixel_data[i + 1] & 0x0F if i + 1 < len(pixel_data) else 0
                packed_pixels.append((p1 << 4) | p2)
            f.write(packed_pixels)

        elif subtype == b'C':
            # 8bpp custom palette (256 colors = 768 bytes)
            palette = img.getpalette()
            if palette is None:
                raise ValueError("No palette found in image")
            needed = 256 * 3
            palette = palette[:needed] + [0] * (needed - len(palette))
            palette = [v // 4 for v in palette]
            f.write(bytearray(palette))
            f.write(bytearray(pixel_data))

        elif subtype == b'V':
            # 8bpp VGA default palette (no palette data written)
            f.write(bytearray(pixel_data))

    print(f"[OK] Converted {input_path} -> {output_path} (NSBMP 2.0, subtype {subtype.decode()})")


# --- CLI handling ---
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python bmp2nsbmp.py input.bmp output.raw [-v] [-s] [-m]")
        sys.exit(1)

    use_default_vga = '-v' in sys.argv
    small = '-s' in sys.argv
    mono = '-m' in sys.argv
    args = [arg for arg in sys.argv[1:] if arg not in ['-v', '-s', '-m']]

    input_path = args[0]
    output_path = args[1]

    convert_bmp_to_nsbmp(input_path, output_path, use_default_vga, small, mono)
