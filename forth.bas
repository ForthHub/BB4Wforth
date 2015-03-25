      REM IA-32 Assembly Language Forth in BBC BASIC for Windows
      REM Based on Linux JonesForth at http://annexia.org/forth/
      REM Adapted by Richard Russell, http://www.rtrussell.co.uk
      REM Version 0.16, 07-Sep-2009 Added ERR, ROLL, OSCLI, SYSCALL
      REM Version 0.17, 08-Sep-2009 Added Load/FreeLibrary, GetProcAddress
      REM Version 0.18, 09-Sep-2009 Added DO, LOOP, +LOOP, I, J
      REM Version 0.19, 10-Sep-2009 Added ?DO, LEAVE, UNLOOP, VERSION$
      REM Version 0.20, 11-Sep-2009 Added ESCape test in loops
      REM Version 0.21, 12-Sep-2009 Added hwnd, U/MOD; fixed Divmod
      REM Version 0.22, 13-Sep-2009 Added stack underflow check; Home, End
      REM Version 0.23, 19-Sep-2009 Added INKEY, hfiles, BGET, BPUT, memhdc
      REM Version 0.24, 20-Sep-2009 Added more 'system variables', UM*
      REM Version 0.25, 21-Sep-2009 Suppress echo while EXECing
      REM Version 0.26, 22-Sep-2009 Save reg's in OSCLI; test 'kill' flag
      REM Version 0.27, 27-Sep-2009 Corrected ?DO, changed TRUE to -1
      REM Version 0.28, 28-Sep-2009 Added M*, */, */MOD, U<, U>, S>D, 2*, 2/, U2/
      REM Version 0.29, 29-Sep-2009 Added SOURCE, >IN ; correct LEAVE
      REM Version 0.30, 30-Sep-2009 Added UM/MOD, SM/REM, FM/MOD, R@, D+, D-
      REM Version 0.31, 01-Oct-2009 Backslash (\) changed to a word
      REM Version 0.32, 02-Oct-2009 Added compliant CREATE...DOES>, EVALUATE
      REM Version 0.33, 03-Oct-2009 Added FILL, ACCEPT, SETSRC, RESTORE
      REM Version 0.34, 04-Oct-2009 Revert to alternative CREATE...DOES>
      REM Version 0.35, 05-Oct-2009 Name change 'builds' -> 'dodoes'
      REM Version 0.36, 06-Oct-2009 Re-arrange memory management; fix +LOOP
      REM Version 0.37, 10-Oct-2009 Added POLL for Windows event handling
      REM Version 0.38, 19-Oct-2009 Updated ROT,-ROT to Jonesforth v47
      
      Version$ = "0.38"
      JONES_VERSION = 47
      SYS "SetWindowText", @hwnd%, "BB4Wforth version "+Version$
      
      F_IMMED = &80
      F_HIDDEN = &20
      F_LENMASK = &1F
      EXCEPTION_CONTINUE_EXECUTION = -1
      
      DIM F% 3-(END AND 3), C% 3327, L% -1, G% 2047, D% (HIMEM-END-6000) OR 3, T% -1
      Code% = C%
      Limit% = L%
      data_segment = D%
      data_segment_top = T%
      return_stack_top = T%
      input_buffer = !332 + 32768
      oscli_buffer = !336
      optval = ^@hfile%(0)-6
      exchan = ^@hfile%(0)+88
      bflags = ^@flags%+3
      ontime = ^!388
      onclose = ^!392
      onmove = ^!396
      onsys  = ^!400
      onmouse = ^!404
      errval = ^?418
      eventq = @vdu%-144
      evtqw  = @vdu%+205
      evtqr  = @vdu%+206
      
      PROCassemble
      
      OSCLI "EXEC """+@dir$+"bb4wforth.f"""
      SYS "SetUnhandledExceptionFilter", exception_filter
      ON ERROR PRINT 'REPORT$
      CALL _start
      END
      
      DEF PROCassemble
      FOR Pass% = 8 TO 10 STEP 2
        P% = Code%
        Q% = data_segment
        L% = Limit%
        M% = data_segment_top
        Link% = 0
        
        SWAP P%,Q% : SWAP L%,M% : REM switch to .data
        [OPT Pass%
        ; Forth variables (data segment):
        .var_State dd 0
        .var_Here dd LastData%
        .var_Latest dd LastLink%
        .var_Sz dd 0
        .var_Base dd 10
        .var_Pnsptr dd 0
        .interpret_is_lit dd 0
        .poll_latest dd 0
        .srcbuff dd input_buffer
        .srcchrs dd 0
        .srccurr dd 0
        .savbuff dd 0 ; used by Evaluate
        .savchrs dd 0 ; used by Evaluate
        .savcurr dd 0 ; used by Evaluate
        ._word_buffer db STRING$(32, " ")
        
        .cold_start             ; High-level code without a codeword.
        dd Quit
        ]
        SWAP P%,Q% : SWAP L%,M% : REM switch to .code
        [OPT Pass%
        .exception_filter
        mov edx,[esp+4]         ; lpEXCEPTION_POINTERS
        mov edx,[edx+4]         ; lpCONTEXT
        mov dword [edx+184],_abort ; eip
        mov eax,[var_Sz]
        mov dword [edx+196],eax ; esp
        mov eax,EXCEPTION_CONTINUE_EXECUTION
        ret 4
        
        ._abortmsg
        db 6 : db 3 : db 13 : db 10
        db "Abort error: "
        ._abortmsgend
        
        ._stackmsg
        db 6 : db 3 : db 13 : db 10
        db "Stack error: "
        ._stackmsgend
        
        ._escmsg
        db 6 : db 3 : db 13 : db 10
        db "Escape"
        db 13 : db 10
        ._escmsgend
        
        ; Assembler entry points:
        ._quit
        mov byte  [optval],0    ; zero optval
        mov dword [exchan],0    ; zero exchan
        call "osrdch"           ; quits if kill flag set!
        ._escape
        bt [bflags],0           ; test kill flag
        jc _quit
        btr [bflags],7          ; clear escape flag
        mov byte [errval],17
        mov edx,_escmsg         ; error message
        mov ecx,_escmsgend-_escmsg ; length of string
        call _tell
        jmps _start_nosz
        
        ._stackerr
        mov byte [errval],57
        mov edx,_stackmsg       ; error message
        mov ecx,_stackmsgend-_stackmsg ; length of string
        jmps _rpt_error
        
        ._abort
        mov byte [errval],58
        mov edx,_abortmsg       ; error message
        mov ecx,_abortmsgend-_abortmsg ; length of string
        ._rpt_error
        call _report_error
        ._start
        cld
        mov [var_Sz],esp        ; Save the initial data stack pointer
        ._start_nosz
        mov dword [srcbuff],input_buffer
        mov dword [srcchrs],0
        mov dword [srccurr],0
        mov ebp,return_stack_top ; Initialise the return stack.
        mov esi,cold_start      ; Initialise interpreter.
        lodsd : jmp [eax]       ; Run interpreter!
        
        ; DOCOL - the interpreter!
        .Docol
        lea ebp,[ebp-4]
        mov [ebp],esi           ; push esi on to the return stack
        lea esi,[eax+4]         ; esi points to first data word
        lodsd : jmp [eax]
        
        ;REM BUILT-IN WORDS ---------------------------------------------------
        
        OPT FNdefcode("DROP", 0, Drop)
        pop eax                 ; drop top of stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("DUP", 0, Dup)
        push dword [esp]        ; duplicate top of stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("SWAP", 0, Swap)
        pop eax                 ; swap top two elements on stack
        pop ebx
        push eax
        push ebx
        lodsd : jmp [eax]
        
        OPT FNdefcode("OVER", 0, Over)
        push dword [esp+4]      ; push second element of stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("ROT", 0, Rot) ; n.b. Jonesforth v47
        pop eax
        pop ebx
        pop ecx
        push ebx
        push eax
        push ecx
        lodsd : jmp [eax]
        
        OPT FNdefcode("-ROT", 0, Nrot) ; n.b. Jonesforth v47
        pop eax
        pop ebx
        pop ecx
        push eax
        push ecx
        push ebx
        lodsd : jmp [eax]
        
        OPT FNdefcode("2DROP", 0, Twodrop)
        pop eax                 ; drop top two elements of stack
        pop eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("2DUP", 0, Twodup)
        push dword [esp+4]      ; duplicate top two elements of stack
        push dword [esp+4]
        lodsd : jmp [eax]
        
        OPT FNdefcode("2SWAP", 0, Twoswap)
        pop eax                 ; swap top two pairs of elements of stack
        pop ebx
        pop ecx
        pop edx
        push ebx
        push eax
        push edx
        push ecx
        lodsd : jmp [eax]
        
        OPT FNdefcode("?DUP", 0, Qdup)
        mov eax,[esp]           ; duplicate top of stack if non-zero
        test eax,eax
        jz _nodup
        push eax
        ._nodup
        lodsd : jmp [eax]
        
        OPT FNdefcode("1+", 0, Incr)
        inc dword [esp]         ; increment top of stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("1-", 0, Decr)
        dec dword [esp]         ; decrement top of stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("4+", 0, Incr4)
        add dword [esp],4       ; add 4 to top of stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("4-", 0, Decr4)
        sub dword [esp],4       ; subtract 4 from top of stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("+", 0, Add)
        pop eax                 ; get top of stack
        add dword [esp],eax     ; and add it to next word on stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("D+", 0, Dadd) ; Added by RTR
        pop edx                 ; MS 32-bits
        pop eax                 ; LS 32-bits (Forth is big-endian)
        add dword [esp+4],eax
        adc dword [esp],edx
        lodsd : jmp [eax]
        
        OPT FNdefcode("-", 0, Sub)
        pop eax                 ; get top of stack
        sub dword [esp],eax     ; and subtract it from next word on stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("D-", 0, Dsub) ; Added by RTR
        pop edx                 ; MS 32-bits
        pop eax                 ; LS 32-bits (Forth is big-endian)
        sub dword [esp+4],eax
        sbb dword [esp],edx
        lodsd : jmp [eax]
        
        OPT FNdefcode("*", 0, Mul)
        pop eax
        pop ebx
        imul ebx                ; signed (or unsigned) multiply
        push eax                ; ignore MS 32 bits
        lodsd : jmp [eax]
        
        OPT FNdefcode("UM*", 0, Umul64) ; Added by RTR
        pop eax
        pop ebx
        mul ebx                 ; unsigned multiply
        push eax                ; LS 32 bits (Forth is big-endian)
        push edx                ; MS 32 bits
        lodsd : jmp [eax]
        
        OPT FNdefcode("M*", 0, Mul64) ; Added by RTR
        pop eax
        pop ebx
        imul ebx                ; signed multiply
        push eax                ; LS 32 bits (Forth is big-endian)
        push edx                ; MS 32 bits
        lodsd : jmp [eax]
        
        OPT FNdefcode("/MOD", 0, Divmod)
        pop ebx
        pop eax
        cdq                     ; RTR correction
        idiv ebx
        push edx                ; push remainder
        push eax                ; push quotient
        lodsd : jmp [eax]
        
        OPT FNdefcode("U/MOD", 0, Udivmod) ; Added by RTR (unsigned)
        pop ebx
        pop eax
        xor edx,edx
        div ebx
        push edx                ; push remainder
        push eax                ; push quotient
        lodsd : jmp [eax]
        
        OPT FNdefcode("UM/MOD", 0, UMdivmod) ; Added by RTR (unsigned)
        pop ebx
        pop edx
        pop eax
        div ebx
        push edx                ; push remainder
        push eax                ; push quotient
        lodsd : jmp [eax]
        
        OPT FNdefcode("SM/REM", 0, SMdivrem) ; Added by RTR (signed)
        pop ebx
        pop edx
        pop eax
        idiv ebx
        push edx                ; push remainder
        push eax                ; push quotient
        lodsd : jmp [eax]
        
        OPT FNdefcode("FM/MOD", 0, FMdivmod) ; Added by RTR (floored)
        pop ebx
        pop edx
        pop eax
        idiv ebx
        or edx,edx
        jz _fmmodx              ; No remainder
        or eax,eax
        jns _fmmodx             ; Quotient is positive
        dec eax
        add edx,ebx
        ._fmmodx
        push edx                ; push remainder
        push eax                ; push quotient
        lodsd : jmp [eax]
        
        OPT FNdefcode("*/", 0, Muldiv) ; Added by RTR
        pop ecx
        pop ebx
        pop eax
        imul ebx
        idiv ecx
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("*/MOD", 0, Muldivmod) ; Added by RTR
        pop ecx
        pop ebx
        pop eax
        imul ebx
        idiv ecx
        push edx                ; push remainder
        push eax                ; push quotient
        lodsd : jmp [eax]
        
        OPT FNdefcode("2*", 0, Twomul) ; Added by RTR
        shl dword [esp],1
        lodsd : jmp [eax]
        
        OPT FNdefcode("2/", 0, Twodiv) ; Added by RTR
        sar dword [esp],1
        lodsd : jmp [eax]
        
        OPT FNdefcode("U2/", 0, Utwodiv) ; Added by RTR
        shr dword [esp],1
        lodsd : jmp [eax]
        
        OPT FNdefcode("=", 0, Equ)
        pop eax                 ; top two words are equal?
        pop ebx
        cmp eax,ebx
        sete al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("<>", 0, Nequ)
        pop eax                 ; top two words are not equal?
        pop ebx
        cmp eax,ebx
        setne al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("<", 0, Lt)
        pop eax
        pop ebx
        cmp ebx,eax
        setl al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("U<", 0, Ult) ; Added by RTR
        pop eax
        pop ebx
        cmp ebx,eax
        setb al
        movzx eax,al
        neg eax
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode(">", 0, Gt)
        pop eax
        pop ebx
        cmp ebx,eax
        setg al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("U>", 0, Ugt) ; Added by RTR
        pop eax
        pop ebx
        cmp ebx,eax
        seta al
        movzx eax,al
        neg eax
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("<=", 0, Le)
        pop eax
        pop ebx
        cmp ebx,eax
        setle al
        neg eax                 ; RTR correction (TRUE = -1)
        movzx eax,al
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode(">=", 0, Ge)
        pop eax
        pop ebx
        cmp ebx,eax
        setge al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("0=", 0, Zequ)
        pop eax                 ; top of stack equals 0?
        test eax,eax
        setz al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("0<>", 0, Znequ)
        pop eax                 ; top of stack not 0?
        test eax,eax
        setnz al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("0<", 0, Zlt)
        pop eax
        test eax,eax
        setl al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("0>", 0, Zgt)
        pop eax
        test eax,eax
        setg al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("0<=", 0, Zle)
        pop eax
        test eax,eax
        setle al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("0>=", 0, Zge)
        pop eax
        test eax,eax
        setge al
        movzx eax,al
        neg eax                 ; RTR correction (TRUE = -1)
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("S>D", 0, Stod) ; Added by RTR
        pop eax
        cdq
        push eax                ; LS 32 bits (Forth is big-endian)
        push edx                ; MS 32 bits
        lodsd : jmp [eax]
        
        OPT FNdefcode("AND", 0, And)
        pop eax                 ; bitwise AND
        and [esp],eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("OR", 0, Or)
        pop eax                 ; bitwise OR
        or [esp],eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("XOR", 0, Xor)
        pop eax                 ; bitwise XOR
        xor [esp],eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("INVERT", 0, Invert)
        not dword [esp]         ; bitwise NOT
        lodsd : jmp [eax]
        
        OPT FNdefcode("EXIT", 0, Exit)
        mov esi,[ebp]
        lea ebp,[ebp+4]
        lodsd : jmp [eax]
        
        OPT FNdefcode("LIT", 0, Lit)
        lodsd
        push eax                ; push the literal number onto stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("ROLL", 0, Roll) ; Added by RTR
        pop ecx
        jecxz _roll_next
        lea edi,[esp+ecx*4]
        lea ebx,[edi-4]
        mov eax,[edi]
        std
        xchg esi,ebx
        rep movsD
        xchg esi,ebx
        cld
        mov [esp],eax
        ._roll_next
        lodsd : jmp [eax]
        
        ;REM MEMORY -----------------------------------------------------------
        
        OPT FNdefcode("!", 0, Store)
        pop ebx                 ; address to store at
        pop eax                 ; data to store there
        mov [ebx],eax           ; store it
        lodsd : jmp [eax]
        
        OPT FNdefcode("@", 0, Fetch)
        pop ebx                 ; address to fetch
        mov eax,[ebx]           ; fetch it
        push eax                ; push value onto stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("+!", 0, Addstore)
        pop ebx                 ; address
        pop eax                 ; the amount to add
        add [ebx],eax           ; add it
        lodsd : jmp [eax]
        
        OPT FNdefcode("-!", 0, Substore)
        pop ebx                 ; address
        pop eax                 ; the amount to subtract
        sub [ebx],eax           ; subtract it
        lodsd : jmp [eax]
        
        OPT FNdefcode("C!", 0, Storebyte)
        pop ebx                 ; address to store at
        pop eax                 ; data to store there
        mov [ebx],al            ; store it
        lodsd : jmp [eax]
        
        OPT FNdefcode("C@", 0, Fetchbyte)
        pop ebx                 ; address to fetch
        movzx eax,byte [ebx]    ; fetch byte
        push eax                ; push value onto stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("C@C!", 0, Ccopy)
        mov ebx,[esp+4]         ; source address
        mov al,[ebx]            ; get source character
        pop edi                 ; destination address
        stosb                   ; copy to destination
        push edi                ; increment destination address
        inc dword [esp+4]       ; increment source address
        lodsd : jmp [eax]
        
        OPT FNdefcode("CMOVE", 0, Cmove)
        mov edx,esi             ; preserve esi
        pop ecx                 ; length
        pop edi                 ; destination address
        pop esi                 ; source address
        cmp edi,esi             ; Added by RTR...
        jc _cmove_down          ; ...to ensure correct
        lea edi,[edi+ecx-1]     ; ...operation when
        lea esi,[esi+ecx-1]     ; ...source and dest
        std                     ; ...are overlapping
        ._cmove_down
        rep movsb               ; copy source to destination
        cld                     ; Added by RTR
        mov esi,edx             ; restore esi
        lodsd : jmp [eax]
        
        OPT FNdefcode("FILL", 0, Fill) ; Added by RTR
        pop eax                 ; char
        pop ecx                 ; count
        pop edi                 ; c-addr
        cmp ecx,0
        jle _fill_next
        rep stosb
        ._fill_next
        lodsd : jmp [eax]
        
        ;REM BUILT-IN VARIABLES -----------------------------------------------
        
        OPT FNdefconst("STATE", 0, State, var_State)
        OPT FNdefconst("HERE", 0, Here, var_Here)
        OPT FNdefconst("LATEST", 0, Latest, var_Latest)
        OPT FNdefconst("S0", 0, Sz, var_Sz)
        OPT FNdefconst("BASE", 0, Base, var_Base)
        OPT FNdefconst("PNSPTR", 0, Pnsptr, var_Pnsptr); Added by RTR
        
        OPT FNdefconst("ERR", 0, Err, errval)          ; Added by RTR
        OPT FNdefconst("hwnd", 0, Hwnd, ^@hwnd%)       ; Added by RTR
        OPT FNdefconst("memhdc", 0, Memhdc, ^@memhdc%) ; Added by RTR
        OPT FNdefconst("prthdc", 0, Prthdc, ^@prthdc%) ; Added by RTR
        OPT FNdefconst("hcsr", 0, Hcsr, ^@hcsr%)       ; Added by RTR
        OPT FNdefconst("hpal", 0, Hpal, ^@hpal%)       ; Added by RTR
        OPT FNdefconst("midiid", 0, Midiid, ^@midi%)   ; Added by RTR
        OPT FNdefconst("hfiles", 0, Hfiles, ^@hfile%(0)) ; Added by RTR
        OPT FNdefconst("flags", 0, Flags, ^@flags%)    ; Added by RTR
        OPT FNdefconst("vduvar", 0, Vduvar, ^@vdu%)    ; Added by RTR
        OPT FNdefconst("msg", 0, Msg, ^@msg%)          ; Added by RTR
        OPT FNdefconst("wparam", 0, Wparam, ^@wparam%) ; Added by RTR
        OPT FNdefconst("lparam", 0, Lparam, ^@lparam%) ; Added by RTR
        OPT FNdefconst("ox", 0, Ox, ^@ox%)             ; Added by RTR
        OPT FNdefconst("oy", 0, Oy, ^@oy%)             ; Added by RTR
        
        ;REM BUILT-IN READ-ONLY VALUES ----------------------------------------
        
        OPT FNdefconst("VERSION", 0, Version, JONES_VERSION)
        OPT FNdefconst("R0", 0, Rz, return_stack_top)
        OPT FNdefconst("DOCOL", 0, Docol_, Docol)
        OPT FNdefconst("F_IMMED", 0, Fimmed, F_IMMED)
        OPT FNdefconst("F_HIDDEN", 0, Fhidden, F_HIDDEN)
        OPT FNdefconst("F_LENMASK", 0, Flenmask, F_LENMASK)
        
        OPT FNdefconst("SYS_EXIT", 0, Sys_exit, 1)
        OPT FNdefconst("SYS_READ", 0, Sys_read, 3)
        OPT FNdefconst("SYS_OPEN", 0, Sys_open, 5)
        OPT FNdefconst("SYS_CLOSE", 0, Sys_close, 6)
        OPT FNdefconst("SYS_BRK", 0, Sys_brk, 45)
        
        OPT FNdefconst("O_RDONLY", 0, O_rdonly, 0)
        OPT FNdefconst("O_RDWR", 0, O_rdwr, 2)
        OPT FNdefconst("O_CREAT", 0, O_creat, %0001000000)
        OPT FNdefconst("O_TRUNC", 0, O_trunc, %1000000000)
        
        OPT FNdefcode("VERSION$", 0, VersionS) ; Added by RTR
        push !^Version$         ; String address
        push LEN(Version$)      ; String length
        lodsd : jmp [eax]
        
        OPT FNdefcode("cmd$", 0, CmdS)         ; Added by RTR
        push !^@cmd$            ; String address
        push LEN(@cmd$)         ; String length
        lodsd : jmp [eax]
        
        OPT FNdefcode("dir$", 0, DirS)         ; Added by RTR
        push !^@dir$            ; String address
        push LEN(@dir$)         ; String length
        lodsd : jmp [eax]
        
        OPT FNdefcode("lib$", 0, LibS)         ; Added by RTR
        push !^@lib$            ; String address
        push LEN(@lib$)         ; String length
        lodsd : jmp [eax]
        
        OPT FNdefcode("tmp$", 0, TmpS)         ; Added by RTR
        push !^@tmp$            ; String address
        push LEN(@tmp$)         ; String length
        lodsd : jmp [eax]
        
        OPT FNdefcode("usr$", 0, UsrS)         ; Added by RTR
        push !^@usr$            ; String address
        push LEN(@usr$)         ; String length
        lodsd : jmp [eax]
        
        ;REM RETURN STACK -----------------------------------------------------
        
        OPT FNdefcode(">R", 0, Tor)
        pop eax                 ; pop parameter stack into eax
        lea ebp,[ebp-4]
        mov [ebp],eax           ; push it on to the return stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("R>", 0, Fromr)
        mov eax,[ebp]           ; pop return stack on to eax
        lea ebp,[ebp+4]
        push eax                ; and push on to parameter stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("R@", 0, Rfetch) ; Added by RTR
        mov eax,[ebp]
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("RSP@", 0, Rspfetch)
        push ebp
        lodsd : jmp [eax]
        
        OPT FNdefcode("RSP!", 0, Rspstore)
        pop ebp
        lodsd : jmp [eax]
        
        OPT FNdefcode("RDROP", 0, Rdrop)
        lea ebp,[ebp+4]         ; pop return stack and throw away
        lodsd : jmp [eax]
        
        ;REM PARAMETER (DATA) STACK -------------------------------------------
        
        OPT FNdefcode("DSP@", 0, Dspfetch)
        mov eax,esp
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("DSP!", 0, Dspstore)
        pop esp
        lodsd : jmp [eax]
        
        ;REM INPUT AND OUTPUT -------------------------------------------------
        
        OPT FNdefcode("KEY", 0, Key)
        call _inp
        push  eax               ; push char value on stack
        lodsd : jmp [eax]
        
        ._inp
        mov eax,[srccurr]
        cmp eax,[srcchrs]       ; Anything remaining in input buffer?
        jz _inp_eol
        ja _inp_refill
        mov eax,[srcbuff]       ; Address of input buffer
        add eax,[srccurr]       ; Add offset to current input
        movzx eax,byte [eax]
        inc dword [srccurr]
        ret
        
        ._inp_refill
        mov edx,input_buffer
        cmp edx,[srcbuff]       ; Evaluating ?
        jnz _inp
        call _osline
        mov [srcchrs],eax
        mov dword,[srccurr],0
        jmps _inp
        
        ._inp_eol
        inc dword [srccurr]
        mov eax,13
        ret
        
        OPT FNdefcode("EMIT", 0, Emit)
        pop eax
        call "oswrch"
        lodsd : jmp [eax]
        
        OPT FNdefcode("WORD", 0, Word_)
        call _word
        push edi                ; push base address
        push ecx                ; push length
        lodsd : jmp [eax]
        
        ._word
        call _inp               ; get next char, returned in al
        cmp al,ASC" "           ; is <= blank?
        jbe _word               ; if so, keep looking
        mov edi,_word_buffer    ; pointer to return buffer
        ._word_loop
        stosb                   ; add character to return buffer
        call _inp               ; get next char, returned in al
        cmp al,ASC" "           ; is <= blank?
        ja _word_loop           ; if not, keep looping
        mov ecx,_word_buffer
        sub edi,ecx             ; get length
        xchg edi,ecx
        ret
        
        OPT FNdefcode("\", F_IMMED, Backslash) ; Added by RTR
        ._word_comment
        call _inp
        cmp al,13
        jnz _word_comment       ; loop until input buffer exhausted
        lodsd : jmp [eax]
        
        OPT FNdefcode("NUMBER", 0, Number)
        pop ecx                 ; length of string
        pop edi                 ; start address of string
        call _number
        push eax                ; parsed number
        push ecx                ; number of unparsed characters (0 = no error)
        lodsd : jmp [eax]
        
        ._number
        xor eax,eax
        xor ebx,ebx
        test ecx,ecx             ; trying to parse a zero-length string return 0.
        jz _number_ret
        
        mov edx,[var_Base]       ; get BASE (in edx)
        mov bl,[edi]             ; bl = first character in string
        inc edi
        push eax                 ; push 0 on stack
        cmp bl,ASC"-"            ; negative number?
        jnz _number_pos
        pop eax
        push ebx                 ; push <> 0 on stack, indicating negative
        dec ecx
        jnz _number_next
        pop ebx                  ; error, string is only '-'.
        mov ecx,1
        ret
        
        ._number_next
        imul eax,edx             ; eax *= BASE
        mov bl,[edi]             ; bl = next character in string
        inc edi
        ._number_pos
        sub bl,ASC"0"            ; bl < '0'?
        jb _number_end
        cmp bl,10                ; bl <= '9'?
        jb _number_dig
        sub bl,17                ; bl < 'A'? (17 is 'A'-'0')
        jb _number_end
        add bl,10
        ._number_dig
        cmp bl,dl                ; bl >= BASE?
        jge _number_end
        add eax,ebx
        loop _number_next
        ._number_end
        pop ebx                  ; sign flag
        test ebx,ebx
        jz _number_ret
        neg eax
        ._number_ret
        ret
        
        OPT FNdefcode("SOURCE", 0, Source) ; Added by RTR
        push dword [srcbuff]
        push dword [srcchrs]
        lodsd : jmp [eax]
        
        OPT FNdefcode(">IN", 0, Inptr) ; Added by RTR
        push srccurr
        lodsd : jmp [eax]
        
        OPT FNdefcode("SETSRC", 0, Setsrc) ; Added by RTR
        pop ecx                 ; string length
        pop edx                 ; string address
        mov eax,[srcbuff]
        mov [savbuff],eax
        mov eax,[srcchrs]
        mov [savchrs],eax
        mov eax,[srccurr]
        mov [savcurr],eax
        mov [srcbuff],edx
        mov [srcchrs],ecx
        mov dword [srccurr],0
        lodsd : jmp [eax]
        
        OPT FNdefcode("RESTORE", 0, Restore) ; Added by RTR
        mov eax,[savcurr]
        mov [srccurr],eax
        mov eax,[savchrs]
        mov [srcchrs],eax
        mov eax,[savbuff]
        mov [srcbuff],eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("ACCEPT", 0, Accept) ; Added by RTR
        pop eax                 ; max chars (ignored!!)
        pop edx                 ; buffer address
        push dword [exchan]
        mov dword [exchan],0    ; temp disable EXECing
        call _osline
        pop dword [exchan]
        push eax                ; characters entered
        lodsd : jmp [eax]
        
        OPT FNdefcode("GET", 0, Get) ; Added by RTR
        call "osrdch"
        movzx eax,al
        push  eax               ; push char value on stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("INKEY", 0, Inkey) ; Added by RTR
        pop eax
        call "oskey"
        movzx eax,al
        jc _inkey_ok
        cmc
        sbb eax,eax
        ._inkey_ok
        push  eax               ; push key value on stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("BGET", 0, Bget) ; Added by RTR
        pop ebx                 ; Channel number
        call "osbget"
        movzx eax,al
        jc _bget_ok
        cmc
        sbb eax,eax
        ._bget_ok
        push  eax               ; push value on stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("BPUT", 0, Bput) ; Added by RTR
        pop ebx                 ; Channel number
        pop eax                 ; Data
        call "osbput"
        lodsd : jmp [eax]
        
        ;REM DICTIONARY LOOK UPS ----------------------------------------------
        
        OPT FNdefcode("FIND", 0, Find)
        pop ecx                 ; ecx = length
        pop edi                 ; edi = address
        call _find
        push  eax               ; eax = address of dictionary entry (or NULL)
        lodsd : jmp [eax]
        
        ._find
        push esi                ; Save esi so we can use it in string comparison.
        mov edx,[var_Latest]    ; LATEST points to name header of the latest word
        ._find_loop
        test edx,edx            ; NULL pointer?  (end of the linked list)
        je _find_bad            ; not found
        
        movzx eax,byte [edx+4]  ; al = flags+length field
        and al,F_HIDDEN OR F_LENMASK ; al = name length
        cmp al,cl               ; Length is the same?
        jne _find_next
        
        push ecx                ; Save the length
        push edi                ; Save the address
        lea esi,[edx+5]         ; Dictionary string we are checking against.
        repe cmpsb              ; Compare the strings.
        pop edi
        pop ecx
        jne _find_next          ; Not the same.
        
        pop esi
        mov eax,edx
        ret                     ; Found
        
        ._find_next
        mov edx,[edx]           ; Move to the previous word
        jmps _find_loop
        
        ._find_bad
        pop esi
        xor eax,eax             ; Return zero to indicate not found.
        ret
        
        OPT FNdefcode(">CFA", 0, Tcfa)
        pop edi
        call _tcfa
        push edi
        lodsd : jmp [eax]
        
        ._tcfa
        lea edi,[edi+4]         ; Skip link pointer
        movzx eax,byte [edi]    ; Load flags+len into eax.
        and al,F_LENMASK        ; Just the length, not the flags.
        lea edi,[edi+eax+4]     ; Skip flags+len and name.
        and edi,NOT 3           ; The codeword is 4-byte aligned.
        ret
        
        OPT FNdefword(">DFA", 0, Tdfa)
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        dd Tcfa                 ; >CFA(get code field address)
        dd Incr4                ; 4+(add 4 to it to get to next word)
        dd Exit                 ; return from Forth word
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        
        ;REM COMPILING --------------------------------------------------------
        
        OPT FNdefcode("CREATE", 0, Create)
        
        pop ecx                 ; ecx = length
        pop ebx                 ; ebx = address of name
        
        mov edi,[var_Here]      ; edi is the address of the header
        mov eax,[var_Latest]    ; Get link pointer
        stosd                   ; and store it in the header.
        
        mov al,cl               ; Get the length.
        stosb                   ; Store the length/flags byte.
        push esi
        mov esi,ebx             ; esi = word
        rep movsb               ; Copy the word
        pop esi
        lea edi,[edi+3]         ; Align to next 4 byte boundary.
        and edi,NOT 3
        
        mov eax,[var_Here]
        mov [var_Latest],eax
        mov [var_Here],edi
        lodsd : jmp [eax]
        
        OPT FNdefcode(",", 0, Comma)
        pop eax                 ; Code pointer to store.
        call _comma
        lodsd : jmp [eax]
        
        ._comma
        mov edi,[var_Here]      ; HERE
        stosd                   ; Store it.
        mov [var_Here],edi      ; Update HERE (incremented)
        ret
        
        OPT FNdefcode("[", F_IMMED, Lbrac)
        xor eax,eax
        mov [var_State],eax     ; Set STATE to 0
        lodsd : jmp [eax]
        
        OPT FNdefcode("]", 0, Rbrac)
        mov dword [var_State],-1; Set STATE to -1.
        lodsd : jmp [eax]
        
        OPT FNdefword(":", 0, Colon)
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        dd Word_                ; Get the name of the new word
        dd Create               ; CREATE the dictionary entry / header
        dd Lit
        dd Docol
        dd Comma                ; Append DOCOL (the codeword).
        dd Latest
        dd Fetch
        dd Hidden               ; Make the word hidden (see below for definition).
        dd Rbrac                ; Go into compile mode.
        dd Exit                 ; Return from the function.
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        
        OPT FNdefword(";", F_IMMED, Semicolon)
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        dd Lit
        dd Exit
        dd Comma                ; Append EXIT (so the word will return).
        dd Latest
        dd Fetch
        dd Hidden               ; Toggle hidden flag -- unhide the word
        dd Lbrac                ; Go back to IMMEDIATE mode.
        dd Exit                 ; Return from the function.
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        
        ;REM EXTENDING THE COMPILER -------------------------------------------
        
        OPT FNdefcode("IMMEDIATE", F_IMMED, Immediate)
        mov edi,[var_Latest]    ; LATEST word.
        lea edi,[edi+4]         ; Point to name/flags byte.
        xor byte [edi],F_IMMED  ; Toggle the IMMED bit.
        lodsd : jmp [eax]
        
        OPT FNdefcode("HIDDEN", 0, Hidden)
        pop edi                 ; Dictionary entry.
        lea edi,[edi+4]         ; Point to name/flags byte.
        xor byte [edi],F_HIDDEN ; Toggle the HIDDEN bit.
        lodsd : jmp [eax]
        
        OPT FNdefword("HIDE", 0, Hide)
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        dd Word_                ; Get the word (after HIDE).
        dd Find                 ; Look up in the dictionary.
        dd Hidden               ; Set F_HIDDEN flag.
        dd Exit                 ; Return.
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        
        OPT FNdefcode("'", 0, Tick)
        lodsd                   ; Get the address of the next word and skip it.
        push eax                ; Push it on the stack.
        lodsd : jmp [eax]
        
        ;REM BRANCHING --------------------------------------------------------
        
        OPT FNdefcode("BRANCH", 0, Branch)
        ._branch
        test byte [bflags],&81
        jnz near _escape        ; ESCape key pressed or Close
        add esi,[esi]           ; add the offset to the instruction pointer
        lodsd : jmp [eax]
        
        OPT FNdefcode("0BRANCH", 0, Zbranch)
        pop eax
        test eax,eax            ; top of stack is zero?
        jz _branch              ; if so, jump back to the branch function above
        lodsd                   ; otherwise we need to skip the offset
        lodsd : jmp [eax]
        
        ;REM LITERAL STRINGS --------------------------------------------------
        
        OPT FNdefcode("LITSTRING", 0, Litstring)
        lodsd                   ; get the length of the string
        push esi                ; push the address of the start of the string
        push eax                ; push it on the stack
        lea esi,[esi+eax+3]     ; skip past the string, and align
        and esi,NOT 3
        lodsd : jmp [eax]
        
        OPT FNdefcode("TELL", 0, Tell)
        pop ecx                 ; length of string
        pop edx                 ; address of string
        call _tell
        lodsd : jmp [eax]
        
        ._tell
        jecxz _tell_ret
        ._tell_loop
        mov al,[edx]
        inc edx
        call "oswrch"
        loop _tell_loop
        ._tell_ret
        ret
        
        ;REM QUIT AND INTERPRET -----------------------------------------------
        
        OPT FNdefword("QUIT", 0, Quit)
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        dd Rz
        dd Rspstore             ; R0 RSP!, clear the return stack
        dd Interpret            ; interpret the next word
        dd Branch
        dd -8                   ; and loop (indefinitely)
        ]SWAP P%,Q% : SWAP L%,M%:[OPT Pass%
        
        OPT FNdefcode("RESET", 0, Reset) ; Added by RTR
        call _reset
        lodsd : jmp [eax]
        
        OPT FNdefcode("INTERPRET", 0, Interpret)
        cmp esp,[var_Sz]
        ja near _stackerr       ; stack underflow
        cmp dword [exchan],0
        jnz _no_prompt          ; EXECing
        mov eax,[srccurr]
        cmp eax,[srcchrs]
        jc _no_prompt           ; More to parse
        mov edx,_okmsg
        mov ecx,_okmsgend-_okmsg
        call _tell
        
        ._no_prompt
        call _word              ; Returns ecx = length, edi = pointer to word.
        
        xor eax,eax
        mov [ontime],eax        ; Cancel ONTIME
        mov [onclose],eax       ; Cancel ONCLOSE
        mov [onmove],eax        ; Cancel ONMOVE
        mov [onsys],eax         ; Cancel ONSYS
        mov [onmouse],eax       ; Cancel ONMOUSE
        mov [poll_latest],eax   ; Force POLL to re-scan
        mov [interpret_is_lit],eax ; Not a literal number (not yet anyway ...)
        call _find              ; Returns eax = pointer to header or 0 if not found.
        test eax,eax            ; Found?
        jz _not_found
        
        mov edi,eax             ; edi = dictionary entry
        mov al,[edi+4]          ; al Get name+flags.
        push eax                ; Just save it for now.
        call _tcfa              ; Convert dictionary entry (in edi) to codeword pointer.
        pop eax
        and al,F_IMMED          ; Is IMMED flag set?
        mov eax,edi
        jnz _run_it             ; If IMMED, jump straight to executing.
        jmps _continue
        
        ._not_found
        inc dword [interpret_is_lit]
        call _number            ; Returns the parsed number in eax, ecx > 0 if error
        test ecx,ecx
        jnz _parse_error
        mov ebx,eax
        mov eax,Lit             ; The word is LIT
        
        ._continue
        mov edx,[var_State]
        test edx,edx
        jz _run_it              ; Jump if executing.
        call _comma
        mov ecx,[interpret_is_lit] ; Was it a literal?
        test ecx,ecx
        jz _interpret_next
        mov eax,ebx             ; Yes, so LIT is followed by a number.
        call _comma
        ._interpret_next
        lodsd : jmp [eax]
        
        ._run_it
        mov ecx,[interpret_is_lit]
        test ecx,ecx            ; Literal?
        jnz _interpret_literal
        jmp [eax]
        
        ._interpret_literal
        push ebx
        lodsd : jmp [eax]
        
        ._parse_error
        mov edx,_errmsg         ; error message
        mov ecx,_errmsgend-_errmsg ; length of string
        call _report_error
        lodsd : jmp [eax]
        
        ._report_error
        call _tell              ; write error message
        
        mov ecx,[srccurr]       ; the error occurred just before srccurr
        mov edx,ecx
        add edx,[srcbuff]
        cmp ecx,40              ; if > 40, then print only 40 characters
        jle _error_short
        mov ecx,40
        ._error_short
        sub edx,ecx             ; edx = start of area to print, ecx = length
        call _tell
        
        mov edx,_errmsgnl       ; newline
        mov ecx,2
        call _tell
        
        ._reset
        mov edx,_exec_stop
        call "oscli"
        mov edx,_reset_input
        call "oscli"
        mov edx,_reset_output
        call "oscli"
        mov dword [srcbuff],input_buffer
        mov dword [srcchrs],0
        mov dword [srccurr],0
        mov dword [var_State],0
        ret
        
        ._errmsg
        db 6 : db 3
        db "Parse error: "
        ._errmsgend
        
        ._errmsgnl
        db 13 : db 10
        
        ._okmsg
        db " OK"
        db 13 : db 10
        ._okmsgend
        
        ._exec_stop
        db "EXEC" : db 13
        ._reset_input
        db "INPUT 0" : db 13
        ._reset_output
        db "OUTPUT 0" : db 13
        
        ;REM ODDS AND ENDS ----------------------------------------------------
        
        OPT FNdefcode("CHAR", 0, Char)
        call _word              ; Returns ecx = length, edi = pointer to word.
        movzx eax,byte [edi]    ; Get the first character of the word.
        push eax                ; Push it onto the stack.
        lodsd : jmp [eax]
        
        OPT FNdefcode("EXECUTE", 0, Execute)
        pop eax                 ; Get xt into eax
        jmp [eax]               ; and jump to it.
        
        OPT FNdefcode("OSCLI", 0, Oscli) ; Added by RTR
        pop ecx                 ; length of string
        pop edx                 ; address of string
        jecxz _oscli_next
        mov edi,oscli_buffer
        xchg edx,esi
        rep movsb
        xchg edx,esi
        mov byte [edi],13
        mov edx,oscli_buffer
        pushad
        call "oscli"
        popad
        ._oscli_next
        lodsd : jmp [eax]
        
        OPT FNdefconst("dodoes", 0, Dodoes, _dodoes) ; Added by RTR
        
        ._dodoes
        cmp dword [eax+4],0     ; Has DOES> been executed ?
        jz _nodoes
        lea ebp,[ebp-4]
        mov [ebp],esi
        mov esi,[eax+4]         ; Get pointer stored by DOES>
        ._nodoes
        lea eax,[eax+8]
        push eax                ; Push user data area address
        lodsd : jmp [eax]
        
        OPT FNdefcode("LEAVE", 0, Leave) ; Added by RTR
        lea ebp,[ebp+12]        ; pop return stack
        jmps _leave
        
        OPT FNdefcode("?DO", 0, Qdo) ; Added by RTR
        pop ecx                 ; initial index
        pop edx                 ; limit
        cmp ecx,edx
        jne _dogo
        ._leave
        mov ecx,1
        xor ebx,ebx
        ._qdo_loop
        lodsd
        cmp eax,Do              ; Nested loop ?
        setz bl
        add ecx,ebx
        cmp eax,Qdo
        setz bl
        add ecx,ebx
        cmp eax,Loop
        setz bl
        sub ecx,ebx
        cmp eax,Ploop
        setz bl
        sub ecx,ebx
        or ecx,ecx
        jnz _qdo_loop
        lodsd : jmp [eax]
        
        OPT FNdefcode("DO", 0, Do) ; Added by RTR
        pop ecx                 ; initial index
        pop edx                 ; limit
        ._dogo
        lea ebp,[ebp-12]        ; make room on return stack
        mov [ebp+8],esi
        mov [ebp+4],edx
        mov [ebp],ecx
        lodsd : jmp [eax]
        
        OPT FNdefcode("+LOOP", 0, Ploop) ; Added by RTR
        pop eax                 ; step
        jmps _loop_step
        
        OPT FNdefcode("LOOP", 0, Loop) ; Added by RTR
        mov eax,1               ; default step
        ._loop_step
        test byte [bflags],&81
        jnz near _escape        ; ESCape key pressed or Close
        mov ebx,[ebp]           ; index
        sub ebx,[ebp+4]         ; subtract limit
        btc ebx,31              ; invert MSB
        add ebx,eax             ; step
        jo _unloop              ; overflow signals loop end
        btc ebx,31              ; invert MSB again
        add ebx,[ebp+4]         ; add limit back
        mov [ebp],ebx           ; new index
        mov esi,[ebp+8]
        lodsd : jmp [eax]       ; continue looping
        
        OPT FNdefcode("UNLOOP", 0, Unloop) ; Added by RTR
        ._unloop
        lea ebp,[ebp+12]        ; pop return stack
        lodsd : jmp [eax]       ; exit loop
        
        OPT FNdefcode("I", 0, I) ; Added by RTR
        push dword [ebp]        ; index
        lodsd : jmp [eax]       ; exit loop
        
        OPT FNdefcode("J", 0, J) ; Added by RTR
        push dword [ebp+12]     ; outer index
        lodsd : jmp [eax]       ; exit loop
        
        OPT FNdefcode("SYSCALL3", 0, Syscall3)
        pop eax                 ; System call number (ignored)
        pop ebx                 ; First parameter (ignored)
        pop ecx                 ; Second parameter (ignored)
        pop edx                 ; Third parameter (ignored)
        push 0
        lodsd : jmp [eax]
        
        OPT FNdefcode("SYSCALL2", 0, Syscall2)
        pop eax                 ; System call number (ignored)
        pop ebx                 ; First parameter (ignored)
        pop ecx                 ; Second parameter (ignored)
        push 0
        lodsd : jmp [eax]
        
        OPT FNdefcode("SYSCALL1", 0, Syscall1)
        pop eax                 ; System call number (ignored)
        pop ebx                 ; First parameter (ignored)
        push ebp                ; Bottom of return stack
        lodsd : jmp [eax]
        
        OPT FNdefcode("SYSCALL", 0, Syscall) ; Added by RTR
        pop eax
        call eax
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("LoadLibrary", 0, Loadlibrary) ; Added by RTR
        call "LoadLibrary"
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("FreeLibrary", 0, Freelibrary) ; Added by RTR
        call "FreeLibrary"
        push eax
        lodsd : jmp [eax]
        
        OPT FNdefcode("GetProcAddress", 0, Getprocaddress) ; Added by RTR
        mov eax,[esp]
        xchg eax,[esp+4]
        mov [esp],eax
        call "GetProcAddress"
        push eax
        lodsd : jmp [eax]
        
        ;REM Windows event handling (added by RTR) ----------------------------
        
        OPT FNdefcode("POLL", 0, Poll)
        mov eax,[var_Latest]
        cmp eax,[poll_latest]   ; Any words added/removed since last POLL?
        jnz _poll_scan
        bt [bflags],5           ; Alert flag set?
        jnc _poll_next
        lock btr [bflags],5     ; Reset alert flag
        mov al,[evtqr]          ; Get read pointer
        cmp al,[evtqw]          ; Queue empty ?
        jz  _poll_next
        push ebx
        mov ebx,[eventq]
        mov bl,al
        mov eax,[ebx]
        mov [^@lparam%],eax
        mov eax,[ebx+256]
        mov [^@wparam%],eax
        add bl,4
        mov eax,[ebx]
        mov [^@msg%],eax
        mov eax,[ebx+256]
        add bl,4
        mov [evtqr],bl
        cmp bl,[evtqw]          ; Queue now empty ?
        pop ebx
        jz  _poll_done
        lock bts [bflags],5     ; Set alert flag
        ._poll_done
        or eax,eax              ; Action word set ?
        jz _poll_next
        mov edi,eax             ; edi = dictionary entry
        call _tcfa              ; Convert to codeword pointer
        mov eax,edi
        jmp Docol
        
        ._poll_next
        lodsd : jmp [eax]
        
        ._poll_scan
        mov [poll_latest],eax
        mov edi,_ontimes
        mov ecx,_oncloses-_ontimes
        call _find              ; ONTIME defined?
        mov [ontime],eax
        mov edi,_oncloses
        mov ecx,_onmoves-_oncloses
        call _find              ; ONCLOSE defined?
        mov [onclose],eax
        mov edi,_onmoves
        mov ecx,_onsyss-_onmoves
        call _find              ; ONMOVE defined?
        mov [onmove],eax
        mov edi,_onsyss
        mov ecx,_onmouses-_onsyss
        call _find              ; ONSYS defined?
        mov [onsys],eax
        mov edi,_onmouses
        mov ecx,_onends-_onmouses
        call _find              ; ONMOUSE defined?
        mov [onmouse],eax
        lodsd : jmp [eax]
        
        ._ontimes
        db "ONTIME"
        ._oncloses
        db "ONCLOSE"
        ._onmoves
        db "ONMOVE"
        ._onsyss
        db "ONSYS"
        ._onmouses
        db "ONMOUSE"
        ._onends
        
        ;REM Simple Line Editor (added by RTR) --------------------------------
        
        ._osline
        pushad                  ; edx = buffer pointer
        xor ebx,ebx             ; initial cursor position
        xor ebp,ebp             ; initial string length
        
        ._osline0
        test byte [bflags],&81
        jnz near _escape        ; ESCape key pressed or Close
        mov esi,vduoff
        mov ecx,10
        call _ostext            ; cursor off
        
        lea esi,[edx+ebx]
        mov byte [edx+ebp],ASC" "
        lea ecx,[ebp+1]
        sub ecx,ebx
        push ecx
        call _ostext            ; rewrite rest of line (plus a space)
        pop ecx
        mov al,8
        ._osline1
        call _oswrch            ; backup to original cursor position
        loop _osline1
        
        mov esi,vduon
        mov ecx,10
        call _ostext            ; cursor on
        
        push edx
        call "osrdch"           ; get character from console (or file)
        pop edx
        cmp al,135              ; delete ?
        jz _osline2
        cmp al,8                ; backspace ?
        jnz _osline5
        or ebx,ebx
        jz _osline0             ; already at start of line
        dec ebx
        call _oswrch            ; backspace cursor
        ._osline2
        cmp ebx,ebp
        jnc _osline0
        lea edi,[edx+ebx]
        lea esi,[edi+1]
        mov ecx,ebp
        sub ecx,ebx
        dec ecx
        jz _osline3
        rep movsb               ; delete character
        ._osline3
        dec ebp                 ; adjust line length
        jmps _osline0
        ;
        ._osline4
        mov al,8
        ._oslineb
        or ebx,ebx
        jz _osline0             ; already at start of line
        dec ebx
        call _oswrch            ; backspace cursor
        loop _oslineb
        jmp _osline0
        ;
        ._osline5
        mov ecx,1
        cmp al,136              ; cursor left ?
        jz _osline4
        cmp al,137              ; cursor right ?
        jz _osline8
        not ecx
        cmp al,130              ; Home ?
        jz _osline4
        cmp al,131              ; End ?
        jz _osline8
        cmp al,9                ; Tab ?
        jz _osline6
        cmp al,13               ; CR ?
        jz _osline9
        cmp al,ASC" "           ; 'Control' char ?
        jc near _osline0
        cmp al,144              ; Ins, Del, PgUp, PgDn etc ?
        jl near _osline0
        ._osline6
        lea edi,[edx+ebp]
        lea esi,[edi-1]
        mov ecx,ebp
        sub ecx,ebx
        jz _osline7
        std
        rep movsb               ; insert character
        cld
        ._osline7
        inc ebp                 ; adjust line length
        mov [edx+ebx],al        ; store character
        inc ebx
        call _oswrch
        jmp _osline0
        ;
        ._osline8
        mov al,9
        ._oslinea
        cmp ebx,ebp
        jnc near _osline0       ; already at end of line
        inc ebx
        call _oswrch            ; advance cursor
        loop _oslinea
        jmp _osline0
        ;
        ._osline9
        mov byte [edx+ebp],al   ; store CR
        call _oswrch
        mov al,10
        call _oswrch            ; output LF
        mov [esp+28],ebp        ; return no. of chars
        popad
        ret
        
        ._ostext
        lodsb
        call _oswrch
        loop _ostext
        ._osret
        ret
        
        ._oswrch
        cmp dword [exchan],0    ; EXECing ?
        jnz _osret
        jmp "oswrch"
        
        .vduoff
        dw &117 : dd 0 : dd 0   ; VDU 23,1,0;0;0;0;
        .vduon
        dw &117 : dd 1 : dd 0   ; VDU 23,1,1;0;0;0;
        ]
        LastLink% = Link%
        LastData% = (Q% + 3) AND -4
      NEXT Pass%
      ENDPROC
      
      DEF FNdefword(name$, flags%, RETURN label%)
      LOCAL start%
      
      SWAP P%,Q% : SWAP L%,M% : REM switch to .data
      P% = (P%+3) AND -4 : REM align 4
      start% = P%
      [OPT Pass% AND 14
      dd Link%
      db flags% + LEN(name$)
      db name$
      ]
      P% = (P%+3) AND -4 : REM align 4
      IF (Pass% AND 2)=0 IF label% ERROR 3, "Multiple label"
      label% = P%
      [OPT Pass% AND 14
      dd Docol
      ]
      SWAP P%,Q% : SWAP L%,M% : REM switch to .code
      Link% = start%
      = Pass%
      
      DEF FNdefcode(name$, flags%, RETURN label%)
      LOCAL start%
      
      SWAP P%,Q% : SWAP L%,M% : REM switch to .data
      P% = (P%+3) AND -4 : REM align 4
      start% = P%
      [OPT Pass% AND 14
      dd Link%
      db flags% + LEN(name$)
      db name$
      ]
      P% = (P%+3) AND -4 : REM align 4
      IF (Pass% AND 2)=0 IF label% ERROR 3, "Multiple label"
      label% = P%
      [OPT Pass% AND 14
      dd Q%
      ]
      SWAP P%,Q% : SWAP L%,M% : REM switch to .code
      Link% = start%
      = Pass%
      
      DEF FNdefconst(name$, flags%, RETURN label%, number%)
      [OPT FNdefcode(name$, flags%, label%) AND 14
      push number%
      lodsd : jmp [eax]
      ]
      = Pass%
