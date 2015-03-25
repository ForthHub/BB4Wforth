\ 'Fake' fractal fern
\ Original QBASIC program published in PC Magazine
\ BB4Wforth version by Richard Russell, 14-Sep-2009

VARIABLE RND 
: RANDOM ( n -- u ) RND @ 134775813 * 1 + DUP RND ! SWAP U/MOD DROP 1 + ;
: FERN
8 MODE
2 0 GCOL
0 0 ( X Y )
80000 1 DO ( Loop 80000 times )
  100 RANDOM 
  DUP 10 <= IF DROP
    SWAP DROP 0 SWAP 16 * 100 / 
  ELSE
    DUP 86 <= IF DROP
      2DUP 2DUP ( X Y X Y X Y )
      4 * 100 / SWAP 85 * 100 / + ( X Y X Y x )
      -ROT ( X Y x X Y )
      85 * 100 / SWAP 4 * 100 / - 160 + ( X Y x y )
      2SWAP 2DROP
    ELSE
      DUP 93 <= IF DROP
        2DUP 2DUP ( X Y X Y X Y )
        -26 * 100 / SWAP 20 * 100 / + ( X Y X Y x )
        -ROT ( X Y x X Y )
        22 * 100 / SWAP 23 * 100 / + 160 + ( X Y x y )
        2SWAP 2DROP
      ELSE DROP
          2DUP 2DUP ( X Y X Y X Y )
          28 * 100 / SWAP 15 * 100 / - ( X Y X Y x )
          -ROT ( X Y x X Y )
          24 * 100 / SWAP 26 * 100 / + 44 + ( X Y x y )
          2SWAP 2DROP
      THEN
    THEN
  THEN
  2DUP SWAP 600 + SWAP 2DUP MOVETO DRAW
LOOP
2DROP
." OK"
;

FERN

