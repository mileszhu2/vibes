.data
displayaddress:     .word       0x10008000

colors: .word 0:6

colors2: 
.word 0x00ffffca
.word 0x00ffffcb
.word 0x00ffffcc
.word 0x00ffffcd
.word 0x00ffffce
.word 0x00ffffcf

# ...

.text
reset_colors:
    la $t9, colors
    li $t1, 0 # index
    li $t2, 0x00ffffc9 # base color
    reset_colors_loop:
        beq $t1, 6, reset_colors_done
        addi $t2, $t2, 1
        sw $t2, 0($t9)
        add $t9, $t9, 4
        addi $t1, $t1, 1
        j reset_colors_loop
    reset_colors_done:
        # display colors
        lw $t0, displayaddress
        la $t9, colors
        lw $t1, 0($t9)
        sw $t1, 0($t0)
        lw $t1, 4($t9)
        sw $t1, 4($t0)
        lw $t1, 8($t9)
        sw $t1, 8($t0)
        lw $t1, 12($t9)
        sw $t1, 12($t0)
        lw $t1, 16($t9)
        sw $t1, 16($t0)
        lw $t1, 20($t9)
        sw $t1, 20($t0)