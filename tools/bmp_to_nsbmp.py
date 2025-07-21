import struct
from PIL import Image
import sys

def convert_bmp_to_raw(input_path, output_path, include_palette=False):
	img = Image.open(input_path)

	if img.mode != 'P':
		raise ValueError("Image must be 8-bit paletted (indexed)")

	width, height = img.size
	pixel_data = list(img.getdata())

	# Header: 'BM' or 'CM' + width + height (2 bytes each, little-endian)
	header = b'CM' if include_palette else b'BM'
	header += struct.pack('<H', width)
	header += struct.pack('<H', height)

	with open(output_path, 'wb') as f:
		f.write(header)

		# If -c is passed, write palette (768 bytes, padded if needed)
		if include_palette:
			palette = img.getpalette()
			if palette is None:
				raise ValueError("No palette found in image")

			needed = 256 * 3
			palette = palette[:needed] + [0] * (needed - len(palette))
			palette = [v // 4 for v in palette]
			f.write(bytearray(palette))

		# Write raw indexed pixel data
		f.write(bytearray(pixel_data))

	print(f"Done: wrote {output_path}")

# --- CLI handling ---
if __name__ == "__main__":
	if len(sys.argv) < 3:
		print("Usage: python bmp2raw.py input.bmp output.raw [-c]")
		sys.exit(1)

	include_palette = '-c' in sys.argv
	args = [arg for arg in sys.argv[1:] if arg != '-c']

	input_path = args[0]
	output_path = args[1]

	convert_bmp_to_raw(input_path, output_path, include_palette)
