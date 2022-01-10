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

title:	titlebeeb.png
	python2 tools/png2bbc.py -p 0157 titlebeeb.png 1 -o title
	exomizer level -q -c -M256 title@0x5580 -o title.exo

heads: headsbeeb.png makeheads.pl headsdata.s
	python2 tools/png2bbc.py --transparent-output 0 -p 0357 headsbeeb.png 1 -o heads.bin
	perl makeheads.pl <heads.bin >heads.out.s
	beebasm -i headsdata.s -v >heads.txt
	exomizer level -q -c -M256 heads@0x8000 -o heads.exo

heads.ssd: heads.exo headstest.s heads.s
	beebasm -i headstest.s -do heads.ssd -boot ƒheads -v >headstest.txt

drod.ssd: drod.s exo.s intro.s title.s map.s zap.s tar.s sprite.s text.s minifont.s scroll.s tiles boot.s swr.s core.s hwscroll.s heads.exo heads.s makedisc.pl
	perl makedisc.pl -f >files.h
	beebasm -i title.s -D PLATFORM_BBCB=1 -D ELECTRON=0 -v >title.txt
	perl makechain.pl titlecode title.txt >titlecode.exo
	beebasm -i title.s -D PLATFORM_ELK=1 -D ELECTRON=1 -v >titleelk.txt
	perl makechain.pl titlecode titleelk.txt >titlecode_elk.exo
	beebasm -i intro.s -D PLATFORM_BEEB=1 -v >intro.txt
	perl makechain.pl dointro intro.txt >intro.exo
	exomizer level -q -c -M256 tiles@0xa000 -o tiles.exo
	beebasm -i drod.s -D PLATFORM_BBCB=1 -v >out_bbcb.txt
	perl makechain.pl code out_bbcb.txt >code_bbcb.exo
	beebasm -i drod.s -D PLATFORM_BEEB=1 -v >out_beeb.txt
	perl makechain.pl code out_beeb.txt >code_beeb.exo
	beebasm -i drod.s -D PLATFORM_ELK=1 -v >out_elk.txt
	perl makechain.pl code out_elk.txt >code_elk.exo
	beebasm -i drod.s -D PLATFORM_MASTER=1 -v >out_master.txt
	perl makechain.pl code out_master.txt >code_master.exo
	beebasm -i boot.s -D PLATFORM_BEEB=1 -do boot.ssd -opt 2 -title "D.R.O.D." -v >boot.txt
	truncate -s 2560 boot.ssd
	perl makedisc.pl <boot.ssd >tmp.ssd && mv tmp.ssd drod.ssd
