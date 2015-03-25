\ "The Towers of Hanoi"
\ Translated from BBC BASIC version by Richard Russell

  VARIABLE PILES
  3 CELLS ALLOT \ Non-standard array declaration

: DISC ( n -- )
  DUP 128 + COLOUR
  DUP 0 DO 32 EMIT LOOP
  DUP .
  1 ?DO 32 EMIT LOOP
  128 COLOUR
;

: TABXY ( x y -- )
  SWAP
  31 EMIT
  EMIT EMIT
;

: TABDISC ( disc pile -- )
  2DUP ( d p d p )
  1- 26 * 13 + SWAP - ( d p x )
  -ROT ( x d p )
  CELLS PILES + @ -1 * 20 + SWAP DROP ( x y )
  TABXY 
;

: PUT ( disc pile -- )
  2DUP ( d p d p )
  TABDISC ( d p )
  SWAP ( p d )
  DISC ( p )
  CELLS PILES + DUP @ 1+ SWAP !
;

: TAKE ( disc pile -- )
  2DUP DUP ( d p d p p )
  CELLS PILES + DUP @ 1- SWAP ! ( d p d p )
  TABDISC ( d p )
  DROP ( d )
  2 * 2 + SPACES 
;

: HANOI ( a b c d -- )
  3 PICK IF
    3 PICK 1- 3 PICK 2 PICK 4 PICK RECURSE
    3 PICK 3 PICK TAKE
    3 PICK 2 PICK PUT
    3 PICK 1- 1 PICK 3 PICK 5 PICK RECURSE
  THEN
  2DROP 2DROP
;

: TOWERS ( n -- )
  3 MODE
  DUP 1 SWAP DO I 1 PUT -1 +LOOP
  0 0 TABXY
  ." Press return to start" 999 INKEY DROP
  1 2 3 HANOI
  0 23 TABXY
;

13 TOWERS
