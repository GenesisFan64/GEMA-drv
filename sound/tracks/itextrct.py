#======================================================================
# Convert ImpulseTracker module to GEMA V1.0
#
# Input:
# python itextrct.py file.it
#======================================================================

import sys
import os.path

#======================================================================
# -------------------------------------------------
# Settings
# -------------------------------------------------

MAX_TIME	= 0x7F
MAX_CHAN	= 32			# !! Maximum 32
IN_FOLDER	= "./trkr/"		# Location of the IT files

#======================================================================
# -------------------------------------------------
# Init
# -------------------------------------------------

if len(sys.argv) != 1+1:
	print("Usage: itextrct.py inputfile")
	exit()
if os.path.exists(IN_FOLDER+sys.argv[1]+".it") == False:
	print("File not found")
	exit()

MASTERNAME = sys.argv[1]
input_file = open(IN_FOLDER+MASTERNAME+".it","rb")
out_patterns = open(MASTERNAME+"_patt.bin","wb")
out_blocks   = open(MASTERNAME+"_blk.bin","wb")

#======================================================================
# -------------------------------------------------
# Init
# -------------------------------------------------

working=True

input_file.seek(0x20)							# go to 0x40
OrdNum = ord(input_file.read(1)) | (ord(input_file.read(1)) << 8)	# Get Num for these
InsNum = ord(input_file.read(1)) | (ord(input_file.read(1)) << 8)
SmpNum = ord(input_file.read(1)) | (ord(input_file.read(1)) << 8)
PatNum = ord(input_file.read(1)) | (ord(input_file.read(1)) << 8)

# TODO, mejorar esta parte...
input_file.seek(0x40)		# Go to 0x40
ChnNum = 0
for i in range(64):
	a = ord(input_file.read(1))
	if (a & 0x80) == False:
		ChnNum += 1


addr_BlockList = 0xC0					# Block order pos
addr_PattList  = 0xC0+((OrdNum)+(InsNum*4)+(SmpNum*4))	# BlkOrder + these variables

#======================================================================
# -------------------------------------------------
# build BLOCKS file
# -------------------------------------------------

# build BLOCKS list
input_file.seek(addr_BlockList)
for b in range(0,OrdNum):
	a = ord(input_file.read(1))		# Copy and Paste
	out_blocks.write(bytes([a]))

# -------------------------------------------------
# build Headers and Patterns
# -------------------------------------------------

buff_Notes = [0]*(MAX_CHAN)			# IT note storage
curr_PattInc = 0				# current Pattern pos
numof_Patt   = PatNum
out_patterns.write(bytes(numof_Patt*4))		# Make room for the pointers

while numof_Patt:
	input_file.seek(addr_PattList)		# Get pattern location in module
	addr_PattList += 4			# Increment for the next one

	# Read MODULE pattern address and jump
	addr_CurrPat = ord(input_file.read(1)) | ord(input_file.read(1)) << 8 | ord(input_file.read(1)) << 16 | ord(input_file.read(1)) << 24
	input_file.seek(addr_CurrPat)
	# Get pattern size and number of rows
	sizeof_Patt = ord(input_file.read(1)) | ord(input_file.read(1)) << 8
	sizeof_Rows = ord(input_file.read(1)) | ord(input_file.read(1)) << 8
	input_file.seek(4,True)		# Skip 4 bytes

	# Make a header for this pattern
	last_pattout = out_patterns.tell()
	out_patterns.seek(curr_PattInc)
	pattrn_start = last_pattout
	out_patterns.write(bytes([pattrn_start&0xFF,(pattrn_start>>8)&0xFF]))	# dw .patt_loc
	out_patterns.write(bytes([sizeof_Rows&0xFF,(sizeof_Rows>>8)&0xFF]))	# dw row_size
	last_pattrstart = pattrn_start

	# ---------------------------
	# read pattern head
	# ---------------------------
	out_patterns.seek(last_pattout)
	set_End = False					# Reset end-of-row flag
	timerOut = 0					# Reset RLE timer

	# ---------------------------
	while sizeof_Rows:
		a = ord(input_file.read(1))
		
		# 0x00
		if a == 0:
			if set_End == True:				# Is the end of the row?
				set_End = False
				out_patterns.write(bytes(1))
			else:							# Else, it's a timer
				if timerOut != 0:				# RLE timer is non-zero?
					out_patterns.seek(-1,True)		# then go back

				out_patterns.write(bytes([timerOut&0x7F]))	# Write/Update timer
				timerOut += 1					# Next
				if timerOut > MAX_TIME:
					timerOut = MAX_TIME
			sizeof_Rows -= 1					# DECREMENT ROW

		# 0x01-0xFF
		else:
			timerOut = 0					# Reset RLE timer
			gotChnlIndx = (a-1) & 0x3F			# Get channel index

			# NEW note, new control byte (+0x80)
			if (a & 128) != 0:
				a = 0xC0 | gotChnlIndx
				out_patterns.write(bytes([a&0xFF]))	# Save format
				a = ord(input_file.read(1))
				buff_Notes[gotChnlIndx] = a		# Get NEW control byte
				out_patterns.write(bytes([a&0xFF]))	# and store it

			# NEW note, same control
			else:
				# NEW data, reuse format
				a = 0x80 | gotChnlIndx
				out_patterns.write(bytes([a&0xFF]))

			if gotChnlIndx >= MAX_CHAN:
				print("Error: RAN OUT OF CHANNELS")
				exit()

			# Read data changes trough control byte
			a = buff_Notes[gotChnlIndx]
			if (a & 1) != 0:
				out_patterns.write(bytes([ord(input_file.read(1))&0xFF]))
			if (a & 2) != 0:
				out_patterns.write(bytes([ord(input_file.read(1))&0xFF]))
			if (a & 4) != 0:
				out_patterns.write(bytes([ord(input_file.read(1))&0xFF]))
			if (a & 8) != 0:
				out_patterns.write(bytes([ord(input_file.read(1))&0xFF]))
				out_patterns.write(bytes([ord(input_file.read(1))&0xFF]))
			set_End = True

	# Next block
	curr_PattInc += 4
	numof_Patt -= 1

# ----------------------------
# End
# ----------------------------

input_file.close()
out_patterns.close()    
