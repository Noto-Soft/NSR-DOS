import struct
from PIL import Image
import sys

def convert_bmp_to_raw(input_path, output_path):
    img = Image.open(input_path)

    if img.mode != 'P':
        raise ValueError("Image must be 8-bit paletted (indexed)")

    width, height = img.size
    pixel_data = list(img.getdata())

    header = b'BM'
    header += struct.pack('<H', width)   
    header += struct.pack('<H', height)  

    while len(header) % 16 != 0:
        header += b'\x00'

    with open(output_path, 'wb') as f:
        f.write(header)
        f.write(bytearray(pixel_data))

    print(f"Done: wrote {output_path}")


convert_bmp_to_raw(sys.argv[1], sys.argv[2])
