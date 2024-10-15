#======================================================================
# Tiled TGA to 32X
#
# tiled_tga_mars.py tga_file out_folder
#======================================================================

import sys
import os.path

#======================================================================
# -------------------------------------------------
# Settings
# -------------------------------------------------

# False: don't write a blank tile
# True: make blank tile at start
BLANK_CELL  = True
# Values
VRAM_ZERO   = 0		# Blank tile
VRAM_START  = 1		# Start at
VRAM_MAX    = 0x1FF	# Max VRAM to use

TILE_WIDTH  = 16	# Default Width/Height
TILE_HEIGHT = 16

#======================================================================
# -------------------------------------------------
# Subs
# -------------------------------------------------

def make_block(XPOS,YPOS):
	global IMG_WIDTH
	#XPOS = XPOS
	YPOS = (IMG_WIDTH*YPOS)

	d = image_addr+XPOS+YPOS
	c = TILE_HEIGHT
	while c:
		input_file.seek(d)
		b = TILE_WIDTH
		while b:
			a = (ord(input_file.read(1)) & 0xFF)
			out_art.write( bytes([a]) )
			b -= 1

		c -= 1
		d += IMG_WIDTH

def chk_block(XPOS,YPOS):
	global IMG_WIDTH
	YPOS = (IMG_WIDTH * YPOS)
	a = 0
	d = image_addr+XPOS+YPOS
	c = TILE_HEIGHT
	while c:
		input_file.seek(d)
		b = TILE_WIDTH
		while b:
			e = (ord(input_file.read(1)) & 0xFF)
			if e != 0:
				a = 1
			b -= 1

		c -= 1
		d += IMG_WIDTH

	return a

def seek_cell(x,y):
  x = x<<3
  y = y*(IMG_WIDTH*8)

  out_offset=x+y
  return(out_offset)

def chks_make(lay):
  d7 = 0
  d5 = 0

  d4 = 0
  d1 = 8
  while d1:
    input_file.seek(lay)
    d2 = 8
    while d2:
      byte = ord(input_file.read(1))
      if byte != 0:
        d3 = byte + d4 + d5 + d7
        d7 += d3
      d4 += 1
      d2 -= 1

    d4 = 0
    d5 += 1
    lay += IMG_WIDTH
    d1 -= 1

  return(d7)

def clist_srch(a,f):
	global clist
	b = False
	c = 0

	d = len(clist)/f
	e = 0
	while d:
		if clist[e] == a:
			b = True
			c = e#clist[e+1]
			return b,c
		e += f
		d -= 1

	return b,c

# ======================================================================
# -------------------------------------------------
# Read TGAs
# -------------------------------------------------

clist = list()
PROJFOLDER = sys.argv[2]
if not os.path.exists(PROJFOLDER):
	os.makedirs(PROJFOLDER)

input_file = open("_res/"+sys.argv[1],"rb")
in_tgafile = sys.argv[1][:-4]
out_art    = open(PROJFOLDER+"/"+in_tgafile+"_art.bin","wb")
out_pal    = open(PROJFOLDER+"/"+in_tgafile+"_pal.bin","wb")
out_map    = open(PROJFOLDER+"/"+in_tgafile+"_blocks.bin","wb")

# input_file = open(sys.argv[3],"rb")
# out_art    = open(PROJFOLER+"/"+"m_art.bin","wb")
# out_pal    = open(PROJFOLER+"/"+"m_pal.bin","wb")

input_file.seek(0x5)					#$05, palsize
a = ord(input_file.read(1)) & 0xFF
b = ord(input_file.read(1)) & 0xFF
a = a | (b << 8)
size_pal = a

input_file.seek(0xC)					#$0C, xsize,ysize (little endian)
x_r = ord(input_file.read(1))
x_l = (ord(input_file.read(1))<<8)
IMG_WIDTH = x_l+x_r
y_r = ord(input_file.read(1))
y_l = (ord(input_file.read(1))<<8)
IMG_HEIGHT = (y_l+y_r)

a = IMG_WIDTH&7
b = IMG_HEIGHT&7
c = "X SIZE IS MISALIGNED"
d = "Y SIZE IS MISALIGNED"
e = " "
f = " "
g = False
if a != 0:
  print( hex(a) )
  e = c
  g = True
if b !=0:
  f = d
  g = True

if g == True:
  print( "WARNING:",e,f )

# ----------------------
# Write palette
# ----------------------

input_file.seek(0x12)
d0 = size_pal
while d0:
  b = ord(input_file.read(1))
  g = ord(input_file.read(1))
  r = ord(input_file.read(1))

  r = (r>>3)&0x1F
  g = (g>>3)&0x1F
  b = (b>>3)&0x1F

  r = (g<<5)+r & 0xFF
  b = (g>>3)+(b<<2) & 0xFF

  #print(hex(b),hex(r))

  out_pal.write( bytes([b,r]) )
  d0 -= 1

# ----------------------
# Make NULL block
# ----------------------

# out_art.write(bytes(TILE_WIDTH*TILE_HEIGHT))

#======================================================================
# -------------------------------------------------
# Convert TGA
# -------------------------------------------------

blk_id = 1
image_addr=input_file.tell()
y_pos=0
cell_y_size=IMG_HEIGHT/TILE_HEIGHT
while cell_y_size:
	x_pos=0
	cell_x_size=IMG_WIDTH/TILE_WIDTH
	while cell_x_size:
		# ----
		b = 0
		a = chk_block(x_pos,y_pos)
		if a != 0:
                  make_block(x_pos,y_pos)
                  b = blk_id
                  blk_id += 1

		# ----
		out_map.write(bytes([(b>>8)&0xFF,b&0xFF]))
		x_pos += TILE_WIDTH
		cell_x_size -= 1
	y_pos += TILE_HEIGHT
	cell_y_size -= 1

print("Done.")
input_file.close()
out_art.close()
out_pal.close()
out_map.close()
