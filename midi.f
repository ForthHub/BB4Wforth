\ MIDI Functions - NOT Quite AMPLE but may be workable...

\ TODO:  GM-Style Instrument numbering
1 CONSTANT 'Grand_Piano' 

\ TODO:  GM-Style Drum Mapping....
\ These would be pitch values used by Channel 10.

\ Obtain addresses for relevant functions in WinMM

Z" WINMM.DLL" LoadLibrary ( Load WinMM library )
DUP Z" midiOutOpen" GetProcAddress CONSTANT midiOutOpen
DUP Z" midiOutShortMsg" GetProcAddress CONSTANT midiOutShortMsg
DUP Z" midiOutClose" GetProcAddress CONSTANT midiOutClose
FreeLibrary DROP ( Pre-loaded by BB4W, so remains in memory )

Z" Kernel32.DLL" LoadLibrary ( Load Kernel32 library )
DUP Z" Sleep" GetProcAddress CONSTANT Sleep
FreeLibrary DROP ( Always pre-loaded, so remains in memory )

VARIABLE MidiHandle 

: OpenMidi ( -- )
  0 0 0 -1 MidiHandle midiOutOpen SYSCALL
  IF
    ." Failed to open MIDI output device" CR
    ABORT
  THEN
;

: CloseMidi ( -- )
  MidiHandle @ midiOutClose SYSCALL
  DROP
;

: SendOutShortMsg ( msg -- )
  MidiHandle @ midiOutShortMsg SYSCALL
  DROP
;

: Delay ( ms -- )
  Sleep SYSCALL DROP
;

HEX
: StartNote ( note -- )
  100 * 7F0090 +
  SendOutShortMsg
;
DECIMAL

: StopNote ( note -- )
  256 * 128 +
  SendOutShortMsg
;

: PlayNote ( note time -- )
  SWAP TUCK 
  StartNote
  Delay
  StopNote
; 

HEX
: Instrument ( voice -- )
  100 * 7F00C0 +
  SendOutShortMsg
;
DECIMAL

: CE3K
  OpenMidi
  'Grand_Piano' Instrument
  70 500 PlayNote
  72 500 PlayNote
  68 500 PlayNote
  56 500 PlayNote
  63 1000 PlayNote
  1000 Delay
  CloseMidi
;

CE3K 
