CFLAGS=-g3 -Wall
all: drod.ssd

tools: tools/dump tools/unpack-room

rooms: dump tools
	mkdir -p rooms
	cd rooms ; \
	for i in `seq -w 350` ; do \
	    ../tools/unpack-room <../reference/00$$i.dump > room$$i 2>/dev/null; \
	done

dump:
	cd reference ; \
	../tools/dump drod1_6.dat >drod1_6.txt

levels: exorooms
	perl tools/pack-levels.pl <reference/drod1_6.txt

exorooms: rooms
	cd rooms; \
	for i in room???; do exomizer level -c -M256 $$i@0x1600 -o $$i.exo ; done

drod.ssd: drod.s drod.bas
	beebasm -i drod.s -do drod.ssd -opt 3 -v >out.txt
