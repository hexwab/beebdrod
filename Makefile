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

tiles: tiles.png tools/sprites.py
	python3 tools/sprites.py tiles.png

drod.ssd: drod.s exo.s intro.s drod.bas map.s zap.s tar.s sprite.s text.s minifont.s scroll.s tiles boot.s swr.s core.s
	perl makedisc.pl -f >files.h
	beebasm -i intro.s -v >intro.txt
	perl makechain.pl dointro intro.txt >intro.exo
	exomizer level -q -c -M256 tiles@0xa000 -o tiles.exo
	beebasm -i drod.s -v >out.txt
	perl makechain.pl code out.txt >code.exo
	beebasm -i boot.s -do boot.ssd -opt 2 -v >boot.txt
	truncate -s 2560 boot.ssd
	perl makedisc.pl <boot.ssd >tmp.ssd && mv tmp.ssd drod.ssd
