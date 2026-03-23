################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    li $t9, 0x808080 #t9=gray
    lw $t0, ADDR_DSPL # $t0 = base address for display
    
    # Initialize the input values for the line drawing code.
    addi $a0, $zero, 0          # set the X coordinate to 0
    addi $a1, $zero, 0          # set the Y coordinate to 0
    addi $a2, $zero, 16         # set the length of the line to 16
    jal vline_draw              # calls the line drawing function
    
    addi $a0, $zero, 7          # set the X coordinate to 7
    addi $a1, $zero, 0          # set the Y coordinate to 0
    addi $a2, $zero, 16         # set the length of the line to 16
    jal vline_draw              # calls the line drawing function
    
    addi $a0, $zero, 9          # set the X coordinate to 9
    addi $a1, $zero, 0          # set the Y coordinate to 0
    addi $a2, $zero, 5          # set the length of the line to 5
    jal vline_draw              # calls the line drawing function
    
    addi $a0, $zero, 7          # set the X coordinate to 7
    addi $a1, $zero, 4          # set the Y coordinate to 4
    addi $a2, $zero, 3          # set the length of the line to 3
    jal hline_draw              # calls the line drawing function
    
    addi $a0, $zero, 0          # set the X coordinate to 0
    addi $a1, $zero, 0          # set the Y coordinate to 0
    addi $a2, $zero, 10         # set the length of the line to 10
    jal hline_draw              # calls the line drawing function
    
    addi $a0, $zero, 0          # set the X coordinate to 0
    addi $a1, $zero, 15         # set the Y coordinate to 15
    addi $a2, $zero, 8          # set the length of the line to 8
    jal hline_draw              # calls the line drawing function
    
    # Start the game
    jal game_loop
    li $v0, 10                      # terminate the program gracefully
    syscall
    
    ###
    ###  Code for drawing a horizontal/vertical line.
    ###
    ###  $t0 = location of the top-left corner of the bitmap
    ###  $a0 = the X coordinate of the start of the line
    ###  $a1 = the Y coordinate of the start of the line
    ###  $a2 = the length of the line
    ###  $t1 = the horizontal offset to add to $t0
    ###  $t2 = the vertical offset to add to $t0
    ###  $t3 = the current location in memory of the pixel to draw
    ###  $t4 = the location of the last pixel in the line
    
    hline_draw:
    sll $t2, $a1, 7                 # Calculate the vertical offset (multiply Y input by 128)
    sll $t1, $a0, 2                 # Calculate the horizontal offset (multiply X input by 4)
    add $t3, $t0, $t2               # Add the vertical offset to $t0
    add $t3, $t3, $t1               # Add the horizontal offset to the location calculated above
    
    sll $a2, $a2, 2                 # Calculate the offset from $t3 for the last pixel in the line (multiply $a2 by 4)
    add $t4, $t3, $a2               # Calculate the position of the last pixel in the line
    # start of the line-drawing loop
    hline_loop:
    beq $t3, $t4, hline_loop_end    # If the current X and Y match the end location of the line, branch out of the loop.
    sw $t9, 0($t3)                  # Draw a single gray pixel at the current X and Y
    addi $t3, $t3, 4                # Move to the next pixel in the row
    j hline_loop                    # Jump to the start of the loop
    hline_loop_end:
    jr $ra                          # return statement
    
    vline_draw:
    sll $t2, $a1, 7                 # Calculate the vertical offset (multiply Y input by 128)
    sll $t1, $a0, 2                 # Calculate the horizontal offset (multiply X input by 4)
    add $t3, $t0, $t2               # Add the vertical offset to $t0
    add $t3, $t3, $t1               # Add the horizontal offset to the location calculated above
    
    sll $a2, $a2, 7                 # Calculate the offset from $t3 for the last pixel in the line (multiply $a2 by 128)
    add $t4, $t3, $a2               # Calculate the position of the last pixel in the line
    # start of the line-drawing loop
    vline_loop:
    beq $t3, $t4, hline_loop_end    # If the current X and Y match the end location of the line, branch out of the loop.
    sw $t9, 0($t3)                  # Draw a single gray pixel at the current X and Y
    addi $t3, $t3, 128              # Move to the next pixel in the column
    j vline_loop                    # Jump to the start of the loop
    vline_loop_end:
    jr $ra                          # return statement

game_loop:
    # First column (for milestone 1 so will remove later)
    li $t1, 0xff0000 # $t1 = red
    li $t2, 0x00ff00 # $t2 = green
    li $t3, 0x0000ff # $t3 = blue
    sw $t1, 160($t0)
    sw $t2, 288($t0)
    sw $t3, 416($t0)

    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
    j game_loop
