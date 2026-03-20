; Returns rune(integer) of the codepoint-useful for grapheme cluster boundary
; --------------------------------------------------------------------
charntorune:
    movzx eax, byte [esi]
    call  .utfseq           ; ebx = n (size of character) can be 1,2,3,4 byte

    test  ebx, ebx
    jz    .rune_error       

    cmp   ebx, 1
    je    .type_1
    cmp   ebx, 2
    je    .type_2
    cmp   ebx, 3
    je    .type_3
    cmp   ebx, 4
    je    .type_4
    jmp   .rune_error       

.type_1:
    movzx edx, al           
    jmp   .cont_done        ; no continuation loop needed for 1 byte cahr

.type_2:
    movzx edx, al
    and   edx, 0x1F         ; strip 110xxxxx
    jmp   .cont_loop

.type_3:
    movzx edx, al
    and   edx, 0x0F         ; strip 1110xxxx
    jmp   .cont_loop
.type_4:
    movzx edx, al
    and   edx, 0x07         ; strip 11110xxx
    

.cont_loop:
    mov   edi, 1            ;consider this i

.cont_next:
    cmp   edi, ebx          ; i < n check.
    jge   .cont_done       

    movzx eax, byte [esi+edi]
    
                            ;verify continuation byte: (s[i] & 0xC0) == 0x80
    mov   ah, al
    and   ah, 0xC0
    cmp   ah, 0x80
    jne   .rune_error       ; not a continuation byte

                            ; r = (r << 6) | (s[i] & 0x3F)
    shl   edx, 6
    and   eax, 0x3F         ; strip 10xxxxxx
    or    edx, eax

    inc   edi               ; i++
    jmp   .cont_next

.cont_done:
    ret

.rune_error:
    pusha
    cinvoke printf, err_msg1
    popa
    mov   edx, 0xFFFD       
    mov   ebx, 1           
    ret


; Input:  al : leading byte
; OUTPUT: expected sequence length (1,2,3,4)- 0:if invalid
; --------------------------------------------------------------------------------------
.utfseq:
    test  al, 0x80          ; 0xxxxxxx-1byte
    jz    .seq_1

    mov   bl, al
    and   bl, 0xC0
    cmp   bl, 0x80          ; 10xxxxxx (invalid leader)
    je    .seq_0

    mov   bl, al
    and   bl, 0xE0
    cmp   bl, 0xC0          ; 110xxxxx-2byte
    je    .seq_2

    mov   bl, al
    and   bl, 0xF0
    cmp   bl, 0xE0          ; 1110xxxx-3byte
    je    .seq_3

    mov   bl, al
    and   bl, 0xF8
    cmp   bl, 0xF0          ; 11110xxx-4byte
    je    .seq_4

    jmp   .seq_0            ; 11111xxx (invalid)

.seq_0: mov ebx, 0
        ret
.seq_1: mov ebx, 1
        ret
.seq_2: mov ebx, 2
        ret
.seq_3: mov ebx, 3
        ret
.seq_4: mov ebx, 4
        ret


; Verifies whether code follows the shortest form rule
; Output: returns 1 or 0 in eax for valid/invalid
; --------------------------------------------------------------------
overlong_check:
    cmp   ebx, 1
    je    .ol_valid                 ;check1

    cmp   ebx, 2
    jne   .check3
    cmp   edx, 0x7F                 ;check2
    jg    .ol_valid
    jmp   .ol_invalid

.check3:
    cmp   ebx, 3
    jne   .check4
    cmp   edx, 0x7FF
    jg    .ol_valid
    jmp   .ol_invalid

.check4:
    cmp   edx, 0xFFFF
    jg    .ol_valid

.ol_invalid:
    pusha
    cinvoke printf, err_msg2
    popa
    mov   eax, 1
    ret
.ol_valid:
    xor   eax, eax
    ret