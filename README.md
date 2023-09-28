BBC Micro port of DROD.

Specifically Caravel DROD (v1.6), which is under MPL and can be found here: http://www.caravelgames.com/Articles/Games_2/AE.html .  Source is at https://github.com/binji/drod/tree/master/Caravel .  

(The official DROD repo, for newer games with engine versions >=2.0, is at https://github.com/CaravelGames/drod and is probably more easily buildable.  But as a reference it's less good as there's around 3x the code, none of which is required for KDD.)

Status: pre-alpha.

Requirements:
* BBC B with DFS ("BBC B version")
* BBC B/B+ with DFS and 16K SWRAM ("Enhanced version")
* BBC Master ("Master version")
* Electron with DFS and 16K SWRAM ("Electron version")

Keys:
* hjklyubn (nethack-style) or numpad (on Master): move
* qw: turn sword
* m: map
* r: restart room
* cursors: move by an entire room (for debugging)

Building:

You will need:
* [beebasm](https://github.com/stardot/beebasm)
* [Exomizer](https://bitbucket.org/magli143/exomizer/wiki/Home) 3.0.1 (or 3.0.2)
* Python 3
* PIL
* [pypng](https://github.com/drj11/pypng)
* Perl
* [Metakit](https://www.equi4.com/metakit.html)
* Freetype
* [Font::FreeType](https://metacpan.org/dist/Font-FreeType)
