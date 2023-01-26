	ORG $8000
	GUARD $C000
.start
	INCLUDE "heads.out.s"
.end
	ORG $2000
	GUARD $3000
.pstart
	INCLUDE "heads.ptrs.s"
.pend
SAVE "heads",start,end
SAVE "headsptrs",pstart,pend
