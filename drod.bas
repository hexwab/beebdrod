MODE1:VDU19,2,5;0;31,0,17:*L.title
INPUT"Level (1-24)",L%
IFL%=0:L%=1
?&3C0=L%-1
REMOSCLI"SRL. level"+RIGHT$("0"+STR$L%,2)+" 8000 4"
*SRL. tiles A000 4
*FX11,25
*FX12,4
*/intro
