#======================================================================
# TGA to MARS sprites
#
# python tga2marsspr.py INPUT_IMAGE.tga OUT_FOLDER
#======================================================================

# Format:
#
# .frame:
# dc.w num_ofpz
#
# dc.b Y
# dc.b size
# dc.w vram
# dc.w vram/2
# dc.w x
# ; next pz

#======================================================================

import sys
import os.path

#======================================================================
# -------------------------------------------------
# SETTINGS
# -------------------------------------------------

# FRAME_WDTH  = 32
# FRAME_HGHT  = 48

#======================================================================
# -------------------------------------------------
# Variables
# -------------------------------------------------

#======================================================================
# -------------------------------------------------
# Subs
# -------------------------------------------------

#======================================================================
# -------------------------------------------------
# Init
# -------------------------------------------------

if len(sys.argv) != 1+4:
 print("Usage: inputfile outputfolder width height")
 exit()

if os.path.exists(sys.argv[1]) == False:
 print("Input file not found")
 exit()

user_thisname = sys.argv[1][:-4]
user_folder   = sys.argv[2]
user_wdth    = sys.argv[3]
user_hght    = sys.argv[4]

input_file = open(sys.argv[1],"rb")
if not os.path.exists(user_folder):
 os.makedirs(user_folder)

user_folder = user_folder+"/"

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
 print("IMAGE MUST BE INDEXED, UNCOMPRESSED, TOP-LEFT")
 print("GOT THIS TYPE:",hex(image_type))
 quit()

#======================================================================
# -------------------------------------------------
# Palette
# -------------------------------------------------

if has_pal == True:
 output_file = open(user_folder+"pal.bin","wb")
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
 FRAME_WDTH = int(user_wdth)
 FRAME_HGHT = int(user_hght)
 GLBL_IMGPOS = input_file.tell()  # SET image top-left global
 art_file = output_file = open(user_folder+"art.bin","wb")

 frame_pos = GLBL_IMGPOS
 numof_frames = int(img_height/FRAME_HGHT)
 for curr_frame in range(numof_frames):

   b = frame_pos
   for y_read in range(FRAME_HGHT):
     input_file.seek(b)
     for x_read in range(FRAME_WDTH):
       a = ord(input_file.read(1)) & 0xFF
       art_file.write(bytes([a]))
       #art_file.write(bytes([0,a]))
     b += FRAME_WDTH

   frame_pos += FRAME_WDTH*FRAME_HGHT

#======================================================================
# ----------------------------
# End
# ----------------------------

print("Done.")
input_file.close()
art_file.close()
