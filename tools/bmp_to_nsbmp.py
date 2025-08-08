import struct
from PIL import Image
import sys

def convert_bmp_to_raw(input_path, output_path, use_default_vga=False):
    img = Image.open(input_path)

    if img.mode != 'P':
        raise ValueError("Image must be 8-bit paletted (indexed)")

    width, height = img.size
    pixel_data = list(img.getdata())

    # Header: 'CM' = custom palette, 'BM' = built-in (default VGA) palette
    header = b'BM' if use_default_vga else b'CM'
    header += struct.pack('<H', width)
    header += struct.pack('<H', height)

    with open(output_path, 'wb') as f:
        f.write(header)

        if not use_default_vga:
            # Write palette (768 bytes)
            palette = img.getpalette()
            if palette is None:
                raise ValueError("No palette found in image")
            if len(palette) % 3 != 0:
                raise ValueError(f"Palette is not in 24-bit RGB format (length={len(palette)})")
            needed = 256 * 3
            palette = palette[:needed] + [0] * (needed - len(palette))
            palette = [v // 4 for v in palette]  # Convert to VGA DAC range
            f.write(bytearray(palette))

        # Write raw indexed pixel data
        f.write(bytearray(pixel_data))

    print(f"[OK] Converted {input_path} to {output_path}")

# --- CLI handling ---
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python bmp2raw.py input.bmp output.raw [-v]")
        sys.exit(1)

    use_default_vga = '-v' in sys.argv
    args = [arg for arg in sys.argv[1:] if arg != '-v']

    input_path = args[0]
    output_path = args[1]

    convert_bmp_to_raw(input_path, output_path, use_default_vga)
