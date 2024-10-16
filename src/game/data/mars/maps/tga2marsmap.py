#======================================================================
#
#======================================================================

#======================================================================

import sys
import os.path

#======================================================================
# -------------------------------------------------
# SETTINGS
# -------------------------------------------------

TILE_SIZE     = 16
TILE_START    = 1
TILE_NULL     = 0
TILE_MAX      = 0x1FF

#======================================================================
# -------------------------------------------------
# Variables
# -------------------------------------------------

clist = list()

#======================================================================
# -------------------------------------------------
# Subs
# -------------------------------------------------

def make_tile(XPOS,YPOS):
 global GLBL_IMGWDTH
 global GLBL_IMGPOS
 curr_pos = GLBL_IMGPOS+((YPOS*GLBL_IMGWDTH)*16)+(XPOS*16)
 c = TILE_SIZE
 while c:
  input_file.seek(curr_pos)
  d = TILE_SIZE
  while d:
   a = ord(input_file.read(1)) & 0xFF
   art_file.write(bytes([a]))
   d -= 1
  curr_pos += GLBL_IMGWDTH
  c -= 1

def chk_tile(XPOS,YPOS):
 global GLBL_IMGWDTH
 global GLBL_IMGPOS

 # LEFT-RIGHT / TOP-BOTTOM
 a = 0
 yloop = TILE_SIZE
 ypixl = 0
 curr_pos = GLBL_IMGPOS+((YPOS*GLBL_IMGWDTH)*16)+(XPOS*16)
 while yloop:
  xpixl = 0
  xloop = TILE_SIZE
  input_file.seek(curr_pos)
  while xloop:
   e = ord(input_file.read(1)) & 0xFF
   if e != 0:
    a += e|e+xpixl+ypixl
   xpixl += 1
   xloop -= 1
  curr_pos += GLBL_IMGWDTH
  ypixl += TILE_SIZE
  yloop -= 1

 b = 0
 c = 0
 d = 0
 return a,b,c,d

def clist_srch(a):
	global clist
	b = False
	c = 0

	d = len(clist)/2
	e = 0
	while d:
		if clist[e] == a:
			b = True
			c = clist[e+1]
			return b,c
		e += 2
		d -= 1

	return b,c

#======================================================================
# -------------------------------------------------
# Init
# -------------------------------------------------

if len(sys.argv) != 2+1:
	print("Usage: tga2md.py image.tga out_folder")
	exit()
if os.path.exists(sys.argv[1]) == False:
	print("TGA file not found")
	exit()

MAIN_NAME   = sys.argv[1][:-4]
FOLDER_NAME = sys.argv[2]
if not os.path.exists(FOLDER_NAME):
    os.makedirs(FOLDER_NAME)
input_file  = open(sys.argv[1],"rb")
user_thisname = FOLDER_NAME+"/"

# if len(sys.argv) != 1+1:
#  print("Usage: inputfile outputfile")
#  exit()
#
# if os.path.exists(sys.argv[1]) == False:
#  print("Input file not found")
#  exit()
#
# user_thisname = sys.argv[1][:-4]
# input_file = open(sys.argv[1],"rb")

#======================================================================
# -------------------------------------------------
# Read headers
# -------------------------------------------------

#    0  -  No image data included.
#    1  -  Uncompressed, color-mapped images.
#    2  -  Uncompressed, RGB images.
#    3  -  Uncompressed, black and white images.
#    9  -  Runlength encoded color-mapped images.
#   10  -  Runlength encoded RGB images.
#   11  -  Compressed, black and white images.
#   32  -  Compressed color-mapped data, using Huffman, Delta, and
#          runlength encoding.
#   33  -  Compressed color-mapped data, using Huffman, Delta, and
#          runlength encoding.  4-pass quadtree-type process.

input_file.seek(1)
color_type = ord(input_file.read(1))
image_type = ord(input_file.read(1))

# start checking
#print("CURRENT IMAGE TYPE: "+hex(image_type))

if color_type == 1:
 #print("FOUND PALETTE")
 pal_start = ord(input_file.read(1))
 pal_start += ord(input_file.read(1)) << 8
 pal_len = ord(input_file.read(1))
 pal_len += ord(input_file.read(1)) << 8
 ignore_this = ord(input_file.read(1))
 has_pal = True

if image_type == 1:
 #print("IMAGE TYPE 1: Indexed")
 img_xstart = ord(input_file.read(1))
 img_xstart += ord(input_file.read(1)) << 8
 img_ystart = ord(input_file.read(1))
 img_ystart += ord(input_file.read(1)) << 8
 img_width = ord(input_file.read(1))
 img_width += ord(input_file.read(1)) << 8
 img_height = ord(input_file.read(1))
 img_height += ord(input_file.read(1)) << 8
 img_pixbits = ord(input_file.read(1))
 img_type = ord(input_file.read(1))
 #print( hex(img_type) )

 #0 = Origin in lower left-hand corner
 #1 = Origin in upper left-hand corner
 if (img_type >> 5 & 1) == False:
  print("ERROR: TOP LEFT images only")
  quit()
 has_img = True
 GLBL_IMGWDTH = img_width # SET width global
else:
 print("IMAGE TYPE NOT SUPPORTED:",hex(image_type))
 #print("MUST BE INDEXED, TOP-LEFT")
 quit()

#======================================================================
# -------------------------------------------------
# Palette
# -------------------------------------------------

if has_pal == True:
 output_file = open(user_thisname+"pal.bin","wb")
 d = pal_len
 while d:
  d -= 1

  r = (ord(input_file.read(1)) & 0xF8 ) << 7
  g = (ord(input_file.read(1)) & 0xF8 ) << 2
  b = (ord(input_file.read(1)) & 0xF8 ) >> 3
  a = (r|g|b) >> 8 & 0xFF
  b = (r|g|b) & 0xFF

  output_file.write( bytes([a,b]))
 output_file.close()

#======================================================================
# -------------------------------------------------
# Picture
# -------------------------------------------------

if has_img == True:
 GLBL_IMGPOS = input_file.tell()  # SET image top-left global
 art_file = open(user_thisname+"art.bin","wb")
 map_file = open(user_thisname+"map.bin","wb")

 map_indx = TILE_START
 x_size = int(img_width/TILE_SIZE)
 y_size = int(img_height/TILE_SIZE)
 y_read = 0
 for y_loop in range(y_size):
   x_read = 0
   for x_loop in range(x_size):
     # --------

     map_curr = TILE_NULL
     c = chk_tile(x_read,y_read)[0]
     if c != 0:
       if clist_srch(c)[0] == True:
         map_curr = ( clist_srch(c)[1] )
       else:
         make_tile(x_read,y_read)
         if map_indx > TILE_MAX:
           print("RAN OUT OF TILES")
           exit()
         map_curr = map_indx
         clist.append(c)
         clist.append(map_curr)
         map_indx += 1

     a = map_curr>>8 & 0xFF
     b = map_curr & 0xFF
     map_file.write(bytes([a,b]))

     # --------
     x_read += 1
   y_read += 1

#print(clist)
#======================================================================
# ----------------------------
# End
# ----------------------------

print("Art uses:",hex(art_file.tell()))
input_file.close()
art_file.close()
map_file.close()
