#======================================================================
# TGA to MD sprites
#
# tga2mdspr.py INPUT_IMAGE.tga OUT_FOLDER F_WDTH F_HGHT X_ADJ Y_ADJ
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

PLC_MODE    = True
DOUBLE_MODE = True

#======================================================================
# -------------------------------------------------
# Variables
# -------------------------------------------------

#======================================================================
# -------------------------------------------------
# Subs
# -------------------------------------------------

def make_cell(XPOS,YPOS):
 global GLBL_IMGWDTH
 global GLBL_IMGPOS
 curr_pos = GLBL_IMGPOS+((YPOS*GLBL_IMGWDTH)*8)+(XPOS*8)
 c = 8
 while c:
  input_file.seek(curr_pos)
  d = 8/2
  while d:
   a = ord(input_file.read(1)) & 0x0F
   b = ord(input_file.read(1)) & 0x0F
   a = (a << 4) | b
   art_file.write(bytes([a]))
   d -= 1
  curr_pos += GLBL_IMGWDTH
  c -= 1

def chk_cell(XPOS,YPOS):
 global GLBL_IMGWDTH
 global GLBL_IMGPOS

 # LEFT-RIGHT / TOP-BOTTOM
 a = 0
 yloop = 8
 ypixl = 0
 curr_pos = GLBL_IMGPOS+((YPOS*GLBL_IMGWDTH)*8)+(XPOS*8)
 while yloop:
  xpixl = 0
  xloop = 8
  input_file.seek(curr_pos)
  while xloop:
   e = ord(input_file.read(1)) & 0x0F
   if e != 0:
    a += e+xpixl+ypixl
   xpixl += 1
   xloop -= 1
  curr_pos += GLBL_IMGWDTH
  ypixl += 8
  yloop -= 1

 b = 0
 c = 0
 d = 0
 return a,b,c,d

#======================================================================
# -------------------------------------------------
# Init
# -------------------------------------------------

cell_tell = 0
cell_max = 0

if len(sys.argv) != 1+6:
 print("tga2mdspr usage: input.tga out_folder spr_width spr_height x_center y_center")
 exit()

if os.path.exists(sys.argv[1]) == False:
 print("Input file not found")
 exit()

user_thisname = sys.argv[1][:-4]
user_folder   = sys.argv[2]
frame_wdth    = sys.argv[3]
frame_hght    = sys.argv[4]
frame_xpos    = sys.argv[5]
frame_ypos    = sys.argv[6]

FRAME_WDTH  = int(frame_wdth)
FRAME_HGHT  = int(frame_hght)
SET_XPOS    = int(frame_xpos)*-1
SET_YPOS    = int(frame_ypos)*-1

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
 print("IMAGE TYPE NOT SUPPORTED:",hex(image_type))
 #print("MUST BE INDEXED, TOP-LEFT")
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

  a = (ord(input_file.read(1)) & 0xE0 ) << 4
  a += (ord(input_file.read(1)) & 0xE0 )
  a += (ord(input_file.read(1)) & 0xE0 ) >> 4
  b = (a >> 8) & 0xFF
  a = a & 0xFF

  output_file.write( bytes([b,a]))
 output_file.close()

#======================================================================
# -------------------------------------------------
# Picture
# -------------------------------------------------

if has_img == True:
 art_file = open(user_folder+"art.bin","wb")
 map_file = open(user_folder+"map.bin","wb")
 numof_frames = int(img_height/FRAME_HGHT)

 if PLC_MODE == True:
  plc_file = open(user_folder+"plc.bin","wb")
  dhead_pos = map_file.tell()
  plc_file.write(bytes(numof_frames*2))

 # make MAP data heads
 head_pos = map_file.tell()
 map_file.write(bytes(numof_frames*2))

 GLBL_IMGPOS = input_file.tell()  # SET image top-left global
 cell_vram = 0    # RESET VRAM
 cell_vdplc = 0
 cell_incvram = 0
 for curr_frame in range(0,numof_frames):

  # ------------------------
  # Check this frame
  # ------------------------
  spr_numpz = 0
  cell_got = 0
  cell_used = list()
  spr_data = list()
  if PLC_MODE == True:
   cell_vram = 0  # RESET VRAM for dplc
   cell_incvram = 0
   dplc_used = list()

  x_csize = FRAME_WDTH/8
  y_csize = FRAME_HGHT/8
  x_cell = 0
  x_pos = SET_XPOS #(FRAME_WDTH>>1)*-1
  x_read = x_csize
  while x_read:
   y_cell = 0
   y_pos  = SET_YPOS #(FRAME_HGHT>>1)*-1
   y_read = y_csize
   while y_read:

    # ------------------------
    # make sprite piece
    a = chk_cell(x_cell,y_cell) # top-left
    b = [x_cell,y_cell]

    if b in cell_used:
     pass

    elif a[0] != 0:
     # ------------------------
     # NORMAL DISPLAY
     # ------------------------
     a = x_cell
     b = y_cell
     # calculate the piece size
     # check Y first
     for yi in range(4+1):
      c = [a,b]
      if b == y_csize:
       break
      elif c in cell_used:
       break
      elif chk_cell(a,b)[0] == 0:
       break
      b += 1

     # check for more X width
     xi = 1
     a = x_cell+1
     for xr in range(3):
       yv = True
       b = y_cell
       for yr in range(yi):
         c = [a,b]
         if a == x_csize:
           yv = False
           break
         elif c in cell_used:
           yv = False
           break
         elif chk_cell(a,b)[0] == 0:
           yv = False
           break
         b += 1
       if yv == False:
         break
       xi += 1
       a += 1
     # ------------------------
     # register cells
     a = x_cell
     b = y_cell
     cell_incvram = 0
     for xreg in range(xi):

      # awful patch
      if DOUBLE_MODE:
        if yi == 1:
         cell_used.append([a,b])
         make_cell(a,b)
         art_file.write(bytes(0x20))
         cell_incvram += 2
         b += 2

        elif yi == 3:
         cell_used.append([a,b])
         make_cell(a,b)
         cell_used.append([a,b+1])
         make_cell(a,b+1)
         cell_used.append([a,b+2])
         make_cell(a,b+2)
         art_file.write(bytes(0x20))
         cell_incvram += 4
         b += 4

        else:
          for yreg in range(yi):
           cell_used.append([a,b])
           cell_incvram += 1
           make_cell(a,b)  # MAKE cell
           b += 1

      else:
        for yreg in range(yi):
         cell_used.append([a,b])
         cell_incvram += 1
         make_cell(a,b)  # MAKE cell
         b += 1

      b = y_cell
      a += 1
     # ------------------------
     # make piece
     xi -= 1
     yi -= 1
     if DOUBLE_MODE:
        if yi == 0 or yi == 2:
          yi += 1
     size = (xi<<2|yi)

     spr_data.append([y_pos,size,cell_vram,x_pos])
     spr_numpz += 1
     if PLC_MODE == True:
      dplc_used.append([cell_vdplc,cell_incvram])
      cell_vdplc += cell_incvram
     cell_vram += cell_incvram

     cell_tell += cell_incvram
     cell_got  += cell_incvram

     # ------------------------
    y_pos += 8
    y_cell += 1
    y_read -= 1
   x_pos += 8
   x_cell += 1
   x_read -= 1

  # ------------------------
  # write MAP head
  dpos = map_file.tell()
  map_file.seek(head_pos)
  map_file.write( bytes([(dpos>>8)&0xFF,dpos&0xFF]) )
  head_pos += 2
  map_file.seek(dpos)
  # write MAP pieces
  map_file.write( bytes([(spr_numpz>>8)&0xFF,spr_numpz&0xFF]) ) # numof_pz
  for i in range(0,len(spr_data)):
   a = spr_data[i][0]
   b = spr_data[i][1]
   c = spr_data[i][2]
   d = c>>1
   e = spr_data[i][3]

   # dc.b y_pos,size
   # dc.w vram_normal
   # dc.w vram_half
   # dc.w x_pos
   map_file.write( bytes([a&0xFF]) )
   map_file.write( bytes([b&0xFF]) )
   map_file.write( bytes([(c>>8)&0xFF,c&0xFF]) )
   map_file.write( bytes([(d>>8)&0xFF,d&0xFF]) )
   map_file.write( bytes([(e>>8)&0xFF,e&0xFF]) )

  # PLC output
  if PLC_MODE == True:
   ddpos = plc_file.tell()
   plc_file.seek(dhead_pos)
   plc_file.write( bytes([(ddpos>>8)&0xFF,ddpos&0xFF]) )
   dhead_pos += 2
   plc_file.seek(ddpos)
   # write MAP pieces
   plc_file.write( bytes([(spr_numpz>>8)&0xFF,spr_numpz&0xFF]) ) # numof_pz
   for i in range(0,len(dplc_used)):
    a = dplc_used[i][0]
    b = dplc_used[i][1]-1 # MINUS ONE
    # if b >= 16:
    #   #print("RAN OUT OF PLC")
    #   b = 15
    b = (b & 0x0F) << 12 & 0xF000
    a = (a & 0x0FFF) | b
    plc_file.write( bytes([(a>>8)&0xFF,a&0xFF]) )

  if cell_got > cell_max:
    cell_max = cell_got

  # NEXT Y FRAME
  #print(dplc_used)
  GLBL_IMGPOS += FRAME_WDTH*FRAME_HGHT
  #curr_frame -= 1


#======================================================================
# ----------------------------
# End
# ----------------------------

print("USING PLC: "+str(PLC_MODE))
print("DOUBLE MODE: "+str(DOUBLE_MODE))
print("Maximum cells: "+hex(cell_max))
#print("Cells used: "+hex(cell_tell))
input_file.close()
art_file.close()
map_file.close()
if PLC_MODE == True:
 plc_file.close()
