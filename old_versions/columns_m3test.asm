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
    
colors: .word 0x00ff0000 # red
        .word 0x0000ff00 # green
        .word 0x000000ff # blue
        .word 0x00ffff00 # yellow
        .word 0x00cc00ff # purple
        .word 0x00ff9900 # orange
        
# for flood fill
movements: .word 0xffffff80 # up (-128)
           .word 0x00000080 # down (128)
           .word 0xfffffffc # left (-4)
           .word 0x00000004 # right (4)
           .word 0xffffff7c # top left (-132)
           .word 0x00000084 # bot right (132)
           .word 0xffffff84 # top right (-124)
           .word 0x0000007c # bot left (124)

##############################################################################
# Mutable Data
##############################################################################
col_locs: .word 0:3 # locations (initially didn't need this but i found a bug)
column: .word 0:3 # colors
next_column: .word 0:3
current_pos: .word 0x10008004 # position logs the block on top of the column's top block
current_x: .word 0x00000000 # index of land_locations that corresponds to the current_pos of column
previous_pos: .word 0x10008004
col_hitbox: .word 0x10008184 # the bottom block of the column
land_locations: .word 0:6 
check_locations: .word 0:84 
candidates: .word 0:84
to_be_deleted: .word 0:84

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    lw $t0, ADDR_DSPL # $t0 = base address for display
    jal draw_game

    # Initialize columns:
    la $s0, next_column
    la $s1, column
    
    # Initialize land locations:
    li $a1, 0x00ff0000
    la $t9, land_locations
    li $t1, 0
    li $t2, 6
    li $a0, 0x10008580
    llloop:
    beq $t1, $t2, end_llloop
    addi $a0, $a0, 4
    sll $t3, $t1, 2
    add $t8, $t9, $t3 
    sw $a0, 0($t8)
    addi $t1, $t1, 1
    j llloop
    end_llloop:
    # Start the game
    jal get_random_column
    jal game_loop
    
game_loop:
    # New column turn setup
    jal transfer_next_to_col
    jal spawn_column # Spawn previously generated column
    jal get_random_column # Generate next column and display
    
    # Check if should end the game
    lw $t2, current_pos # find the current_pos
    ble $t2, $t0, end_game # checks if current_pos less than the top left corner $t0
    
    # Check if key has been pressed
    key_loop:
	li $v0, 32
	li $a0, 1
	syscall

    lw $s2, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($s2)                  # Load first word from keyboard
    beq $t8, 1, keyboard_input      # If first word 1, key is pressed
    b key_loop

    # Check which key has been pressed
    keyboard_input:                     # A key is pressed
        lw $a0, 4($s2)                  # Load second word from keyboard
        beq $a0, 0x71, respond_to_Q     # Check if the key q was pressed
        beq $a0, 0x77, respond_to_W     # Check if the key w was pressed
        beq $a0, 0x61, respond_to_A     # Check if the key a was pressed
        beq $a0, 0x73, respond_to_S     # Check if the key s was pressed
        beq $a0, 0x64, respond_to_D     # Check if the key d was pressed
        li $v0, 1                       # ask system to print $a0
        syscall
        b key_loop
    
    respond_to_Q:
    	li $v0, 10                      # Quit gracefully
    	syscall
    	
    respond_to_W:
    	li $t1, 0
        li $t2, 3
        lw $t4, 8($s1)
        swap_loop:
        beq $t1, $t2, swap_end
        sll $t6, $t1, 2
        add $t5, $s1, $t6
        lw $a0, 0($t5)
        sw $t4, 0($t5)
        move $t4, $a0
        addi $t1, $t1, 1
        j swap_loop
        swap_end:
        jal spawn_column
        jal sleep
        j key_loop
    respond_to_A:
    	lw $t1, current_pos # param for collision_checker
    	lw $t2, col_hitbox # param for collision_checker
    	li $a0, -4 # offset to move left (param for collision_checker)
    	jal collision_checker # check collision and update location if applicable
    	jal sleep
    	j key_loop
    respond_to_S: 
        # This is done assuming the game over check at the start of game_loop actually works
        # This implies that in this postion, the down move is valid and won't lose you the game
        # well it actually only checks the leftmost land_location but I'm counting on A and D moves to take care of the other locations
    	la $t1, current_pos 
    	la $t3, land_locations
    	lw $t4, current_x
    	sll $t4, $t4, 2 # multiply by 4
    	add $t5, $t3, $t4 # the location in land_locations to search
    	lw $t6, 0($t5) # the lowest possible current_pos in the current_x
        sw $t6, 0($t1) # update current_pos for spawn_column
        lw $t2, current_pos
        addi $t2, $t2, -384 # find the new lowest current_pos
        sw $t2, 0($t5) # update land_locations with new lowest current_pos
        jal spawn_column
        jal sleep
        lw $t1, col_hitbox
        la $t3, check_locations # load some queue of locations to check
        sw $t1, 0($t3)
        jal connection_finder # checks for connections and updates screen if applicable
        jal end_turn # resets for new turn
        jal sleep
        j game_loop # Go back to Step 1
    respond_to_D:
    	lw $t1, current_pos # param for collision_checker
    	lw $t2, col_hitbox # param for collision_checker
    	li $a0, 4 # offset to move right (param for collision_checker)
    	jal collision_checker # check collision and update location if applicable
    	jal sleep
    	j key_loop

    j game_loop
    end_game:
    li $v0, 10 # terminate the program gracefully
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

draw_game:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    li $t9, 0x808080 #t9=gray
    
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
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

get_random_column:
    # Generate color combo
    la $t9, colors
    addi $t6, $t0, 160
    li $t1, 0
    li $t2, 3
    li $v0, 42
    li $a1, 6
    generate_loop:
    beq $t1, $t2, generate_end
    li $a0, 0
    syscall # number in $a0
    move $t3, $a0
    sll $t3, $t3, 2 # multiply by 4 (offset)
    add $t4, $t9, $t3 # store the index in $t4 (index)
    lw $t3, 0($t4) # load the index value of colors and store in $t3
    sll $t5, $t1, 2 # multiply by 4 (offset)
    add $t4, $s0, $t5 # store the index in $t4 (index)
    sw $t3, 0($t4) # store the color in $t3 to the index in column
    sw $t3, 0($t6) # display on bitmap
    addi $t6, $t6, 128 
    addi $t1, $t1, 1
    j generate_loop
    generate_end:
    jr $ra                          # return statement
    
spawn_column:
    la $s7, col_locs
    li $a0, 0x00000000 # black
    li $a1, 0x10008084 # min position that doesn't break the game
    li $t1, 0
    li $t2, 3
    lw $t3, current_pos
    move $a3, $t3 # copy to $a3 for spawn_end
    lw $t7, previous_pos
    spawn_loop:
    beq $t1, $t2, spawn_end
    sll $t6, $t1, 2
    add $t5, $s1, $t6 # color index in colors
    lw $t4, 0($t5) # get the color
    addi $t3, $t3, 128 # color in position
    addi $t7, $t7, 128 # color out position
    add $t6, $s7, $t6 # index in col_locs
    sw $t3, 0($t6) # store color in position in col_locs
    # search previous color in positions
    li $t6, 0
    search_col_locs:
        beq $t6, $t1, color_out # no more previous color in positions and no match
        sll $t5, $t6, 2
        add $t8, $s7, $t5 # index in col_locs
        lw $t8, 0($t8) # color in position in col_locs
        beq $t7, $t8, skip_to_color_in # don't color out if the square was colored in
        addi $t6, $t6, 1
        j search_col_locs
    color_out:
    sw $a0, 0($t7) # color out
    skip_to_color_in:
    blt $t3, $a1, continue_spawn
    sw $t4, 0($t3) # color in
    addi $t1, $t1, 1 # increment
    j spawn_loop
    continue_spawn:
    addi $t1, $t1, 1 # increment
    j spawn_loop
    spawn_end:
    la $t1, col_hitbox
    sw $t3, 0($t1) # update hitbox location
    la $t7, previous_pos
    sw $a3, 0($t7) # update previous_pos to current_pos
    jr $ra
    
transfer_next_to_col:
    la $t1, next_column
    la $t2, column
    
    # Copy all 3 elements without loop
    lw $t3, 0($t1)
    sw $t3, 0($t2)
    
    lw $t3, 4($t1)
    sw $t3, 4($t2)
    
    lw $t3, 8($t1)
    sw $t3, 8($t2)
    jr $ra
    
collision_checker: 
# Parameters:
# $t1 is the current_pos of the column
# $t2 is the col_hitbox (used to check collision)
# $a0 to determine whether the intended move is left or right
    li $a1, 0 # black
    add $t3, $t2, $a0 # location to the right or left of the hitbox
    lw $t5, 0($t3) # color right or left of hitbox
    beq $t5, $a1, no_collision
    li $a1, 1 # to indicate collision
    jr $ra
    no_collision:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $t2, current_pos
    add $t1, $t1, $a0
    sw $t1, 0($t2) # update current_pos for spawn_column
    sra $t9, $a0, 2 # divide 4???
    jal spawn_column
    la $t2, current_x
    lw $t1, current_x
    add $t1, $t1, $t9
    sw $t1, 0($t2)
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
sleep:
    li $v0, 32
    li $a0, 15
    syscall
    jr $ra
    
end_turn:
    # Reset the pos for new turn
    la $t1, previous_pos
    la $t2, current_pos
    li $a0, 0
    li $a1, 0x10008004 # default location
	la $t3, land_locations
	la $t4, current_x
	sw $a0, 0($t4) # reset current_x to zero
	lw $t6, 0($t3) # the lowest possible current_pos in the current_x
	blt $t6, $a1, it_over
	sw $a1, 0($t2) # reset current_pos to top-left of playing map
	sw $a1, 0($t1) # reset previous_pos to top-left of playing map
	jr $ra
    it_over:
    sw $t6, 0($t2) # update current_pos 
    jr $ra
    
connection_finder:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    # params $t3 as a queue of locations to check
    # subsequent functions in the recursion loop shouldn't change $t3 or the following assignments
    li $t1, 0 # index for check_locations
    la $a1, to_be_deleted
    check_location_loop:
        add $t2, $t3, $t1 # where to search in $t3 location queue
        lw $t5, 0($t2) # get location
        beq $t5, 0, update_game # signals end of queue
        blt $t5, $t0, check_exit # invalid (clearly the game has a bug)
        column_up_loop:
            # check current column (loop bottom up till see black or grey)
            lw $t4, 0($t5) # target color
            beq $t4, 0x808080, up_exit # if $t4 is grey
            beq $t4, 0, up_exit # if $t4 is black
            jal check_around
            addi $t5, $t5, -128 # move up
            j column_up_loop
        up_exit:
        add $t1, $t1, 4 # increment
        j check_location_loop
    update_game:
        jal sleep
        move $v1, $t3
        jal reset_array
        la $t8, candidates
        la $t1, to_be_deleted
        li $t2, 0 # index 
        li $t9, 0 # black
        paint_black:
            beq $t2, 336, paint_black_done # 84*4 = 336
            add $t4, $t1, $t2
            lw $t5, 0($t4) # get the location
            beq $t5, 0, paint_black_done # no more to search
            blt $t5, 0x10008084, skip_paint # invalid location
            sw $t9, 0($t5) # paint black
            jal sleep
            skip_paint:
            add $t2, $t2, 4 # increment
            j paint_black
        paint_black_done:
            li $t2, 0 # reset the index for drop_loop
        drop_loop:
            beq $t2, 336, do_we_continue # 84*4 = 336
            add $t4, $t1, $t2
            lw $t5, 0($t4) # get the location
            beq $t5, 0, do_we_continue # no more to search
            
            sub $t6, $t5, $t0 # $t6 = $t5 - $t0
            addi $t6, $t6, -4 # substract 4
            sra $t4, $t6, 7 # divide by 128 and throw out remainder
            sll $t4, $t4, 7 # multiply $t4 by 128
            sub $t6, $t6, $t4 # $t6 - $t4 is the remainder and also the index
            add $v1, $t8, $t6 # candidates location
            lw $t6, 0($v1)
            blt $t5, $t6, pos_adjust
            move $t6, $t5
            j pos_adjust_end
            pos_adjust:
            add $t6, $t5, 128 # adjust the position
            pos_adjust_end:
            move $t7, $t6
            drop_loop_up:
                # check current column (loop bottom up till see black or grey)
                addi $t6, $t7, -128 # move up previous $t7
                lw $t4, 0($t6) # target color
                beq $t4, 0x808080, drop_exit # if $t4 is grey
                sw $t9, 0($t6) # color above black
                # beq $t4, 0, drop_exit # if $t4 is black
                sw $t4, 0($t7) # color current black pixel the above color (which is not black)
                jal sleep
                move $t7, $t6 # $t6 is the previous now
                j drop_loop_up
            drop_exit:
            la $v0, land_locations
            sub $t6, $t5, $t0 # $t6 = $t5 - $t0
            addi $t6, $t6, -4 # substract 4
            sra $t4, $t6, 7 # divide by 128 and throw out remainder
            sll $t4, $t4, 7 # multiply $t4 by 128
            sub $t6, $t6, $t4 # $t6 - $t4 is the remainder and also the index
            add $v0, $v0, $t6 # land_locations index
            lw $t4, 0($v0) # load the current land_location
            addi $t4, $t4, 128
            sw $t4, 0($v0)
            add $v1, $t8, $t6 # candidates location
            lw $t7, 0($v1)
            ble $t5, $t7, skip_replace
            sw $t5, 0($v1)
            skip_replace:
            add $t2, $t2, 4 # increment
            j drop_loop
        do_we_continue:
            li $t1, 0 # index
            li $t4, 0 # counter
            search_loop:
            beq $t1, 24, stop_search
            add $v1, $t8, $t1
            lw $t2, 0($v1) # load the first value
            blt $t2, $t0, skip_search
            add $v1, $t3, $t4
            sw $t2, 0($v1)
            add $t4, $t4, 4
            skip_search:
            add $t1, $t1, 4 # increment
            j search_loop
            stop_search:
            la $v1, candidates
            jal reset_array
            la $v1, to_be_deleted
            jal reset_array
            beq $t4, 0, check_exit
            jal connection_finder
    check_exit:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

check_around:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    # params $t4 as the target color and $t5 as the root location
    # subsequent functions in the recursion loop shouldn't change $t4, $t5, or the following assignments
    la $t2, movements
    li $v0, 0 # connection length
    la $v1, candidates
    
    # check vertical connection (up, down)
    lw $a0, 0($t2) # up
    add $t6, $t5, $zero
    jal flood_fill # recursive
    lw $a0, 4($t2) # down
    add $t6, $t5, $zero
    jal flood_fill # recursive
    la $v1, candidates # reset candidates pointer
    blt $v0, 3, skip1
    jal transfer_candidates
    skip1:
    jal reset_array
    jal sleep
    
    # if none, check horizontal connection (left, right)
    li $v0, 0 # reset connection length
    lw $a0, 8($t2) # left
    add $t6, $t5, $zero
    jal flood_fill # recursive
    lw $a0, 12($t2) # right
    add $t6, $t5, $zero
    jal flood_fill # recursive
    la $v1, candidates # reset candidates pointer
    blt $v0, 3, skip2 
    jal transfer_candidates
    skip2:
    jal reset_array
    jal sleep
    
    # if none, check diagonal 1 (topleft, botright)
    li $v0, 0 # reset connection length
    lw $a0, 16($t2) # topleft
    add $t6, $t5, $zero
    jal flood_fill # recursive
    lw $a0, 20($t2) # botright
    add $t6, $t5, $zero
    jal flood_fill # recursive
    la $v1, candidates # reset candidates pointer
    blt $v0, 3, skip3 
    jal transfer_candidates
    skip3:
    jal reset_array
    jal sleep
    
    # if none, check diagonal 2 (topright, botleft)
    li $v0, 0 # reset connection length
    lw $a0, 24($t2) # topright
    add $t6, $t5, $zero
    jal flood_fill # recursive
    lw $a0, 28($t2) # botleft
    add $t6, $t5, $zero
    jal flood_fill # recursive
    la $v1, candidates # reset candidates pointer
    blt $v0, 3, skip4 
    jal transfer_candidates
    skip4:
    jal reset_array
    jal sleep
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
flood_fill: 
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    # params $v0 (connection length), $v1 (candidates), $t6 (search location), $t4 (target color), $a0 (direction)
    # returns $v0 (connection length)
    lw $t7, 0($t6) # get the color
    bne $t7, $t4, end_flood # if no more of same color in direction $a0
    # else
    jal duplicate_check
    add $t6, $t6, $a0 # move one step in $a0 direction
    jal flood_fill # keep searching
    end_flood:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

duplicate_check:
    # params $t6 as the location value to check in candidates 
    # and $v1 as the current candidates pointer
    # and $v0 as the connection length
    la $s7, candidates
    li $t8, 0 # index
    duplicate_check_loop:
        beq $t8, 336, done_duplicate_check # 84*4 = 336
        add $s6, $s7, $t8
        lw $t7, 0($s6) # load candidate
        beq $t7, 0, no_duplicate # no more candidates
        beq $t7, $t6, done_duplicate_check # found a duplicate
        add $t8, $t8, 4 # increment
        j duplicate_check_loop
    no_duplicate:
        sw $t6, 0($v1) # add to candidates
        add $v1, $v1, 4 # increment candidates pointer
        addi $v0, $v0, 1 # increase connection length by 1
    done_duplicate_check:
    jr $ra

transfer_candidates:
    # $a1 is to_be_deleted array
    la $v1, candidates
    li $t6, 0 # index
    transfer_loop:
        beq $t6, 336, done_transfer # 84*4 = 336
        add $v0, $v1, $t6
        lw $t7, 0($v0) # load candidate
        beq $t7, 0, done_transfer # no more candidates
        li $t8, 0 # duplicate check index
        la $s7, to_be_deleted
        duplicate_check_loop2:
            beq $t8, 336, done_duplicate_check2 # 84*4 = 336
            add $s6, $s7, $t8
            lw $v0, 0($s6) # load value in to_be_deleted
            beq $v0, 0, no_duplicate2 # no more values
            beq $v0, $t7, done_duplicate_check2 # found a duplicate
            add $t8, $t8, 4 # increment
            j duplicate_check_loop2
        no_duplicate2:
            sw $t7, 0($a1) # store in to_be_deleted
            add $a1, $a1, 4 # increment pointer for to_be_deleted
        done_duplicate_check2:
            add $t6, $t6, 4 # increment
            j transfer_loop
    done_transfer:
    jr $ra

reset_array:
    # params $v1 (array)
    li $t6, 0 # index
    li $t7, 0 # reset value
    reset_array_loop:
        beq $t6, 336, done_reset_array # 84*4 = 336
        add $v0, $v1, $t6
        sw $t7, 0($v0) # store 0
        add $t6, $t6, 4 # increment
        j reset_array_loop
    done_reset_array:
    jr $ra
