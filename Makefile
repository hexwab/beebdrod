CFLAGS=-g3 -Wall
all: drod.ssd

tools: tools/dump tools/unpack-room

rooms: dump tools
	mkdir -p rooms
	cd rooms ; \
	for i in `seq -w 350` ; do \
	    ../tools/unpack-room <../reference/00$$i.dump > room$$i 2>/dev/null; \
	done

text:
	mkdir -p text
	cd text ; \
	../tools/dump ../reference/text.dat >../reference/text.txt ; \
	perl ../tools/text.pl <../reference/text.txt

dump:
	cd reference ; \
	../tools/dump drod1_6.dat >drod1_6.txt

levels:
	perl tools/pack-levels.pl <reference/drod1_6.txt

levels-test:
	perl tools/pack-levels.pl -d <reference/drod1_6.txt

tiles: tiles.png
	python3 tools/sprites.py tiles.png

drod.ssd: drod.s exo.s intro.s drod.bas map.s zap.s sprite.s tiles
	beebasm -i intro.s -v >intro.txt
	beebasm -i drod.s -do drod.ssd -opt 3 -v >out.txt
