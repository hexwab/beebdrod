Level file:
0000: number of rooms
 [maximum 25 rooms per level]
0001: starting room
0002: starting X coord within room, 0-37
0003: starting Y coord within room, 0-31
0004: starting direction, 0-7
0005: 25 bytes of coordinate
coordinates are 3 bits X 2:0, 3 bits Y (5:3)
  zzyyyxxx
001e: 25 bytes of pointer lo to room data
0037: 25 bytes of pointer hi to room data
pointers are absolute, assuming level is at 8000
0050: 25 bytes of orb data length
0069: room data begins

  [maximum map size is 7x7, level 8 needs fixing to conform to this]
  [can we use the two spare bits to store conquered/explored flags?]

Room data:
up to 255 bytes of orb data, length in header
 [note that orb data is read-only so can be discarded and reloaded]

Orb data:
orb: sxxxxxxxx yyyyyycc x,y are coords, c is count of targets-1
  s: is scroll not orb
  [max 4 targets per orb]
scrolls: 1 byte of length(+3), then text
for actual orbs:
zxxxxxxxx yyyyyytt for each target
 t: type. 1-3 open,close,toggle
  max space for orbs is 208 bytes

2720 (40*34*2, $aa0) bytes of tile data, compressed
 [default decompression location $2400, or elsewhere if drawing the map]
each tile is two bytes: first byte is opaque layer, second byte is transparent

[map data is padded by 1 tile in each direction, so that crumbly walls
in adjacent rooms are handled correctly. this takes 288 bytes! can we
be more efficient?]
