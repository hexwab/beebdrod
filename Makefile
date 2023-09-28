CFLAGS=-g3 -Wall
export EXO=exomizer301
export BEEBASM=beebasm
all: drod.ssd

tools: tools/dump tools/unpack-room

rooms: dump
	mkdir -p rooms
	cd rooms ; \
	../tools/dump ../reference/drod1_6.dat >../reference/drod1_6.txt ; \
	for i in `seq -w 350` ; do \
	    ../tools/unpack-room < 00$$i.dump > room$$i 2>/dev/null; \
	done

text:
	mkdir -p text
	cd text ; \
	../tools/dump ../reference/text.dat >../reference/text.txt ; \
	perl ../tools/text.pl <../reference/text.txt

levels: tools/pack-levels.pl rooms
	perl tools/pack-levels.pl <reference/drod1_6.txt
	touch levels

levels-test:
	perl tools/pack-levels.pl -d <reference/drod1_6.txt

tiles: tiles.png tools/sprites.py
	python3 tools/sprites.py tiles.png

title.exo: titlebeeb.png
	python3 tools/png2bbc.py -p 0157 titlebeeb.png 1 -o title
	$(EXO) level -q -c -M256 title@0x5580 -o title.exo

files.h: makedisc.pl
	perl makedisc.pl -f >files.h

font_headline: headline.bdf tools/font.pl
	perl tools/font.pl font_headline -EFLNSTacdefghijlnoprstuvwxy headline.bdf

font_headline.exo: font_headline
	$(EXO) level -q -c -M256 font_headline@0x2000 -o font_headline.exo

font_body: font.bdf tools/font.pl
	perl tools/font.pl font_body ' !'\''()+,-.0123456789:;<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' font.bdf

font_body.exo: font_body
	$(EXO) level -q -c -M256 font_body@0x2000 -o font_body.exo

yrm.beeb: yrm.B.2.png
	python3 tools/png2bbc.py yrm.B.2.png 4 -o yrm.beeb

story.exo: story.s font_body.exo font_body yrm.beeb story1.txt story2.txt story3.txt story4.txt tools/format.pl files.h
	perl tools/format.pl 16 23 10 0 1 10 64 0 font_body <story1.txt >lines1
	perl tools/format.pl 16 23 11 0 1 10 0 0 font_body <story2.txt >lines2
	perl tools/format.pl 16 23 10 0 1 10 0 0 font_body <story3.txt >lines3
	perl tools/format.pl 16 23 11 0 1 10 0 0 font_body <story4.txt >lines4
	$(BEEBASM) -i story.s -D PLATFORM_BBCB=1 -D ELECTRON=0 -v >storycode.txt
	perl makechain.pl story storycode.txt >story.exo

heads.exo: headsbeeb.png makeheads.pl headsdata.s
	python3 tools/png2bbc.py --transparent-output 0 -p 0357 headsbeeb.png 1 -o heads.bin
	# include just one frame in main RAM
	perl makeheads.pl 2 -p <heads.bin >heads.ptrs.s
	perl makeheads.pl 0134567 <heads.bin >heads.out.s
	$(BEEBASM) -i headsdata.s -v >heads.txt
	$(EXO) level -q -c -M256 heads@0x8000 -o heads.exo
	$(EXO) level -q -c -M256 headsptrs@0x2000 -o headsptrs.exo

intro: text levels tools/pack-intros.pl font_body font_headline
	perl tools/pack-intros.pl
	touch intro

transp_to_floor.s: transp_to_floor.pl
	perl transp_to_floor.pl >transp_to_floor.s

heads.ssd: heads.exo headstest.s heads.s
	$(BEEBASM) -i headstest.s -do heads.ssd -boot ƒheads -v >headstest.txt

drod.ssd: drod.s exo.s intro.s title.s map.s zap.s tar.s sprite.s text.s minifont.s scroll.s tiles boot.s swr.s core.s hwscroll.s title.exo heads.exo heads.s makedisc.pl level.s fs.s wallpit.s transp_to_floor.s intro font_body.exo font_headline.exo story.exo files.h
	$(BEEBASM) -i title.s -D PLATFORM_BBCB=1 -D ELECTRON=0 -v >title.txt
	perl makechain.pl titlecode title.txt >titlecode.exo
	$(BEEBASM) -i title.s -D PLATFORM_ELK=1 -D ELECTRON=1 -v >titleelk.txt
	perl makechain.pl titlecode titleelk.txt >titlecode_elk.exo
	$(BEEBASM) -i intro.s -D PLATFORM_BEEB=1 -v >intro.txt
	perl makechain.pl dointro intro.txt >intro.exo
	$(EXO) level -q -c -M256 tiles@0xa000 -o tiles.exo
	$(BEEBASM) -i drod.s -D PLATFORM_BBCB=1 -v >out_bbcb.txt
	perl makechain.pl code out_bbcb.txt >code_bbcb.exo
	perl makechain.pl map_overlay out_bbcb.txt map >map_overlay.exo
	$(BEEBASM) -i drod.s -D PLATFORM_BEEB=1 -v >out_beeb.txt
	perl makechain.pl code out_beeb.txt >code_beeb.exo
	$(BEEBASM) -i drod.s -D PLATFORM_ELK=1 -v >out_elk.txt
	perl makechain.pl code out_elk.txt >code_elk.exo
	$(BEEBASM) -i drod.s -D PLATFORM_MASTER=1 -v >out_master.txt
	perl makechain.pl code out_master.txt >code_master.exo
	$(BEEBASM) -i boot.s -D PLATFORM_BEEB=1 -do boot.ssd -opt 2 -title "D.R.O.D." -v >boot.txt
	perl makedisc.pl <boot.ssd 2>manifest.txt >tmp.ssd && mv tmp.ssd drod.ssd && cat manifest.txt

clean:
	-rm -rf *.exo intro heads headsptrs heads.out.s heads.ptrs.s heads.bin transp_to_floor.s title tiles code dointro map_overlay drod.ssd heads.ssd boot.ssd boot.txt heads.txt intro.txt titlecode files.h out*.txt title*.txt

reallyclean:
	-rm -rf level[012][0-9] dump/ rooms/ text/ levels dump
