format PE console
entry start

include 'win32a.inc' ; Set your own path



; Properties
prop_other       = 0
prop_cr          = 1
prop_lf          = 2
prop_control     = 3
prop_extend      = 4
prop_zwj         = 5
prop_spacingmark = 6
prop_RI          = 7  ; Regional Indicator-Special Case

section '.data' data readable writeable
    ;Testcase here
    teststr db 0xF0, 0x9F, 0x87, 0xB5, 0xF0, 0x9F, 0x87, 0xB0, 0xF0, 0x9F, 0x87, 0xA6, 0
    msg     db 'Total graphemes: %d', 10, 0
    err_msg db 'Error: Malformed sequence.', 10, 0
    err_msg1 = err_msg
    err_msg2 = err_msg

    
    ; Mask for Other-->Extend(4), ZWJ(5), SpacingMark(6) = (1<<4)|(1<<5)|(1<<6) = 0x70 - Precomputed values!
    dont_break:
        dd 0x00000070 ; 0:Other
        dd 0x00000004 ; 1: CR          
        dd 0x00000000 ; 2: LF
        dd 0x00000000 ; 3: Control
        dd 0x00000070 ; 4: Extend
        dd 0x00000070 ; 5: ZWJ
        dd 0x00000070 ; 6: Spacingmark
        dd 0x00000070 ; 7: RI          -> RI to RI is handled by the explicit state machine below

    ; Intervals for quick lookup
    ;quick note, this is oversimplification of the actual intervals of properties- these are just made for the sake of simpilicity
    intervals:
        dd 0x000D, 0x000D, prop_cr
        dd 0x000A, 0x000A, prop_lf
        dd 0x0000, 0x001F, prop_control
        dd 0x0300, 0x036F, prop_extend
        dd 0x200D, 0x200D, prop_zwj
        dd 0x093E, 0x094C, prop_spacingmark
        dd 0x1F1E6, 0x1F1FF, prop_RI    

        dd 0xFFFFFFFF, 0, 0

section '.text' code readable executable
start:
    push teststr
    call count_graphemes
    add  esp, 4

    cinvoke printf, msg, eax

    invoke ExitProcess, 0
;--------------------
count_graphemes:
    push ebp
    mov  ebp, esp
    sub  esp, 8             ; [ebp-4] = storing previous propertry,[ebp-8] = ri_odd flag
    push ebx
    push esi
    push edi
    mov  esi, [ebp+8]      
    xor  ecx, ecx          

    mov  dword [ebp-4], prop_control
    mov  dword [ebp-8], 0            
.loop:
    movzx eax, byte [esi]
    test  al, al
    jz    .done

    call  charntorune
    cmp   edx, 0xFFFD
    je    .handle_error
    call  overlong_check
    test  eax, eax
    jnz   .handle_error

    push  edx               
    call  .get_prop         ; eax = curr_prop
    pop   edx

    
    ; Indicator State Machine
    ; --------------------------------
    cmp   eax, prop_RI
    jne   .not_ri

    ; It IS a Regional Indicator. Check  state memory.
    cmp   dword [ebp-8], 1
    je    .ri_glue          ; State is odd. Glue it to make a flag

    ; State is even (this is the 1st half of a new flag). Set state to odd.
    mov   dword [ebp-8], 1
    jmp   .do_bitmask
.ri_glue:
    mov   dword [ebp-8], 0  ; Reset state to even (flag is complete)
    jmp   .glue             

.not_ri:
    ; Chain broken by a normal character. Reset the RI state memory.
    mov   dword [ebp-8], 0  
    




    
    ; Standard Stateless Bitmask 
    ;------------------------------------------------
.do_bitmask:
    mov   edi, [ebp-4]                       
    mov   edi, dword [dont_break + edi*4]    
    bt    edi, eax                           
    jc    .glue                              

                            ;Break
    inc   ecx               

.glue:
    mov   [ebp-4], eax      ; Save current prop for comparison ahead
    add   esi, ebx          
    jmp   .loop

.handle_error:
    pusha
    cinvoke printf, err_msg
    popa
    mov   dword [ebp-4], prop_control 
    mov   dword [ebp-8], 0  
    add   esi, ebx
    jmp   .loop
.done:
    mov   eax, ecx          
    pop   edi
    pop   esi
    pop   ebx
    mov   esp, ebp          
    pop   ebp
    ret

; --------------------------------------------------------------------
.get_prop:
    mov   edi, intervals
.search_loop:
    mov   eax, [edi]        
    cmp   eax, 0xFFFFFFFF   
    je    .not_found
    cmp   edx, eax          
    jb    .next_interval    
    cmp   edx, [edi+4]      
    ja    .next_interval    
    mov   eax, [edi+8]      
    ret
.next_interval:
    add   edi, 12           
    jmp   .search_loop
.not_found:
    mov   eax, prop_other   
    ret


include "utf8_decode.inc"
section '.idata' import data readable
    library kernel32, 'kernel32.dll', \
            msvcrt, 'msvcrt.dll'
    import kernel32, ExitProcess, 'ExitProcess'
    import msvcrt, printf, 'printf'