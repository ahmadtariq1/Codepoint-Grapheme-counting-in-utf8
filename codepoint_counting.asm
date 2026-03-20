format PE console
entry start

include 'win32a.inc' ;Adjust according to your own path

section '.data' data readable writeable

    
    teststr db 0xC2, 0xA2, 0xE2, 0x82, 0xAC, 0xF0, 0x90, 0x90, 0xB7, 0
    msg     db 'Total codepoints: %d', 10, 0
    err_msg1 db 'Error: Malformed UTF-8.[bad rune]', 10, 0
    err_msg2 db 'Error: Malformed UTF-8.[overlong]', 10, 0

section '.text' code readable executable

start:
    
    push teststr
    call utflen
    add  esp, 4         

    
    cinvoke printf, msg, eax    

    invoke ExitProcess, 0

; Input: teststr (string)
; Output: returns count of codepoints
; ------------------------------------------------------------------------------------
utflen:
    push ebp
    mov  ebp, esp
    push ebx
    push esi
    push edi

    mov  esi, [ebp+8]       
    xor  ecx, ecx           

.loop:
    movzx eax, byte [esi]  
    test  al, al           
    jz    .end             

    call  charntorune     

    test  ebx, ebx          
    jz    .advance_one

    call  overlong_check  
    test  eax, eax
    jnz   .advance_n        

    inc   ecx               

.advance_n:
    add   esi, ebx          
    jmp   .loop

.advance_one:
    inc   esi               
    jmp   .loop


.end:
    mov   eax, ecx          ;
    pop   edi
    pop   esi
    pop   ebx
    pop   ebp

    ret



include "utf8_decode.inc"
section '.idata' import data readable
    library kernel32, 'kernel32.dll', \
            msvcrt, 'msvcrt.dll'

    import kernel32, ExitProcess, 'ExitProcess'
    import msvcrt, printf, 'printf'