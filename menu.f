Z" user32.dll" LoadLibrary
DUP Z" CreatePopupMenu" GetProcAddress CONSTANT CreatePopupMenu
DUP Z" CreateMenu" GetProcAddress CONSTANT CreateMenu
DUP Z" AppendMenuA" GetProcAddress CONSTANT AppendMenu
DUP Z" SetMenu" GetProcAddress CONSTANT SetMenu
DUP Z" DrawMenuBar" GetProcAddress CONSTANT DrawMenuBar
FreeLibrary DROP ( user32.dll is pre-loaded by BB4W )

CreatePopupMenu SYSCALL
DUP Z" Blac&k" 0 0 3 ROLL AppendMenu SYSCALL DROP
DUP Z" &Red" 1 0 3 ROLL AppendMenu SYSCALL DROP
DUP Z" &Green" 2 0 3 ROLL AppendMenu SYSCALL DROP
DUP Z" &Yellow" 3 0 3 ROLL AppendMenu SYSCALL DROP
DUP Z" &Blue" 4 0 3 ROLL AppendMenu SYSCALL DROP
DUP Z" &Magenta" 5 0 3 ROLL AppendMenu SYSCALL DROP
DUP Z" &Cyan" 6 0 3 ROLL AppendMenu SYSCALL DROP
DUP Z" &White" 7 0 3 ROLL AppendMenu SYSCALL DROP

CreateMenu SYSCALL
DUP Z" &Colour" 3 ROLL 16 3 ROLL AppendMenu SYSCALL DROP
hwnd @ SetMenu SYSCALL DROP
hwnd @ DrawMenuBar SYSCALL DROP

: ONSYS wparam @ 128 + COLOUR CLS ;
: MENUTEST BEGIN 0 MS POLL AGAIN ;
MENUTEST


