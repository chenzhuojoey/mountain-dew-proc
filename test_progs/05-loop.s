/* Test simple branch logic on always taken (CPI optimized)
  for(int r0=0xFF; r0>0; r0--);
*/
lda $r0, 0xFF
loop:
	subq $r0, 0x01, $r0
	bgt $r0, loop
call_pal 0x555
