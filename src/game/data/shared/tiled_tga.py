#======================================================================
# Tiled TGA to Genesis OLD
#
# tiled_tga.py tga_file out_folder
#======================================================================

import sys
import os.path

#======================================================================
# -------------------------------------------------
# Settings
# -------------------------------------------------

# False: Normal mode
# True: Auto-alignfix for Interlace Double mode
DOUBLE_MODE = False

# False: don't write a blank tile
# True: make blank tile at start
BLANK_CELL  = False

#======================================================================
# -------------------------------------------------
# Values
# -------------------------------------------------

VRAM_ZERO   = 0         # Blank tile
VRAM_START  = 1		# Start at
VRAM_STARTD = 2		# for Double mode
VRAM_MAX    = 0x7F0	# Max VRAM to use

TILE_WIDTH  = 16	# Default Width/Height
TILE_HEIGHT = 16

#======================================================================
# -------------------------------------------------
# Subs
# -------------------------------------------------

def make_cell(XPOS,YPOS,COLOR):
	global IMG_WIDTH
	XPOS = XPOS * 8
	YPOS = (IMG_WIDTH * YPOS) * 8

	d = image_addr+XPOS+YPOS
	c = 8
	while c:
		input_file.seek(d)
		b = 4
		while b:
			a = 0
			e = (ord(input_file.read(1)) & 0xFF)
			f = (ord(input_file.read(1)) & 0xFF)

			g = e >> 4
			if g == COLOR:
				a = (e << 4) & 0xF0
			g = f >> 4
			if g == COLOR:
				a += f & 0x0F

			#a = (ord(input_file.read(1)) & 0x0F) << 4
			#a += (ord(input_file.read(1)) & 0x0F)
			out_art.write( bytes([a]) )
			b -= 1

		c -= 1
		d += IMG_WIDTH

def chk_cell(XPOS,YPOS,COLOR):
	global IMG_WIDTH
	XPOS = XPOS * 8
	YPOS = (IMG_WIDTH * YPOS) * 8
	a = 0
	d = image_addr+XPOS+YPOS

	x = 0
	y = 0

	c = 8
	while c:
		input_file.seek(d)
		b = 8
		while b:
			f = (ord(input_file.read(1)) & 0xFF)

			g = f >> 4
			if g == COLOR:
				if DOUBLE_MODE == True:
					if (f & 0x0F) != 0:
						a += a + x + y + (f & 0x0F)
				else:
					a += a + (f & 0x0F)
			#z += x + y

			x += 1
			b -= 1

		x = 0
		y += 1
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

input_file.seek(0x5)					#$05, palsize
size_pal = ord(input_file.read(1))

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
  r = r >> 5
  r = r << 1
  g = g >> 5
  g = g << 1
  b = b >> 5
  b = b << 1
  g = g << 4
  gr = g+r
  out_pal.write( bytes([b]) )
  out_pal.write( bytes([gr]))
  d0 -= 1

# ----------------------
# Make NULL block
# ----------------------

if DOUBLE_MODE == True:
  if TILE_HEIGHT & 8:
    print("INVALID HEIGHT FOR DOUBLE MODE")
    input_file.close()
    out_art.close()
    out_pal.close()
    out_map.close()
    exit()
  else:
   if BLANK_CELL == True:
     out_art.write(  bytes(0x40) )
     #VRAM_STARTD += 2
   map_vram = VRAM_STARTD
   a = int( (TILE_WIDTH>>3)*(TILE_HEIGHT>>3) )
   b = VRAM_ZERO&0x7FE >> 8 & 0xFF
   c = VRAM_ZERO&0x7FE & 0xFF
   d = VRAM_ZERO&0x7FE+1 >> 8 & 0xFF
   e = VRAM_ZERO&0x7FE+1 & 0xFF

   a = a >> 1
   out_map.write(  bytes([b,c,d,e]*(a)) )

else:
  if BLANK_CELL == True:
    out_art.write(  bytes(0x20) )
  map_vram = VRAM_START
  a = int( (TILE_WIDTH>>3)*(TILE_HEIGHT>>3) )
  b = VRAM_ZERO >> 8 & 0xFF
  c = VRAM_ZERO & 0xFF
  out_map.write(  bytes([b,c]*(a)) )

#======================================================================
# -------------------------------------------------
# Convert tga
# -------------------------------------------------

cells_used = 0
x_pos = 0
y_pos = 0
image_addr=input_file.tell()
last_warn = False

# --------------------------------
# DOUBLE MODE
# --------------------------------

if DOUBLE_MODE == True:
  if TILE_HEIGHT & 8 == True:
    print("INVALID HEIGHT FOR DOUBLE MODE")
    input_file.close()
    out_art.close()
    out_pal.close()
    out_map.close()
    exit()

  y_pos=0
  cell_y_size=IMG_HEIGHT/TILE_HEIGHT
  while cell_y_size:
    x_pos=0
    cell_x_size=IMG_WIDTH/TILE_WIDTH
    while cell_x_size:
      x_at = 0
      x_size = TILE_WIDTH>>3
      while x_size:
        y_at = 0
        y_size = TILE_HEIGHT>>4 #TILE_HEIGHT>>3
        while y_size:
          d3 = 0
          d4 = 0

          d1 = VRAM_ZERO & 0x7FE
          d2 = VRAM_ZERO & 0x7FE
          d6 = 4
          while d6:
            d5 = chk_cell(x_pos+x_at,y_pos+y_at,d4) | chk_cell(x_pos+x_at,y_pos+(y_at+1),d4)
            if d5 != 0:
              d3 = d4
              d6 = False
              break
            d4 += 1
            d6 -= 1
          if d5 != 0:
            #if clist_srch(d5,3)[0] == True:
              #d7=clist_srch(d5,3)[1]
              #d1=clist[d7+1]
              #d2=clist[d7+2]
              ##print("FOUND DOUBLE",hex(d1),hex(d2))
            #else:
            if last_warn == False:
              make_cell(x_pos+x_at,y_pos+y_at,d3)
              make_cell(x_pos+x_at,y_pos+(y_at+1),d3)
              cells_used += 2
              if cells_used > VRAM_MAX:
                print("WARNING: ran out of vram, ignoring new cells")
                map_vram = 0
                last_warn = True

              d3 = d3 << 13
              d1=map_vram|d3
              d2=(map_vram+1)|d3
              clist.append(d5)
              clist.append(d1)
              clist.append(d2)
              map_vram+=2
          out_map.write( bytes([(d1>>8)&0xFF,d1&0xFF]) )
          out_map.write( bytes([(d2>>8)&0xFF,d2&0xFF]) )
          y_at += 2
          y_size -= 1
        x_at += 1
        x_size -= 1

      x_pos += TILE_WIDTH>>3
      cell_x_size -= 1

    y_pos += TILE_HEIGHT>>3
    cell_y_size -= 1

# --------------------------------
# NORMAL MODE
# --------------------------------
else:
  y_pos=0
  cell_y_size=IMG_HEIGHT/TILE_HEIGHT
  while cell_y_size:
    x_pos=0
    cell_x_size=IMG_WIDTH/TILE_WIDTH
    while cell_x_size:
      x_at = 0
      x_size = TILE_WIDTH>>3
      while x_size:
        y_at = 0
        y_size = TILE_HEIGHT>>3
        while y_size:
          d1 = VRAM_ZERO & 0x7FF
          d2 = 0
          d4 = 0
          d5 = 4
          while d5:
            d2 = chk_cell(x_pos+x_at,y_pos+y_at,d4)
            if d2 != 0:
              d3 = d4
              d5 = False
              break
            d4 += 1
            d5 -= 1
          if d2 != 0:
            if clist_srch(d2,2)[0] == True:
              d7=clist_srch(d2,2)[1]
              d1=clist[d7+1]
            else:
              make_cell(x_pos+x_at,y_pos+y_at,d3) #write_cell(image_addr+seek_cell(x_pos+x_at,y_pos+y_at))
              cells_used += 1
              if last_warn == False:
                if cells_used > VRAM_MAX:
                  print("WARNING: ran out of vram, ignoring new cells")
                  map_vram = 0
                  last_warn = True
              d3 = d3 << 13
              d1=map_vram|d3
              clist.append(d2)
              clist.append(d1)
              map_vram+=1
          out_map.write( bytes([(d1>>8)&0xFF,d1&0xFF]) )
          y_at += 1
          y_size -= 1
        x_at += 1
        x_size -= 1

      x_pos += TILE_WIDTH>>3
      cell_x_size -= 1

    y_pos += TILE_HEIGHT>>3
    cell_y_size -= 1

print("Used VRAM:",hex(cells_used))
print("Done.")
input_file.close()
out_art.close()
out_pal.close()
out_map.close()
