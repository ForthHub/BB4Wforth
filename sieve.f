Z" winmm.dll" LoadLibrary 
DUP Z" timeGetTime" GetProcAddress CONSTANT timeGetTime
FreeLibrary DROP \ WINMM.DLL is pre-loaded by BB4W

200000 CONSTANT Limit
CREATE Sieve Limit CELLS ALLOT
Sieve Limit CELLS 0 FILL

: SIEVE
  2 ( Prime )
  BEGIN DUP DUP * Limit < WHILE
    DUP 2 * Limit SWAP DO
      1 I CELLS Sieve + !
    DUP +LOOP
    BEGIN 1+
    DUP CELLS Sieve + @ 0= UNTIL
  REPEAT
  DROP
;

: TOTAL
  0 ( Total )
  Limit 2 DO 
    I CELLS Sieve + @ IF ELSE 1+ THEN     
  LOOP
;       

: TEST 
  timeGetTime SYSCALL 
  ." Working..." CR
  SIEVE
  TOTAL
  timeGetTime SYSCALL SWAP
  ." Total number of primes = " . CR
  ." Time taken = " SWAP - S>D <# # # # 46 HOLD #S #> TYPE 
  ."  seconds" CR
;

TEST
