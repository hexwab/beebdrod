#! /usr/bin/python3

import os, sys
from PIL import Image

with Image.open(sys.argv[1]) as image:
    if len(sys.argv) < 3:
        outFilename = (sys.argv[1].split('.')[0])
    else:
        outFilename = sys.argv[2]
    #print(outFilename)
    outFile = open(outFilename, "wb")

    src = { 0x00: (6,0), # ??
            0x01: (1,0), #blank
            0x02: (0,0), #pit
            0x03: (3,0), #stairs
            0x04: (0,2), #wall
            0x05: (1,2), #crumbly           
            0x06: (17,3),#blue door
            0x07: (16,3),#green door
            0x08: (18,3),#red door
            0x09: (3,4), #yellow closed
            0x0a: (4,4), #yellow open
            0x0b: (1,1), #trapdoor
            0x0c: (0,3), #wall 2
            0x0d: (10,0),#force
            0x0e: (12,0),#force
            0x0f: (10,2),#force
            0x10: (16,0),#force
            0x11: (12,2),#force
            0x12: (18,0),#force
            0x13: (14,2),#force
            0x14: (14,0),#force
            0x15: (2,1), #unused
            0x16: (2,1), #
            0x17: (6,4), #scroll
            0x18: (2,2), #orb
            0x24: (14,5), #checkpoint

            0x42: (0,7), # Beethro NE
            0x43: (2,6), # Beethro E
            0x44: (8,4), # Beethro SE
            0x45: (9,6), # Beethro S
            0x46: (7,6), # Beethro SW
            0x47: (5,7), # Beethro W
            0x40: (11,7),# Beethro NW
            0x41: (10,5),# Beethro N

            0x4a: (1,6), # sword NE
            0x4b: (3,6), # sword E
            0x4c: (9,5), # sword SE
            0x4d: (9,7), # sword S
            0x4e: (6,7), # sword SW
            0x4f: (4,7), # sword W
            0x48: (10,6),# sword NW
            0x49: (10,4),# sword N

            0x50: (3,11),# title NW
            0x51: (4,11),# title N
            0x52: (5,11),# title NE
            0x53: (3,12),# title W
            0x54: (5,12),# title E
            0x55: (3,13),# title SW
            0x56: (4,13),# title S
            0x57: (5,13),# title SE
            0x58: (11,11),# scroll NW
            0x59: (12,11),# scroll N
            0x5a: (13,11),# scroll NE
            0x5b: (11,12),# scroll W
            0x5c: (13,12),# scroll E
            0x5d: (11,13),# scroll SW
            0x5e: (12,13),# scroll S
            0x5f: (13,13),# scroll SE
                        
            0x66: (1,4), #roach (FIXME)

    }

    used = 0
    for n in range(0,16):
        for nn in range(0,256,16):
            try:
                srcx = 8*src[n+nn][0]
                srcy = 8*src[n+nn][1]
                used += 1
            except:
                if True:
                    srcx = 8*2 # ? for unknown tiles
                    srcy = 8*1
                else:
                    srcx = 8*5 # black for unknown tiles
                    srcy = 8*0
                
            #print (srcx,srcy)
            for y in range(0, 8, 8):
                for x in range(0, 8, 4):
                    for dy in range(8):
                        byte = 0
                        for dx in range(4):
                            colour = image.getpixel((x+dx+srcx, y+dy+srcy))
                            if colour==4: colour = 2 # FIXME: masking
                            assert (colour < 4)
                            value = (0,1,0x10,0x11)[colour]
                            byte = (byte<<1) | value
                        outFile.write(bytes([byte]))

    print ("used ",used)
