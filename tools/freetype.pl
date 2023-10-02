#!/usr/bin/perl -w
use strict;
use Font::FreeType;

my ($filename, $sizex, $sizey) = @ARGV;

my $dpi = 75;

my $face = Font::FreeType->new->face($filename);

$face->set_char_size($sizex, $sizey, $dpi, $dpi);

#201c 201d “ ”
#2019 ’
#fb00 ﬀ
#fb01 ﬁ
#fb02 ﬂ
#fb03 ﬃ
#fb04 ﬄ
my @desired_glyphs = (32..126, 0x201c, 0x201d, 0x2019, 0xfb00..0xfb04);
#my %desired_glyphs; map {$desired_glyphs{$_}++} @desired_glyphs;

my ($maxw,$maxh,$minh)=(0,0,0);
my $out="";
my $chars=0;
for my $char (@desired_glyphs) {
    my $glyph = $face->glyph_from_char_code($char);
    warn "No glyph for character '$char'.\n", next unless $glyph;
    my ($arr, $left, $top) = $glyph->bitmap(FT_RENDER_MODE_MONO);
    my $len=0;
    for my $line (@$arr) {
	$line=~tr/\x00\xff/01/;
	$len=length $line;
	$line.='0'x(8-($len&7));
	$line=unpack'H*',pack'B*',$line;
    }
    my $height = scalar @$arr;
    $maxw=$len if $len>$maxw;
    $maxh=$height if $height>$maxh;
    $minh=$top-$height if $top-$height<$minh;
    my $ha=$glyph->horizontal_advance;
    #use Data::Dumper;
    $out.="STARTCHAR ".$glyph->name."\n";
    $out.="ENCODING $char\n";
    $out.="SWIDTH ".$ha*1000*72/$dpi." 0\n";
    $out.="DWIDTH $ha 0\n";
    #$out.="BBX $len $height $left ".($top-$height)."\n";
    $out.="BBX $len $height 0 ".($top-$height)."\n";
    $out.="BITMAP\n";
    $out.=uc"$_\n" for @$arr;
    $out.="00\n" if !@$arr;
    $out.="ENDCHAR\n";
    $chars++;
}

print "STARTFONT 2.1\n";
print "FONT foobar\n";
print "SIZE $sizex $dpi $dpi\n";
print "FONTBOUNDINGBOX $maxw ".($maxh+$minh)." 0 $minh\n";
print "STARTPROPERTIES 5\n";
print "FACE_NAME \"".$face->family_name." ".$face->style_name."\"\n";
print "FAMILY_NAME \"".$face->family_name."\"\n";
print "WEIGHT_NAME \"".$face->style_name."\"\n";
print "FONT_DESCENT ".$face->descender."\n";
print "FONT_ASCENT ".$face->ascender."\n";
print "ENDPROPERTIES\n";
print "CHARS $chars\n";
print $out;
print "ENDFONT\n";
#print $maxw." ".$maxh;
