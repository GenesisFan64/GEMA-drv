#======================================================================
# Custom p2bin script
#======================================================================

import sys
import os.path

#======================================================================
# -------------------------------------------------
# Init
# -------------------------------------------------

if os.path.exists(sys.argv[1]) == False:
	print("P2BIN: File not found")
	exit()
	
input_file = open(sys.argv[1],"rb")
output_file = open(sys.argv[2],"wb")
a = ord(input_file.read(1))		# Filler reads
b = ord(input_file.read(1))

#======================================================================
# -------------------------------------------------
# Start
# -------------------------------------------------

working=True
while working:
	a = int(ord(input_file.read(1)))
	if a == 0:
		working = False
	elif a == 0x81:
		input_file.seek(3,1)
		startfrom  = int(ord(input_file.read(1)))
		startfrom |= int(ord(input_file.read(1))) << 8
		startfrom |= int(ord(input_file.read(1))) << 16
		startfrom |= int(ord(input_file.read(1))) << 24
		length = int(ord(input_file.read(1)))
		length |= int(ord(input_file.read(1))) << 8
		output_file.seek(startfrom)
		result = input_file.read(length)
		output_file.write(result)
	else:
		print("INVALID CONTROL BYTE")
		working = False
	
# ----------------------------
# End
# ----------------------------

input_file.close()
output_file.close()    
