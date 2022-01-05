	ORG $8000
	;GUARD $C000
.start
	INCLUDE "heads.out.s"
.end

SAVE "heads",start,$c000 ;end
