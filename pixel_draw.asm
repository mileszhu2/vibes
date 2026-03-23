.data
displayaddress:     .word       0x10008000

# ...

.text
# ...
li $t1, 0xff0000 # $t1 = red
li $t2, 0x00ff00 # $t2 = green
li $t3, 0x0000ff # $t3 = blue
lw $t0, displayaddress # $t0 = base address for display
sw $t1, 0( $t0 ) # paint the first unit (i.e., top−left) red
sw $t2, 4( $t0 ) # paint the second unit on the first row green
sw $t3, 128( $t0 ) # paint the first unit on the second row blue

########################################################################
###  Everything above this line was provided in the project handout  ###
########################################################################

add $t4, $t1, $t2               # store the colour yellow into $t4
add $t5, $t1, $t3               # store the colour magenta into $t5
add $t6, $t2, $t3               # store the colour cyan into $t6
sw $t4, 8( $t0 )                # paint the next pixel yellow
sw $t5, 12( $t0 )               # paint the next pixel magenta
sw $t6, 16( $t0 )               # paint the next pixel cyan

add $t7, $t6, $t1               # store the colour white into $t7
addi $t0, $t0, 256              # move $t0 to the first pixel in the third row.
addi $t8, $t0, 128              # set the location for stopping the drawing of the line.
loop:
sw $t7, 0( $t0 )                # paint the first pixel in the third row white
addi $t0, $t0, 4                # increase the address in $t0 by 4 bytes.
beq $t0, $t8, end               # if $t0 has reached the end of the line, then stop.
j loop
end:
lw $t0, displayaddress # $t0 = base address for display
