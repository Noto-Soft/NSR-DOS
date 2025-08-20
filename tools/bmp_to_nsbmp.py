import struct
from PIL import Image
import sys

def convert_bmp_to_raw(input_path, output_path, use_default_vga=False, small=False):
    img = Image.open(input_path)

    if img.mode != 'P':
        raise ValueError("Image must be paletted (indexed)")

    width, height = img.size
    pixel_data = list(img.getdata())

    if small:
        # 4bpp format
        header = b'4M'
    else:
        header = b'BM' if use_default_vga else b'CM'

    header += struct.pack('<H', width)
    header += struct.pack('<H', height)

    with open(output_path, 'wb') as f:
        f.write(header)

        if small:
            # Write 16-color palette (48 bytes)
            palette = img.getpalette()
            if palette is None:
                raise ValueError("No palette found in image")

            needed = 16 * 3
            palette = palette[:needed] + [0] * (needed - len(palette))
            palette = [v // 4 for v in palette]  # scale to VGA DAC 0–63
            f.write(bytearray(palette))

            # Convert pixel data to 4bpp (two pixels per byte)
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
            if not use_default_vga:
                # Write 256-color palette (768 bytes)
                palette = img.getpalette()
                if palette is None:
                    raise ValueError("No palette found in image")
                needed = 256 * 3
                palette = palette[:needed] + [0] * (needed - len(palette))
                palette = [v // 4 for v in palette]  # VGA DAC 0–63
                f.write(bytearray(palette))

            # Write 8bpp pixels
            f.write(bytearray(pixel_data))

    print(f"[OK] Converted {input_path} to {output_path}")


# --- CLI handling ---
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python bmp2raw.py input.bmp output.raw [-v] [-s]")
        sys.exit(1)

    use_default_vga = '-v' in sys.argv
    small = '-s' in sys.argv
    args = [arg for arg in sys.argv[1:] if arg not in ['-v', '-s']]

    input_path = args[0]
    output_path = args[1]

    convert_bmp_to_raw(input_path, output_path, use_default_vga, small)
