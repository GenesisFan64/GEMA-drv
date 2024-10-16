#======================================================================
# Tiled level to MD
#
# tiled_md.py tmx_file out_folder
#======================================================================

import sys
import os.path
import xml.etree.ElementTree as ET

#======================================================================
# -------------------------------------------------
# Settings
# -------------------------------------------------

# False: Normal mode
# True: Compress prizes (the "prizes" layer MUST be included)
RLE_PRIZES  = False

# False: layout data is on bytes (0-255)
# True: layout data is on words (0-65535)
WIDE_LAYOUT = False

#======================================================================
# -------------------------------------------------
# Values
# -------------------------------------------------

VRAM_ZERO   = 0		# Blank tile
VRAM_START  = 1		# Start at
VRAM_STARTD = 2		# for Double mode
VRAM_MAX    = 0x7FF	# Max VRAM to use

TILE_WIDTH  = 16	# Default Width/Height
TILE_HEIGHT = 16

#======================================================================
# -------------------------------------------------
# Convert blocks
# -------------------------------------------------

# ------------------------------------

cells_used = 0
clist = list()
przrle	= [0,0]

# ------------------------------------

if len(sys.argv) != 2+1:
	print("Usage: inputfile outfolder")
	exit()

if os.path.exists(sys.argv[1]) == False:
	print("Input file not found")
	exit()

MASTERNAME = sys.argv[1][:-4]
PROJFOLDER = sys.argv[2]

if not os.path.exists(PROJFOLDER):
	os.makedirs(PROJFOLDER)
if not os.path.exists(PROJFOLDER+"/layers"):
	os.makedirs(PROJFOLDER+"/layers")

#======================================================================
# -------------------------------------------------
# Make mini head
# -------------------------------------------------

input_file = open(sys.argv[1],"r")
input_file.seek(0)
a = input_file.read().find('<map version="1.9"')
if a != -1:
	input_file.seek(a)
	b = input_file.tell()
	a = input_file.read().find('>')
	input_file.seek(b+1)
	a = input_file.read(a-1).split()
	#print(a)

	#if a[2] != 'tiledversion="1.1.4"':
		#print("invalid Tiled version")
		#input_file.close()
		#quit()
	if a[3] != 'orientation="orthogonal"':
		print("invalid orientation: should be orthogonal")
		input_file.close()
		quit()
	if a[4] != 'renderorder="right-down"':
		print("invalid layout order: should be right-down")
		input_file.close()
		quit()

	width = a[5].split('"')
	height = a[6].split('"')
	blkwidth = a[7].split('"')
	blkheight = a[8].split('"')

	TILE_WIDTH = int(blkwidth[1])
	TILE_HEIGHT = int(blkheight[1])
	LAY_WIDTH = int(width[1])
	LAY_HEIGHT = int(height[1])

#======================================================================
# -------------------------------------------------
# Convert layout
# -------------------------------------------------

input_file.seek(0)
layer_tiletops = list()
tree = ET.parse(sys.argv[1])
root = tree.getroot()
for a in root.findall('tileset'):
	#b = a.find('data').text.replace("\n","")
	layer_tiletops.append(int(a.get('firstgid')))

max_layers = 0
input_file.seek(0)
layer_tags = list()
layer_data = list()
tree = ET.parse(sys.argv[1])
root = tree.getroot()
for a in root.findall('layer'):
	b = a.find('data').text.replace("\n","")
	layer_tags.append(a.get('name'))
	layer_data.append(b)
	max_layers += 1
#print(layer_data)

cntr_lyrs = max_layers
indx_lyrs = 0
while cntr_lyrs:
	lyr_file = open(PROJFOLDER+"/layers/"+layer_tags[indx_lyrs]+".bin","wb")

	a = layer_data[indx_lyrs].split(",")
	b = len(a)
	e = 0
	while b:
		lyr_data = int(a[e])
		#print(lyr_data)
		if lyr_data != 0:
			h = len(layer_tiletops)
			g = h-1
			while h:
				if lyr_data > layer_tiletops[g]-1:
					lyr_data -= layer_tiletops[g]-1
					break
				g -= 1
				h -= 1

		if WIDE_LAYOUT == True:
			lyr_file.write(bytes([ f>>8&0xFF , f&0xFF ]))
		else:
			if lyr_data > 255:
				print("WARNING: ran out of bytes, value:",hex(lyr_data))
				lyr_data = lyr_data&0xFF
			lyr_file.write(bytes([ lyr_data&0xFF ]))
			#print("LEL")
		e += 1
		b -= 1

	lyr_file.close()
	indx_lyrs += 1  # next layer
	cntr_lyrs -= 1	# decrement counter

#======================================================================
# -------------------------------------------------
# Compress Prizes to RLE
# -------------------------------------------------

if RLE_PRIZES == True:
	in_prz = open(PROJFOLDER+"/"+"prizes"+".bin","rb")
	out_prz = open(PROJFOLDER+"/"+"prizes_rle"+".bin","wb")
	in_prz.seek(0,os.SEEK_END)
	c = in_prz.tell()
	in_prz.seek(0)

	while c:
		a = ord(in_prz.read(1)) & 0xFF
		c -= 1

		b = przrle[1]
		if b != a:
			przrle[0] = 0
			out_prz.seek(+2,1)

		przrle[1] = a
		przrle[0] +=1
		if przrle[0] > 0xFE:
			przrle[0] = 1
			out_prz.seek(+2,1)
		out_prz.write( bytes([ int(przrle[0]&0xFF) ]))
		out_prz.write( bytes([ int(przrle[1]&0xFF) ]))
		out_prz.seek(-2,1)

	out_prz.seek(+2,1)
	out_prz.write( bytes([0xFF]))
	out_prz.close()
	in_prz.close()

# ======================================================================
# -------------------------------------------------
# Convert objects
# -------------------------------------------------

input_file.seek(0)
has_objects = False

c = input_file.tell()
b = input_file.read()
a = b.find("<objectgroup")
if a != -1:
	input_file.seek( (c+a)+1 )

	c = input_file.tell()
	b = input_file.read()
	a = b.find('<object')
	if a != -1:
		has_objects = True
		input_file.seek( c+a )
		c = input_file.tell()
		b = input_file.read()
		flen = b.find("</objectgroup>")
		input_file.seek( c )

		d = 0
		b = input_file.read(flen).replace("<","").replace("/>","").replace("\n","").split()
		e = len(b)

		OBJ_NAME = list()
		OBJ_X    = list()
		OBJ_Y    = list()
		OBJ_TYPE = list()

		f = -1
		while e:
			c = b[d].replace("=","").split('"')
			if c[0] == "id":
				f += 1
				OBJ_NAME.append(0)
				OBJ_TYPE.append(0)
				OBJ_X.append(0)
				OBJ_Y.append(0)

			if c[0] == "name":
				OBJ_NAME[f] = c[1]
			if c[0] == "type":
				OBJ_TYPE[f] = c[1]
			if c[0] == "x":
				OBJ_X[f] = int(float(c[1]))
			if c[0] == "y":
				OBJ_Y[f] = int(float(c[1]))
			d += 1
			e -= 1

	out_obj = open(PROJFOLDER+"/"+"objects"+".asm","w")
	if has_objects == True:
		a = len(OBJ_NAME)
		b = 0
		while a:
			out_obj.write("\t\tdc.l "+OBJ_NAME[b]+"\n")
			out_obj.write("\t\tdc.w "+str(OBJ_X[b])+","+str(OBJ_Y[b])+"\n")
			out_obj.write("\t\tdc.w "+str(OBJ_TYPE[b])+","+"0"+"\n")
			b += 1
			a -= 1

	out_obj.write("\t\tdc.l -1\n")
	out_obj.close()

input_file.close()
