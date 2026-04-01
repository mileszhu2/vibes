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
        
colors2:    .word 0x00ffffca
            .word 0x00ffffcb
            .word 0x00ffffcc
            .word 0x00ffffcd
            .word 0x00ffffce
            .word 0x00ffffcf
        
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
last_update: .word 0
last_gravity_increase: .word 0
gravity_speed: .word 0 # gravity speed
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

used_colors:    .word 0x00ff0000 # red
                .word 0x0000ff00 # green
                .word 0x000000ff # blue
                .word 0x00ffff00 # yellow
                .word 0x006600ff # purple
                .word 0x00ff9900 # orange

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    lw $t0, ADDR_DSPL # $t0 = base address for display
    jal begin
    lw $t0, ADDR_DSPL
    jal clear_screen
    lw $t0, ADDR_DSPL
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
    # Record system time
    li $v0, 30
    syscall
    sw $a0, last_gravity_increase
    # Start the game
    jal get_random_column
    j game_loop
    
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
    
    # Timer check
    li $v0, 30
    syscall
    lw $t1, last_gravity_increase
    sub $t2, $a0, $t1
    blt $t2, 10000, continue_gravity
    lw $t2, gravity_speed
    ble $t2, 0, continue_gravity # floor is 0 
    sub $t2, $t2, 50
    sw $t2, gravity_speed
    sw $a0, last_gravity_increase
    continue_gravity:
    lw $t1, last_update
    sub $t2, $a0, $t1
    
    # Check if 1 second has passed
    lw $t3, gravity_speed
    bge $t2, $t3, update_display
    
    # Small delay to prevent busy-waiting
    li $v0, 32
    li $a0, 10                  # 10ms delay
    syscall
    
    b key_loop
    
    update_display:
    # Update bitmap display
    lw $t1, current_pos
	lw $t2, current_x
	la $t3, land_locations
	
	sll $t2, $t2, 2
	add $t3, $t3, $t2
	lw $t3, 0($t3)
	
	blt $t1, $t3, gravity
	j respond_to_S
	
	gravity:
        lw $t1, current_pos # param for collision_checker
    	lw $t2, col_hitbox # param for collision_checker
    	li $a0, 128 # offset to move right (param for collision_checker)
    	jal collision_checker # check collision and update location if applicable
    	
    li $t1, 0 # index
    # find the land location again
    lw $t2, current_x
	la $t3, land_locations
	sll $t2, $t2, 2
	add $t3, $t3, $t2
	lw $t3, 0($t3)
    landing_loop:
        add $t3, $t3, 128
        lw $t2, 0($t3)
        beq $t2, 0x00ffffff, remove_white
        beq $t2, 0, add_white
        j after_color_land
        add_white:
        li $a0, 0x00ffffff
        sw $a0, 0($t3)
        j after_color_land
        remove_white:
        li $a0, 0
        sw $a0, 0($t3)
        after_color_land:
        addi $t1, $t1, 1
        blt $t1, 3, landing_loop
    
    # Reset timer
    li $v0, 30
    syscall
    sw $a0, last_update
    
    b key_loop

    # Check which key has been pressed
    keyboard_input:                     # A key is pressed
        lw $a0, 4($s2)                  # Load second word from keyboard
        beq $a0, 0x71, respond_to_Q     # Check if the key q was pressed
        beq $a0, 0x77, respond_to_W     # Check if the key w was pressed
        beq $a0, 0x61, respond_to_A     # Check if the key a was pressed
        beq $a0, 0x73, respond_to_S     # Check if the key s was pressed
        beq $a0, 0x64, respond_to_D     # Check if the key d was pressed
        beq $a0, 0x70, pause_loop       # Pause menu (if p was pressed)
        li $v0, 1                       # ask system to print $a0
        syscall
        b key_loop
    
    respond_to_Q:
    	j end_game
    	
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
        jal clear_land_indicator
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
        jal clear_land_indicator
    	lw $t1, current_pos # param for collision_checker
    	lw $t2, col_hitbox # param for collision_checker
    	li $a0, 4 # offset to move right (param for collision_checker)
    	jal collision_checker # check collision and update location if applicable
    	jal sleep
    	j key_loop
    	
    pause_loop:
        # Check if a key is available
        li $t0, 0xFFFF0000      # receiver control
        lw $t1, 0($t0)
    
        andi $t1, $t1, 1
        beq $t1, $zero, continue_pause   # 🔁 keep waiting
    
        # Read the key
        li $t0, 0xFFFF0004
        lw $t2, 0($t0)
    
        # Check for valid keys
        li $t3, 'p'
        beq $t2, $t3, unpause 
    
        li $t3, 'q'
        beq $t2, $t3, quit_from_pause
         
        continue_pause:
        jal draw_pause_menu
        
        # Sleep for half a second
        li $v0, 32
        li $a0, 500
        syscall
        
        jal flash_pause
        
        # Sleep for half a second
        li $v0, 32
        li $a0, 500
        syscall
        
        j pause_loop

    j game_loop

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
    la $t9, used_colors
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
    
# clear the landing indicator
clear_land_indicator:
	li $t1, 0 # index
    # find the land location again
    lw $t2, current_x
	la $t3, land_locations
	sll $t2, $t2, 2
	add $t3, $t3, $t2
	lw $t3, 0($t3)
    clear_landing_loop:
    add $t3, $t3, 128
    li $a0, 0
    sw $a0, 0($t3)
    addi $t1, $t1, 1
    blt $t1, 3, clear_landing_loop
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
    beq $a0, 128, alternate_ending
    sra $t9, $a0, 2 # divide 4???
    jal spawn_column
    la $t2, current_x
    lw $t1, current_x
    add $t1, $t1, $t9
    sw $t1, 0($t2)
    j skip_current_x_update
    alternate_ending:
    jal spawn_column
    skip_current_x_update:
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

# Main title screen
begin:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    begin_loop:
        # clear the screen in case we're running from end screen
        lw $t0, ADDR_DSPL
        jal clear_screen
    
        # Check if a key is available
        li $t0, 0xFFFF0000      # receiver control
        lw $t1, 0($t0)
    
        andi $t1, $t1, 1
        beq $t1, $zero, continue   # 🔁 keep waiting
    
        # Read the key
        li $t0, 0xFFFF0004
        lw $t2, 0($t0)
    
        # Check for valid keys
        li $t3, 'e'
        beq $t2, $t3, draw_easy
    
        li $t3, 'm'
        beq $t2, $t3, draw_medium
    
        li $t3, 'h'
        beq $t2, $t3, draw_hard
        
        li $t3, 't'
        beq $t2, $t3, draw_tony
    
        continue:
            lw $t0, ADDR_DSPL
            jal draw_title
            
            # sleep for half a second
            li $v0, 32
            li $a0, 500
            syscall
            
            jal flash_title
            
            li $v0, 32
            li $a0, 500
            syscall
            
            jal clear_screen
            j begin_loop
    
draw_title:
    li $t1, 0xffffff      # make $t1 white
    
    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 272($t0)
    sw $t1, 280($t0)
    sw $t1, 284($t0)
    sw $t1, 288($t0)
    sw $t1, 296($t0)
    sw $t1, 300($t0)
    sw $t1, 304($t0)
    sw $t1, 312($t0)
    sw $t1, 316($t0)
    sw $t1, 320($t0)
    sw $t1, 328($t0)
    sw $t1, 332($t0)
    sw $t1, 336($t0)
    sw $t1, 392($t0)
    sw $t1, 412($t0)
    sw $t1, 424($t0)
    sw $t1, 432($t0)
    sw $t1, 440($t0)
    sw $t1, 448($t0)
    sw $t1, 460($t0)
    sw $t1, 472($t0)
    sw $t1, 520($t0)
    sw $t1, 524($t0)
    sw $t1, 528($t0)
    sw $t1, 540($t0)
    sw $t1, 552($t0)
    sw $t1, 556($t0)
    sw $t1, 560($t0)
    sw $t1, 568($t0)
    sw $t1, 572($t0)
    sw $t1, 588($t0)
    sw $t1, 656($t0)
    sw $t1, 668($t0)
    sw $t1, 680($t0)
    sw $t1, 688($t0)
    sw $t1, 696($t0)
    sw $t1, 704($t0)
    sw $t1, 716($t0)
    sw $t1, 728($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    sw $t1, 784($t0)
    sw $t1, 796($t0)
    sw $t1, 808($t0)
    sw $t1, 816($t0)
    sw $t1, 824($t0)
    sw $t1, 832($t0)
    sw $t1, 844($t0)
    sw $t1, 1160($t0)
    sw $t1, 1164($t0)
    sw $t1, 1168($t0)
    sw $t1, 1176($t0)
    sw $t1, 1180($t0)
    sw $t1, 1184($t0)
    sw $t1, 1192($t0)
    sw $t1, 1196($t0)
    sw $t1, 1200($t0)
    sw $t1, 1208($t0)
    sw $t1, 1216($t0)
    sw $t1, 1288($t0)
    sw $t1, 1304($t0)
    sw $t1, 1312($t0)
    sw $t1, 1320($t0)
    sw $t1, 1336($t0)
    sw $t1, 1344($t0)
    sw $t1, 1416($t0)
    sw $t1, 1420($t0)
    sw $t1, 1424($t0)
    sw $t1, 1432($t0)
    sw $t1, 1436($t0)
    sw $t1, 1440($t0)
    sw $t1, 1448($t0)
    sw $t1, 1452($t0)
    sw $t1, 1456($t0)
    sw $t1, 1468($t0)
    sw $t1, 1544($t0)
    sw $t1, 1560($t0)
    sw $t1, 1568($t0)
    sw $t1, 1584($t0)
    sw $t1, 1596($t0)
    sw $t1, 1672($t0)
    sw $t1, 1676($t0)
    sw $t1, 1680($t0)
    sw $t1, 1688($t0)
    sw $t1, 1696($t0)
    sw $t1, 1704($t0)
    sw $t1, 1708($t0)
    sw $t1, 1712($t0)
    sw $t1, 1724($t0)
    sw $t1, 1928($t0)
    sw $t1, 1944($t0)
    sw $t1, 1952($t0)
    sw $t1, 1956($t0)
    sw $t1, 1960($t0)
    sw $t1, 1968($t0)
    sw $t1, 1972($t0)
    sw $t1, 1984($t0)
    sw $t1, 1992($t0)
    sw $t1, 2000($t0)
    sw $t1, 2008($t0)
    sw $t1, 2024($t0)
    sw $t1, 2056($t0)
    sw $t1, 2060($t0)
    sw $t1, 2068($t0)
    sw $t1, 2072($t0)
    sw $t1, 2080($t0)
    sw $t1, 2096($t0)
    sw $t1, 2104($t0)
    sw $t1, 2112($t0)
    sw $t1, 2120($t0)
    sw $t1, 2128($t0)
    sw $t1, 2136($t0)
    sw $t1, 2140($t0)
    sw $t1, 2148($t0)
    sw $t1, 2152($t0)
    sw $t1, 2184($t0)
    sw $t1, 2192($t0)
    sw $t1, 2200($t0)
    sw $t1, 2208($t0)
    sw $t1, 2212($t0)
    sw $t1, 2216($t0)
    sw $t1, 2224($t0)
    sw $t1, 2232($t0)
    sw $t1, 2240($t0)
    sw $t1, 2248($t0)
    sw $t1, 2256($t0)
    sw $t1, 2264($t0)
    sw $t1, 2272($t0)
    sw $t1, 2280($t0)
    sw $t1, 2312($t0)
    sw $t1, 2320($t0)
    sw $t1, 2328($t0)
    sw $t1, 2336($t0)
    sw $t1, 2352($t0)
    sw $t1, 2360($t0)
    sw $t1, 2368($t0)
    sw $t1, 2376($t0)
    sw $t1, 2384($t0)
    sw $t1, 2392($t0)
    sw $t1, 2400($t0)
    sw $t1, 2408($t0)
    sw $t1, 2440($t0)
    sw $t1, 2448($t0)
    sw $t1, 2456($t0)
    sw $t1, 2464($t0)
    sw $t1, 2468($t0)
    sw $t1, 2472($t0)
    sw $t1, 2480($t0)
    sw $t1, 2484($t0)
    sw $t1, 2496($t0)
    sw $t1, 2504($t0)
    sw $t1, 2508($t0)
    sw $t1, 2512($t0)
    sw $t1, 2520($t0)
    sw $t1, 2528($t0)
    sw $t1, 2536($t0)
    sw $t1, 2696($t0)
    sw $t1, 2704($t0)
    sw $t1, 2712($t0)
    sw $t1, 2716($t0)
    sw $t1, 2720($t0)
    sw $t1, 2728($t0)
    sw $t1, 2732($t0)
    sw $t1, 2736($t0)
    sw $t1, 2744($t0)
    sw $t1, 2748($t0)
    sw $t1, 2824($t0)
    sw $t1, 2832($t0)
    sw $t1, 2840($t0)
    sw $t1, 2848($t0)
    sw $t1, 2856($t0)
    sw $t1, 2864($t0)
    sw $t1, 2872($t0)
    sw $t1, 2880($t0)
    sw $t1, 2952($t0)
    sw $t1, 2956($t0)
    sw $t1, 2960($t0)
    sw $t1, 2968($t0)
    sw $t1, 2972($t0)
    sw $t1, 2976($t0)
    sw $t1, 2984($t0)
    sw $t1, 2988($t0)
    sw $t1, 3000($t0)
    sw $t1, 3008($t0)
    sw $t1, 3080($t0)
    sw $t1, 3088($t0)
    sw $t1, 3096($t0)
    sw $t1, 3104($t0)
    sw $t1, 3112($t0)
    sw $t1, 3120($t0)
    sw $t1, 3128($t0)
    sw $t1, 3136($t0)
    sw $t1, 3208($t0)
    sw $t1, 3216($t0)
    sw $t1, 3224($t0)
    sw $t1, 3232($t0)
    sw $t1, 3240($t0)
    sw $t1, 3248($t0)
    sw $t1, 3256($t0)
    sw $t1, 3260($t0)
    
    jr $ra
    
flash_title:
    li $t1, 0x000000     # make $t1 black

    sw $t1, 1160($t0)
    sw $t1, 1164($t0)
    sw $t1, 1168($t0)
    sw $t1, 1288($t0)
    sw $t1, 1416($t0)
    sw $t1, 1420($t0)
    sw $t1, 1424($t0)
    sw $t1, 1544($t0)
    sw $t1, 1672($t0)
    sw $t1, 1676($t0)
    sw $t1, 1680($t0)
    sw $t1, 1928($t0)
    sw $t1, 1944($t0)
    sw $t1, 2056($t0)
    sw $t1, 2060($t0)
    sw $t1, 2068($t0)
    sw $t1, 2072($t0)
    sw $t1, 2184($t0)
    sw $t1, 2192($t0)
    sw $t1, 2200($t0)
    sw $t1, 2312($t0)
    sw $t1, 2320($t0)
    sw $t1, 2328($t0)
    sw $t1, 2440($t0)
    sw $t1, 2448($t0)
    sw $t1, 2456($t0)
    sw $t1, 2696($t0)
    sw $t1, 2704($t0)
    sw $t1, 2824($t0)
    sw $t1, 2832($t0)
    sw $t1, 2952($t0)
    sw $t1, 2956($t0)
    sw $t1, 2960($t0)
    sw $t1, 3080($t0)
    sw $t1, 3088($t0)
    sw $t1, 3208($t0)
    sw $t1, 3216($t0)
    
    jr $ra
    
draw_easy:
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff      # make $t1 white
    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 272($t0)
    sw $t1, 280($t0)
    sw $t1, 284($t0)
    sw $t1, 288($t0)
    sw $t1, 296($t0)
    sw $t1, 300($t0)
    sw $t1, 304($t0)
    sw $t1, 312($t0)
    sw $t1, 316($t0)
    sw $t1, 320($t0)
    sw $t1, 328($t0)
    sw $t1, 332($t0)
    sw $t1, 336($t0)
    sw $t1, 392($t0)
    sw $t1, 412($t0)
    sw $t1, 424($t0)
    sw $t1, 432($t0)
    sw $t1, 440($t0)
    sw $t1, 448($t0)
    sw $t1, 460($t0)
    sw $t1, 472($t0)
    sw $t1, 520($t0)
    sw $t1, 524($t0)
    sw $t1, 528($t0)
    sw $t1, 540($t0)
    sw $t1, 552($t0)
    sw $t1, 556($t0)
    sw $t1, 560($t0)
    sw $t1, 568($t0)
    sw $t1, 572($t0)
    sw $t1, 588($t0)
    sw $t1, 656($t0)
    sw $t1, 668($t0)
    sw $t1, 680($t0)
    sw $t1, 688($t0)
    sw $t1, 696($t0)
    sw $t1, 704($t0)
    sw $t1, 716($t0)
    sw $t1, 728($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    sw $t1, 784($t0)
    sw $t1, 796($t0)
    sw $t1, 808($t0)
    sw $t1, 816($t0)
    sw $t1, 824($t0)
    sw $t1, 832($t0)
    sw $t1, 844($t0)
    sw $t1, 1160($t0)
    sw $t1, 1164($t0)
    sw $t1, 1168($t0)
    sw $t1, 1176($t0)
    sw $t1, 1180($t0)
    sw $t1, 1184($t0)
    sw $t1, 1192($t0)
    sw $t1, 1196($t0)
    sw $t1, 1200($t0)
    sw $t1, 1208($t0)
    sw $t1, 1216($t0)
    sw $t1, 1288($t0)
    sw $t1, 1304($t0)
    sw $t1, 1312($t0)
    sw $t1, 1320($t0)
    sw $t1, 1336($t0)
    sw $t1, 1344($t0)
    sw $t1, 1416($t0)
    sw $t1, 1420($t0)
    sw $t1, 1424($t0)
    sw $t1, 1432($t0)
    sw $t1, 1436($t0)
    sw $t1, 1440($t0)
    sw $t1, 1448($t0)
    sw $t1, 1452($t0)
    sw $t1, 1456($t0)
    sw $t1, 1468($t0)
    sw $t1, 1544($t0)
    sw $t1, 1560($t0)
    sw $t1, 1568($t0)
    sw $t1, 1584($t0)
    sw $t1, 1596($t0)
    sw $t1, 1672($t0)
    sw $t1, 1676($t0)
    sw $t1, 1680($t0)
    sw $t1, 1688($t0)
    sw $t1, 1696($t0)
    sw $t1, 1704($t0)
    sw $t1, 1708($t0)
    sw $t1, 1712($t0)
    sw $t1, 1724($t0)
    
    # $t1 no longer used to we can change it
    la $t0, gravity_speed
    li $t1, 1000
    sw $t1, 0($t0)
    
    # sleep for half a second
    li $v0, 32
    li $a0, 2000
    syscall

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_medium:
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff      # make $t1 white
    
    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 272($t0)
    sw $t1, 280($t0)
    sw $t1, 284($t0)
    sw $t1, 288($t0)
    sw $t1, 296($t0)
    sw $t1, 300($t0)
    sw $t1, 304($t0)
    sw $t1, 312($t0)
    sw $t1, 316($t0)
    sw $t1, 320($t0)
    sw $t1, 328($t0)
    sw $t1, 332($t0)
    sw $t1, 336($t0)
    sw $t1, 392($t0)
    sw $t1, 412($t0)
    sw $t1, 424($t0)
    sw $t1, 432($t0)
    sw $t1, 440($t0)
    sw $t1, 448($t0)
    sw $t1, 460($t0)
    sw $t1, 472($t0)
    sw $t1, 520($t0)
    sw $t1, 524($t0)
    sw $t1, 528($t0)
    sw $t1, 540($t0)
    sw $t1, 552($t0)
    sw $t1, 556($t0)
    sw $t1, 560($t0)
    sw $t1, 568($t0)
    sw $t1, 572($t0)
    sw $t1, 588($t0)
    sw $t1, 656($t0)
    sw $t1, 668($t0)
    sw $t1, 680($t0)
    sw $t1, 688($t0)
    sw $t1, 696($t0)
    sw $t1, 704($t0)
    sw $t1, 716($t0)
    sw $t1, 728($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    sw $t1, 784($t0)
    sw $t1, 796($t0)
    sw $t1, 808($t0)
    sw $t1, 816($t0)
    sw $t1, 824($t0)
    sw $t1, 832($t0)
    sw $t1, 844($t0)
    sw $t1, 1928($t0)
    sw $t1, 1944($t0)
    sw $t1, 1952($t0)
    sw $t1, 1956($t0)
    sw $t1, 1960($t0)
    sw $t1, 1968($t0)
    sw $t1, 1972($t0)
    sw $t1, 1984($t0)
    sw $t1, 1992($t0)
    sw $t1, 2000($t0)
    sw $t1, 2008($t0)
    sw $t1, 2024($t0)
    sw $t1, 2056($t0)
    sw $t1, 2060($t0)
    sw $t1, 2068($t0)
    sw $t1, 2072($t0)
    sw $t1, 2080($t0)
    sw $t1, 2096($t0)
    sw $t1, 2104($t0)
    sw $t1, 2112($t0)
    sw $t1, 2120($t0)
    sw $t1, 2128($t0)
    sw $t1, 2136($t0)
    sw $t1, 2140($t0)
    sw $t1, 2148($t0)
    sw $t1, 2152($t0)
    sw $t1, 2184($t0)
    sw $t1, 2192($t0)
    sw $t1, 2200($t0)
    sw $t1, 2208($t0)
    sw $t1, 2212($t0)
    sw $t1, 2216($t0)
    sw $t1, 2224($t0)
    sw $t1, 2232($t0)
    sw $t1, 2240($t0)
    sw $t1, 2248($t0)
    sw $t1, 2256($t0)
    sw $t1, 2264($t0)
    sw $t1, 2272($t0)
    sw $t1, 2280($t0)
    sw $t1, 2312($t0)
    sw $t1, 2320($t0)
    sw $t1, 2328($t0)
    sw $t1, 2336($t0)
    sw $t1, 2352($t0)
    sw $t1, 2360($t0)
    sw $t1, 2368($t0)
    sw $t1, 2376($t0)
    sw $t1, 2384($t0)
    sw $t1, 2392($t0)
    sw $t1, 2400($t0)
    sw $t1, 2408($t0)
    sw $t1, 2440($t0)
    sw $t1, 2448($t0)
    sw $t1, 2456($t0)
    sw $t1, 2464($t0)
    sw $t1, 2468($t0)
    sw $t1, 2472($t0)
    sw $t1, 2480($t0)
    sw $t1, 2484($t0)
    sw $t1, 2496($t0)
    sw $t1, 2504($t0)
    sw $t1, 2508($t0)
    sw $t1, 2512($t0)
    sw $t1, 2520($t0)
    sw $t1, 2528($t0)
    sw $t1, 2536($t0)
    
    # $t1 no longer used to we can change it
    la $t0, gravity_speed
    li $t1, 500
    sw $t1, 0($t0)
    
    # sleep for half a second
    li $v0, 32
    li $a0, 2000
    syscall
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
draw_hard:
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff      # make $t1 white
    
    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 272($t0)
    sw $t1, 280($t0)
    sw $t1, 284($t0)
    sw $t1, 288($t0)
    sw $t1, 296($t0)
    sw $t1, 300($t0)
    sw $t1, 304($t0)
    sw $t1, 312($t0)
    sw $t1, 316($t0)
    sw $t1, 320($t0)
    sw $t1, 328($t0)
    sw $t1, 332($t0)
    sw $t1, 336($t0)
    sw $t1, 392($t0)
    sw $t1, 412($t0)
    sw $t1, 424($t0)
    sw $t1, 432($t0)
    sw $t1, 440($t0)
    sw $t1, 448($t0)
    sw $t1, 460($t0)
    sw $t1, 472($t0)
    sw $t1, 520($t0)
    sw $t1, 524($t0)
    sw $t1, 528($t0)
    sw $t1, 540($t0)
    sw $t1, 552($t0)
    sw $t1, 556($t0)
    sw $t1, 560($t0)
    sw $t1, 568($t0)
    sw $t1, 572($t0)
    sw $t1, 588($t0)
    sw $t1, 656($t0)
    sw $t1, 668($t0)
    sw $t1, 680($t0)
    sw $t1, 688($t0)
    sw $t1, 696($t0)
    sw $t1, 704($t0)
    sw $t1, 716($t0)
    sw $t1, 728($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    sw $t1, 784($t0)
    sw $t1, 796($t0)
    sw $t1, 808($t0)
    sw $t1, 816($t0)
    sw $t1, 824($t0)
    sw $t1, 832($t0)
    sw $t1, 844($t0)
    sw $t1, 2696($t0)
    sw $t1, 2704($t0)
    sw $t1, 2712($t0)
    sw $t1, 2716($t0)
    sw $t1, 2720($t0)
    sw $t1, 2728($t0)
    sw $t1, 2732($t0)
    sw $t1, 2736($t0)
    sw $t1, 2744($t0)
    sw $t1, 2748($t0)
    sw $t1, 2824($t0)
    sw $t1, 2832($t0)
    sw $t1, 2840($t0)
    sw $t1, 2848($t0)
    sw $t1, 2856($t0)
    sw $t1, 2864($t0)
    sw $t1, 2872($t0)
    sw $t1, 2880($t0)
    sw $t1, 2952($t0)
    sw $t1, 2956($t0)
    sw $t1, 2960($t0)
    sw $t1, 2968($t0)
    sw $t1, 2972($t0)
    sw $t1, 2976($t0)
    sw $t1, 2984($t0)
    sw $t1, 2988($t0)
    sw $t1, 3000($t0)
    sw $t1, 3008($t0)
    sw $t1, 3080($t0)
    sw $t1, 3088($t0)
    sw $t1, 3096($t0)
    sw $t1, 3104($t0)
    sw $t1, 3112($t0)
    sw $t1, 3120($t0)
    sw $t1, 3128($t0)
    sw $t1, 3136($t0)
    sw $t1, 3208($t0)
    sw $t1, 3216($t0)
    sw $t1, 3224($t0)
    sw $t1, 3232($t0)
    sw $t1, 3240($t0)
    sw $t1, 3248($t0)
    sw $t1, 3256($t0)
    sw $t1, 3260($t0)
    
    # $t1 no longer used to we can change it
    la $t0, gravity_speed
    li $t1, 250
    sw $t1, 0($t0)
    
    # sleep for half a second
    li $v0, 32
    li $a0, 2000
    syscall
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
draw_tony:
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff      # make $t1 white
    
    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 272($t0)
    sw $t1, 280($t0)
    sw $t1, 284($t0)
    sw $t1, 288($t0)
    sw $t1, 296($t0)
    sw $t1, 300($t0)
    sw $t1, 304($t0)
    sw $t1, 312($t0)
    sw $t1, 316($t0)
    sw $t1, 320($t0)
    sw $t1, 328($t0)
    sw $t1, 332($t0)
    sw $t1, 336($t0)
    sw $t1, 392($t0)
    sw $t1, 412($t0)
    sw $t1, 424($t0)
    sw $t1, 432($t0)
    sw $t1, 440($t0)
    sw $t1, 448($t0)
    sw $t1, 460($t0)
    sw $t1, 472($t0)
    sw $t1, 520($t0)
    sw $t1, 524($t0)
    sw $t1, 528($t0)
    sw $t1, 540($t0)
    sw $t1, 552($t0)
    sw $t1, 556($t0)
    sw $t1, 560($t0)
    sw $t1, 568($t0)
    sw $t1, 572($t0)
    sw $t1, 588($t0)
    sw $t1, 656($t0)
    sw $t1, 668($t0)
    sw $t1, 680($t0)
    sw $t1, 688($t0)
    sw $t1, 696($t0)
    sw $t1, 704($t0)
    sw $t1, 716($t0)
    sw $t1, 728($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    sw $t1, 784($t0)
    sw $t1, 796($t0)
    sw $t1, 808($t0)
    sw $t1, 816($t0)
    sw $t1, 824($t0)
    sw $t1, 832($t0)
    sw $t1, 844($t0)
    sw $t1, 1160($t0)
    sw $t1, 1164($t0)
    sw $t1, 1168($t0)
    sw $t1, 1176($t0)
    sw $t1, 1180($t0)
    sw $t1, 1184($t0)
    sw $t1, 1192($t0)
    sw $t1, 1204($t0)
    sw $t1, 1212($t0)
    sw $t1, 1220($t0)
    sw $t1, 1292($t0)
    sw $t1, 1304($t0)
    sw $t1, 1312($t0)
    sw $t1, 1320($t0)
    sw $t1, 1324($t0)
    sw $t1, 1332($t0)
    sw $t1, 1340($t0)
    sw $t1, 1348($t0)
    sw $t1, 1420($t0)
    sw $t1, 1432($t0)
    sw $t1, 1440($t0)
    sw $t1, 1448($t0)
    sw $t1, 1456($t0)
    sw $t1, 1460($t0)
    sw $t1, 1472($t0)
    sw $t1, 1548($t0)
    sw $t1, 1560($t0)
    sw $t1, 1568($t0)
    sw $t1, 1576($t0)
    sw $t1, 1588($t0)
    sw $t1, 1600($t0)
    sw $t1, 1676($t0)
    sw $t1, 1688($t0)
    sw $t1, 1692($t0)
    sw $t1, 1696($t0)
    sw $t1, 1704($t0)
    sw $t1, 1716($t0)
    sw $t1, 1728($t0)
    
    # $t1 no longer used to we can change it
    # good luck.
    la $t0, gravity_speed
    sw $zero, 0($t0)
    
    # overwrite the colours.
    set_colors2:
        la $t0, used_colors   # destination
        la $t1, colors2       # source
        li $t2, 6             # number of elements

    copy_loop:
        lw $t3, 0($t1)        # load from colors2
        sw $t3, 0($t0)        # store into used_colors
    
        addi $t0, $t0, 4
        addi $t1, $t1, 4
        addi $t2, $t2, -1
        bgtz $t2, copy_loop
    
    # sleep for half a second
    li $v0, 32
    li $a0, 2000
    syscall
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
clear_screen:
    # Total number of pixels: 256 * 256 = 65536
    li $t2, 1024        # loop counter

    # Black color
    li $t1, 0x000000    

clear_loop:
    sw $t1, 0($t0)        # set pixel to black
    
    addi $t0, $t0, 4      # move to next pixel (4 bytes)
    addi $t2, $t2, -1     # decrement counter
    
    bgtz $t2, clear_loop  # loop if not done
    
    jr $ra
    
end_game:
    lw $t0, ADDR_DSPL
    jal clear_screen
    
    # Check if a key is available
    li $t0, 0xFFFF0000      # receiver control
    lw $t1, 0($t0)

    andi $t1, $t1, 1
    beq $t1, $zero, continue_end   # 🔁 keep waiting

    # Read the key
    li $t0, 0xFFFF0004
    lw $t2, 0($t0)

    # Check for valid keys
    li $t3, 'm'
    beq $t2, $t3, menu_chosen

    li $t3, 'q'
    beq $t2, $t3, quit_chosen

    continue_end:    
    lw $t0, ADDR_DSPL
    jal draw_end_screen
    
    # sleep for half a second
    li $v0, 32
    li $a0, 500
    syscall
    
    jal flash_end_screen
    
    li $v0, 32
    li $a0, 500
    syscall
    
    jal clear_screen
    j end_game
    
draw_end_screen:
    li $t1, 0xffffff      # make $t1 white
        
    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 272($t0)
    sw $t1, 280($t0)
    sw $t1, 284($t0)
    sw $t1, 288($t0)
    sw $t1, 296($t0)
    sw $t1, 312($t0)
    sw $t1, 320($t0)
    sw $t1, 324($t0)
    sw $t1, 328($t0)
    sw $t1, 392($t0)
    sw $t1, 408($t0)
    sw $t1, 416($t0)
    sw $t1, 424($t0)
    sw $t1, 428($t0)
    sw $t1, 436($t0)
    sw $t1, 440($t0)
    sw $t1, 448($t0)
    sw $t1, 520($t0)
    sw $t1, 528($t0)
    sw $t1, 536($t0)
    sw $t1, 540($t0)
    sw $t1, 544($t0)
    sw $t1, 552($t0)
    sw $t1, 560($t0)
    sw $t1, 568($t0)
    sw $t1, 576($t0)
    sw $t1, 580($t0)
    sw $t1, 584($t0)
    sw $t1, 648($t0)
    sw $t1, 656($t0)
    sw $t1, 664($t0)
    sw $t1, 672($t0)
    sw $t1, 680($t0)
    sw $t1, 688($t0)
    sw $t1, 696($t0)
    sw $t1, 704($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    sw $t1, 784($t0)
    sw $t1, 792($t0)
    sw $t1, 800($t0)
    sw $t1, 808($t0)
    sw $t1, 816($t0)
    sw $t1, 824($t0)
    sw $t1, 832($t0)
    sw $t1, 836($t0)
    sw $t1, 840($t0)
    sw $t1, 1032($t0)
    sw $t1, 1036($t0)
    sw $t1, 1040($t0)
    sw $t1, 1048($t0)
    sw $t1, 1056($t0)
    sw $t1, 1064($t0)
    sw $t1, 1068($t0)
    sw $t1, 1072($t0)
    sw $t1, 1080($t0)
    sw $t1, 1084($t0)
    sw $t1, 1088($t0)
    sw $t1, 1160($t0)
    sw $t1, 1168($t0)
    sw $t1, 1176($t0)
    sw $t1, 1184($t0)
    sw $t1, 1192($t0)
    sw $t1, 1208($t0)
    sw $t1, 1216($t0)
    sw $t1, 1288($t0)
    sw $t1, 1296($t0)
    sw $t1, 1304($t0)
    sw $t1, 1312($t0)
    sw $t1, 1320($t0)
    sw $t1, 1324($t0)
    sw $t1, 1328($t0)
    sw $t1, 1336($t0)
    sw $t1, 1340($t0)
    sw $t1, 1416($t0)
    sw $t1, 1424($t0)
    sw $t1, 1432($t0)
    sw $t1, 1440($t0)
    sw $t1, 1448($t0)
    sw $t1, 1464($t0)
    sw $t1, 1472($t0)
    sw $t1, 1544($t0)
    sw $t1, 1548($t0)
    sw $t1, 1552($t0)
    sw $t1, 1560($t0)
    sw $t1, 1564($t0)
    sw $t1, 1568($t0)
    sw $t1, 1576($t0)
    sw $t1, 1580($t0)
    sw $t1, 1584($t0)
    sw $t1, 1592($t0)
    sw $t1, 1600($t0)
    sw $t1, 1608($t0)
    sw $t1, 1928($t0)
    sw $t1, 1944($t0)
    sw $t1, 1952($t0)
    sw $t1, 1956($t0)
    sw $t1, 1960($t0)
    sw $t1, 1968($t0)
    sw $t1, 1980($t0)
    sw $t1, 1988($t0)
    sw $t1, 1996($t0)
    sw $t1, 2056($t0)
    sw $t1, 2060($t0)
    sw $t1, 2068($t0)
    sw $t1, 2072($t0)
    sw $t1, 2080($t0)
    sw $t1, 2096($t0)
    sw $t1, 2100($t0)
    sw $t1, 2108($t0)
    sw $t1, 2116($t0)
    sw $t1, 2124($t0)
    sw $t1, 2184($t0)
    sw $t1, 2192($t0)
    sw $t1, 2200($t0)
    sw $t1, 2208($t0)
    sw $t1, 2212($t0)
    sw $t1, 2216($t0)
    sw $t1, 2224($t0)
    sw $t1, 2232($t0)
    sw $t1, 2236($t0)
    sw $t1, 2244($t0)
    sw $t1, 2252($t0)
    sw $t1, 2312($t0)
    sw $t1, 2320($t0)
    sw $t1, 2328($t0)
    sw $t1, 2336($t0)
    sw $t1, 2352($t0)
    sw $t1, 2364($t0)
    sw $t1, 2372($t0)
    sw $t1, 2380($t0)
    sw $t1, 2440($t0)
    sw $t1, 2448($t0)
    sw $t1, 2456($t0)
    sw $t1, 2464($t0)
    sw $t1, 2468($t0)
    sw $t1, 2472($t0)
    sw $t1, 2480($t0)
    sw $t1, 2492($t0)
    sw $t1, 2500($t0)
    sw $t1, 2504($t0)
    sw $t1, 2508($t0)
    sw $t1, 2696($t0)
    sw $t1, 2700($t0)
    sw $t1, 2704($t0)
    sw $t1, 2712($t0)
    sw $t1, 2720($t0)
    sw $t1, 2728($t0)
    sw $t1, 2736($t0)
    sw $t1, 2740($t0)
    sw $t1, 2744($t0)
    sw $t1, 2824($t0)
    sw $t1, 2832($t0)
    sw $t1, 2840($t0)
    sw $t1, 2848($t0)
    sw $t1, 2856($t0)
    sw $t1, 2868($t0)
    sw $t1, 2952($t0)
    sw $t1, 2960($t0)
    sw $t1, 2968($t0)
    sw $t1, 2976($t0)
    sw $t1, 2984($t0)
    sw $t1, 2996($t0)
    sw $t1, 3080($t0)
    sw $t1, 3088($t0)
    sw $t1, 3096($t0)
    sw $t1, 3104($t0)
    sw $t1, 3112($t0)
    sw $t1, 3124($t0)
    sw $t1, 3208($t0)
    sw $t1, 3212($t0)
    sw $t1, 3224($t0)
    sw $t1, 3228($t0)
    sw $t1, 3232($t0)
    sw $t1, 3240($t0)
    sw $t1, 3252($t0)
    sw $t1, 3344($t0)

    jr $ra
    
flash_end_screen:
    li $t1, 0x000000     # make $t1 black
    
    sw $t1, 1928($t0)
    sw $t1, 1944($t0)
    sw $t1, 2056($t0)
    sw $t1, 2060($t0)
    sw $t1, 2068($t0)
    sw $t1, 2072($t0)
    sw $t1, 2184($t0)
    sw $t1, 2192($t0)
    sw $t1, 2200($t0)
    sw $t1, 2312($t0)
    sw $t1, 2320($t0)
    sw $t1, 2328($t0)
    sw $t1, 2440($t0)
    sw $t1, 2448($t0)
    sw $t1, 2456($t0)
    sw $t1, 2696($t0)
    sw $t1, 2700($t0)
    sw $t1, 2704($t0)
    sw $t1, 2824($t0)
    sw $t1, 2832($t0)
    sw $t1, 2952($t0)
    sw $t1, 2960($t0)
    sw $t1, 3080($t0)
    sw $t1, 3088($t0)
    sw $t1, 3208($t0)
    sw $t1, 3212($t0)
    sw $t1, 3344($t0)
    
    jr $ra
    
menu_chosen:
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff      # make $t1 white

    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 272($t0)
    sw $t1, 280($t0)
    sw $t1, 284($t0)
    sw $t1, 288($t0)
    sw $t1, 296($t0)
    sw $t1, 312($t0)
    sw $t1, 320($t0)
    sw $t1, 324($t0)
    sw $t1, 328($t0)
    sw $t1, 392($t0)
    sw $t1, 408($t0)
    sw $t1, 416($t0)
    sw $t1, 424($t0)
    sw $t1, 428($t0)
    sw $t1, 436($t0)
    sw $t1, 440($t0)
    sw $t1, 448($t0)
    sw $t1, 520($t0)
    sw $t1, 528($t0)
    sw $t1, 536($t0)
    sw $t1, 540($t0)
    sw $t1, 544($t0)
    sw $t1, 552($t0)
    sw $t1, 560($t0)
    sw $t1, 568($t0)
    sw $t1, 576($t0)
    sw $t1, 580($t0)
    sw $t1, 584($t0)
    sw $t1, 648($t0)
    sw $t1, 656($t0)
    sw $t1, 664($t0)
    sw $t1, 672($t0)
    sw $t1, 680($t0)
    sw $t1, 688($t0)
    sw $t1, 696($t0)
    sw $t1, 704($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    sw $t1, 784($t0)
    sw $t1, 792($t0)
    sw $t1, 800($t0)
    sw $t1, 808($t0)
    sw $t1, 816($t0)
    sw $t1, 824($t0)
    sw $t1, 832($t0)
    sw $t1, 836($t0)
    sw $t1, 840($t0)
    sw $t1, 1032($t0)
    sw $t1, 1036($t0)
    sw $t1, 1040($t0)
    sw $t1, 1048($t0)
    sw $t1, 1056($t0)
    sw $t1, 1064($t0)
    sw $t1, 1068($t0)
    sw $t1, 1072($t0)
    sw $t1, 1080($t0)
    sw $t1, 1084($t0)
    sw $t1, 1088($t0)
    sw $t1, 1160($t0)
    sw $t1, 1168($t0)
    sw $t1, 1176($t0)
    sw $t1, 1184($t0)
    sw $t1, 1192($t0)
    sw $t1, 1208($t0)
    sw $t1, 1216($t0)
    sw $t1, 1288($t0)
    sw $t1, 1296($t0)
    sw $t1, 1304($t0)
    sw $t1, 1312($t0)
    sw $t1, 1320($t0)
    sw $t1, 1324($t0)
    sw $t1, 1328($t0)
    sw $t1, 1336($t0)
    sw $t1, 1340($t0)
    sw $t1, 1416($t0)
    sw $t1, 1424($t0)
    sw $t1, 1432($t0)
    sw $t1, 1440($t0)
    sw $t1, 1448($t0)
    sw $t1, 1464($t0)
    sw $t1, 1472($t0)
    sw $t1, 1544($t0)
    sw $t1, 1548($t0)
    sw $t1, 1552($t0)
    sw $t1, 1560($t0)
    sw $t1, 1564($t0)
    sw $t1, 1568($t0)
    sw $t1, 1576($t0)
    sw $t1, 1580($t0)
    sw $t1, 1584($t0)
    sw $t1, 1592($t0)
    sw $t1, 1600($t0)
    sw $t1, 1608($t0)
    sw $t1, 1928($t0)
    sw $t1, 1944($t0)
    sw $t1, 1952($t0)
    sw $t1, 1956($t0)
    sw $t1, 1960($t0)
    sw $t1, 1968($t0)
    sw $t1, 1980($t0)
    sw $t1, 1988($t0)
    sw $t1, 1996($t0)
    sw $t1, 2056($t0)
    sw $t1, 2060($t0)
    sw $t1, 2068($t0)
    sw $t1, 2072($t0)
    sw $t1, 2080($t0)
    sw $t1, 2096($t0)
    sw $t1, 2100($t0)
    sw $t1, 2108($t0)
    sw $t1, 2116($t0)
    sw $t1, 2124($t0)
    sw $t1, 2184($t0)
    sw $t1, 2192($t0)
    sw $t1, 2200($t0)
    sw $t1, 2208($t0)
    sw $t1, 2212($t0)
    sw $t1, 2216($t0)
    sw $t1, 2224($t0)
    sw $t1, 2232($t0)
    sw $t1, 2236($t0)
    sw $t1, 2244($t0)
    sw $t1, 2252($t0)
    sw $t1, 2312($t0)
    sw $t1, 2320($t0)
    sw $t1, 2328($t0)
    sw $t1, 2336($t0)
    sw $t1, 2352($t0)
    sw $t1, 2364($t0)
    sw $t1, 2372($t0)
    sw $t1, 2380($t0)
    sw $t1, 2440($t0)
    sw $t1, 2448($t0)
    sw $t1, 2456($t0)
    sw $t1, 2464($t0)
    sw $t1, 2468($t0)
    sw $t1, 2472($t0)
    sw $t1, 2480($t0)
    sw $t1, 2492($t0)
    sw $t1, 2500($t0)
    sw $t1, 2504($t0)
    sw $t1, 2508($t0)
    
    # sleep for half a second
    li $v0, 32
    li $a0, 2000
    syscall
    
    # reset mutable data
    
    reset_state:
        # ---------- gravity_speed ----------
        la $t0, gravity_speed
        sw $zero, 0($t0)
    
        # ---------- current_x ----------
        la $t0, current_x
        sw $zero, 0($t0)
    
        # ---------- col_locs (3 words) ----------
        la $t0, col_locs
        li $t1, 3
    reset_col_locs:
        sw $zero, 0($t0)
        addi $t0, $t0, 4
        addi $t1, $t1, -1
        bgtz $t1, reset_col_locs
    
        # ---------- column (3 words) ----------
        la $t0, column
        li $t1, 3
    reset_column:
        sw $zero, 0($t0)
        addi $t0, $t0, 4
        addi $t1, $t1, -1
        bgtz $t1, reset_column
    
        # ---------- next_column (3 words) ----------
        la $t0, next_column
        li $t1, 3
    reset_next_column:
        sw $zero, 0($t0)
        addi $t0, $t0, 4
        addi $t1, $t1, -1
        bgtz $t1, reset_next_column
    
        # ---------- land_locations (6 words) ----------
        la $t0, land_locations
        li $t1, 6
    reset_land:
        sw $zero, 0($t0)
        addi $t0, $t0, 4
        addi $t1, $t1, -1
        bgtz $t1, reset_land
    
        # ---------- check_locations (84 words) ----------
        la $t0, check_locations
        li $t1, 84
    reset_check:
        sw $zero, 0($t0)
        addi $t0, $t0, 4
        addi $t1, $t1, -1
        bgtz $t1, reset_check
    
        # ---------- candidates (84 words) ----------
        la $t0, candidates
        li $t1, 84
    reset_candidates:
        sw $zero, 0($t0)
        addi $t0, $t0, 4
        addi $t1, $t1, -1
        bgtz $t1, reset_candidates
    
        # ---------- to_be_deleted (84 words) ----------
        la $t0, to_be_deleted
        li $t1, 84
    reset_deleted:
        sw $zero, 0($t0)
        addi $t0, $t0, 4
        addi $t1, $t1, -1
        bgtz $t1, reset_deleted
    
        # ---------- reset pointer-based values ----------
        la $t0, current_pos
        li $t1, 0x10008004
        sw $t1, 0($t0)
    
        la $t0, previous_pos
        sw $t1, 0($t0)
    
        la $t0, col_hitbox
        li $t1, 0x10008184
        sw $t1, 0($t0)
        
    # restore original colours
    restore_colors:
        la $t0, used_colors
        la $t1, colors
        li $t2, 6

    restore_loop:
        lw $t3, 0($t1)
        sw $t3, 0($t0)
    
        addi $t0, $t0, 4
        addi $t1, $t1, 4
        addi $t2, $t2, -1
        bgtz $t2, restore_loop

    j main

quit_chosen:
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff      # make $t1 white
    
    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 272($t0)
    sw $t1, 280($t0)
    sw $t1, 284($t0)
    sw $t1, 288($t0)
    sw $t1, 296($t0)
    sw $t1, 312($t0)
    sw $t1, 320($t0)
    sw $t1, 324($t0)
    sw $t1, 328($t0)
    sw $t1, 392($t0)
    sw $t1, 408($t0)
    sw $t1, 416($t0)
    sw $t1, 424($t0)
    sw $t1, 428($t0)
    sw $t1, 436($t0)
    sw $t1, 440($t0)
    sw $t1, 448($t0)
    sw $t1, 520($t0)
    sw $t1, 528($t0)
    sw $t1, 536($t0)
    sw $t1, 540($t0)
    sw $t1, 544($t0)
    sw $t1, 552($t0)
    sw $t1, 560($t0)
    sw $t1, 568($t0)
    sw $t1, 576($t0)
    sw $t1, 580($t0)
    sw $t1, 584($t0)
    sw $t1, 648($t0)
    sw $t1, 656($t0)
    sw $t1, 664($t0)
    sw $t1, 672($t0)
    sw $t1, 680($t0)
    sw $t1, 688($t0)
    sw $t1, 696($t0)
    sw $t1, 704($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    sw $t1, 784($t0)
    sw $t1, 792($t0)
    sw $t1, 800($t0)
    sw $t1, 808($t0)
    sw $t1, 816($t0)
    sw $t1, 824($t0)
    sw $t1, 832($t0)
    sw $t1, 836($t0)
    sw $t1, 840($t0)
    sw $t1, 1032($t0)
    sw $t1, 1036($t0)
    sw $t1, 1040($t0)
    sw $t1, 1048($t0)
    sw $t1, 1056($t0)
    sw $t1, 1064($t0)
    sw $t1, 1068($t0)
    sw $t1, 1072($t0)
    sw $t1, 1080($t0)
    sw $t1, 1084($t0)
    sw $t1, 1088($t0)
    sw $t1, 1160($t0)
    sw $t1, 1168($t0)
    sw $t1, 1176($t0)
    sw $t1, 1184($t0)
    sw $t1, 1192($t0)
    sw $t1, 1208($t0)
    sw $t1, 1216($t0)
    sw $t1, 1288($t0)
    sw $t1, 1296($t0)
    sw $t1, 1304($t0)
    sw $t1, 1312($t0)
    sw $t1, 1320($t0)
    sw $t1, 1324($t0)
    sw $t1, 1328($t0)
    sw $t1, 1336($t0)
    sw $t1, 1340($t0)
    sw $t1, 1416($t0)
    sw $t1, 1424($t0)
    sw $t1, 1432($t0)
    sw $t1, 1440($t0)
    sw $t1, 1448($t0)
    sw $t1, 1464($t0)
    sw $t1, 1472($t0)
    sw $t1, 1544($t0)
    sw $t1, 1548($t0)
    sw $t1, 1552($t0)
    sw $t1, 1560($t0)
    sw $t1, 1564($t0)
    sw $t1, 1568($t0)
    sw $t1, 1576($t0)
    sw $t1, 1580($t0)
    sw $t1, 1584($t0)
    sw $t1, 1592($t0)
    sw $t1, 1600($t0)
    sw $t1, 1608($t0)
    sw $t1, 2696($t0)
    sw $t1, 2700($t0)
    sw $t1, 2704($t0)
    sw $t1, 2712($t0)
    sw $t1, 2720($t0)
    sw $t1, 2728($t0)
    sw $t1, 2736($t0)
    sw $t1, 2740($t0)
    sw $t1, 2744($t0)
    sw $t1, 2824($t0)
    sw $t1, 2832($t0)
    sw $t1, 2840($t0)
    sw $t1, 2848($t0)
    sw $t1, 2856($t0)
    sw $t1, 2868($t0)
    sw $t1, 2952($t0)
    sw $t1, 2960($t0)
    sw $t1, 2968($t0)
    sw $t1, 2976($t0)
    sw $t1, 2984($t0)
    sw $t1, 2996($t0)
    sw $t1, 3080($t0)
    sw $t1, 3088($t0)
    sw $t1, 3096($t0)
    sw $t1, 3104($t0)
    sw $t1, 3112($t0)
    sw $t1, 3124($t0)
    sw $t1, 3208($t0)
    sw $t1, 3212($t0)
    sw $t1, 3224($t0)
    sw $t1, 3228($t0)
    sw $t1, 3232($t0)
    sw $t1, 3240($t0)
    sw $t1, 3252($t0)
    sw $t1, 3344($t0)
    
    li $v0, 10 # terminate the program gracefully
    syscall
    
    draw_pause_menu:
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff      # make $t1 white
    
    sw $t1, 940($t0)
    sw $t1, 944($t0)
    sw $t1, 948($t0)
    sw $t1, 956($t0)
    sw $t1, 960($t0)
    sw $t1, 964($t0)
    sw $t1, 972($t0)
    sw $t1, 980($t0)
    sw $t1, 988($t0)
    sw $t1, 992($t0)
    sw $t1, 996($t0)
    sw $t1, 1004($t0)
    sw $t1, 1008($t0)
    sw $t1, 1012($t0)
    sw $t1, 1068($t0)
    sw $t1, 1076($t0)
    sw $t1, 1084($t0)
    sw $t1, 1092($t0)
    sw $t1, 1100($t0)
    sw $t1, 1108($t0)
    sw $t1, 1116($t0)
    sw $t1, 1132($t0)
    sw $t1, 1196($t0)
    sw $t1, 1200($t0)
    sw $t1, 1204($t0)
    sw $t1, 1212($t0)
    sw $t1, 1216($t0)
    sw $t1, 1220($t0)
    sw $t1, 1228($t0)
    sw $t1, 1236($t0)
    sw $t1, 1244($t0)
    sw $t1, 1248($t0)
    sw $t1, 1252($t0)
    sw $t1, 1260($t0)
    sw $t1, 1264($t0)
    sw $t1, 1268($t0)
    sw $t1, 1324($t0)
    sw $t1, 1340($t0)
    sw $t1, 1348($t0)
    sw $t1, 1356($t0)
    sw $t1, 1364($t0)
    sw $t1, 1380($t0)
    sw $t1, 1388($t0)
    sw $t1, 1452($t0)
    sw $t1, 1468($t0)
    sw $t1, 1476($t0)
    sw $t1, 1484($t0)
    sw $t1, 1488($t0)
    sw $t1, 1492($t0)
    sw $t1, 1500($t0)
    sw $t1, 1504($t0)
    sw $t1, 1508($t0)
    sw $t1, 1516($t0)
    sw $t1, 1520($t0)
    sw $t1, 1524($t0)
    sw $t1, 1836($t0)
    sw $t1, 1840($t0)
    sw $t1, 1844($t0)
    sw $t1, 1852($t0)
    sw $t1, 1860($t0)
    sw $t1, 1868($t0)
    sw $t1, 1876($t0)
    sw $t1, 1880($t0)
    sw $t1, 1884($t0)
    sw $t1, 1964($t0)
    sw $t1, 1972($t0)
    sw $t1, 1980($t0)
    sw $t1, 1988($t0)
    sw $t1, 1996($t0)
    sw $t1, 2008($t0)
    sw $t1, 2092($t0)
    sw $t1, 2100($t0)
    sw $t1, 2108($t0)
    sw $t1, 2116($t0)
    sw $t1, 2124($t0)
    sw $t1, 2136($t0)
    sw $t1, 2220($t0)
    sw $t1, 2228($t0)
    sw $t1, 2236($t0)
    sw $t1, 2244($t0)
    sw $t1, 2252($t0)
    sw $t1, 2264($t0)
    sw $t1, 2348($t0)
    sw $t1, 2352($t0)
    sw $t1, 2364($t0)
    sw $t1, 2368($t0)
    sw $t1, 2372($t0)
    sw $t1, 2380($t0)
    sw $t1, 2392($t0)
    sw $t1, 2484($t0)
    
    jr $ra
    
clear_pause_menu:
    lw $t0, ADDR_DSPL
    li $t1, 0x000000      # make $t1 black
    
    sw $t1, 940($t0)
    sw $t1, 944($t0)
    sw $t1, 948($t0)
    sw $t1, 956($t0)
    sw $t1, 960($t0)
    sw $t1, 964($t0)
    sw $t1, 972($t0)
    sw $t1, 980($t0)
    sw $t1, 988($t0)
    sw $t1, 992($t0)
    sw $t1, 996($t0)
    sw $t1, 1004($t0)
    sw $t1, 1008($t0)
    sw $t1, 1012($t0)
    sw $t1, 1068($t0)
    sw $t1, 1076($t0)
    sw $t1, 1084($t0)
    sw $t1, 1092($t0)
    sw $t1, 1100($t0)
    sw $t1, 1108($t0)
    sw $t1, 1116($t0)
    sw $t1, 1132($t0)
    sw $t1, 1196($t0)
    sw $t1, 1200($t0)
    sw $t1, 1204($t0)
    sw $t1, 1212($t0)
    sw $t1, 1216($t0)
    sw $t1, 1220($t0)
    sw $t1, 1228($t0)
    sw $t1, 1236($t0)
    sw $t1, 1244($t0)
    sw $t1, 1248($t0)
    sw $t1, 1252($t0)
    sw $t1, 1260($t0)
    sw $t1, 1264($t0)
    sw $t1, 1268($t0)
    sw $t1, 1324($t0)
    sw $t1, 1340($t0)
    sw $t1, 1348($t0)
    sw $t1, 1356($t0)
    sw $t1, 1364($t0)
    sw $t1, 1380($t0)
    sw $t1, 1388($t0)
    sw $t1, 1452($t0)
    sw $t1, 1468($t0)
    sw $t1, 1476($t0)
    sw $t1, 1484($t0)
    sw $t1, 1488($t0)
    sw $t1, 1492($t0)
    sw $t1, 1500($t0)
    sw $t1, 1504($t0)
    sw $t1, 1508($t0)
    sw $t1, 1516($t0)
    sw $t1, 1520($t0)
    sw $t1, 1524($t0)
    sw $t1, 1836($t0)
    sw $t1, 1840($t0)
    sw $t1, 1844($t0)
    sw $t1, 1852($t0)
    sw $t1, 1860($t0)
    sw $t1, 1868($t0)
    sw $t1, 1876($t0)
    sw $t1, 1880($t0)
    sw $t1, 1884($t0)
    sw $t1, 1964($t0)
    sw $t1, 1972($t0)
    sw $t1, 1980($t0)
    sw $t1, 1988($t0)
    sw $t1, 1996($t0)
    sw $t1, 2008($t0)
    sw $t1, 2092($t0)
    sw $t1, 2100($t0)
    sw $t1, 2108($t0)
    sw $t1, 2116($t0)
    sw $t1, 2124($t0)
    sw $t1, 2136($t0)
    sw $t1, 2220($t0)
    sw $t1, 2228($t0)
    sw $t1, 2236($t0)
    sw $t1, 2244($t0)
    sw $t1, 2252($t0)
    sw $t1, 2264($t0)
    sw $t1, 2348($t0)
    sw $t1, 2352($t0)
    sw $t1, 2364($t0)
    sw $t1, 2368($t0)
    sw $t1, 2372($t0)
    sw $t1, 2380($t0)
    sw $t1, 2392($t0)
    sw $t1, 2484($t0)
    
    jr $ra
    
unpause:
    jal clear_pause_menu
    
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff      # make $t1 white
    
    sw $t1, 940($t0)
    sw $t1, 944($t0)
    sw $t1, 948($t0)
    sw $t1, 956($t0)
    sw $t1, 960($t0)
    sw $t1, 964($t0)
    sw $t1, 972($t0)
    sw $t1, 980($t0)
    sw $t1, 988($t0)
    sw $t1, 992($t0)
    sw $t1, 996($t0)
    sw $t1, 1004($t0)
    sw $t1, 1008($t0)
    sw $t1, 1012($t0)
    sw $t1, 1068($t0)
    sw $t1, 1076($t0)
    sw $t1, 1084($t0)
    sw $t1, 1092($t0)
    sw $t1, 1100($t0)
    sw $t1, 1108($t0)
    sw $t1, 1116($t0)
    sw $t1, 1132($t0)
    sw $t1, 1196($t0)
    sw $t1, 1200($t0)
    sw $t1, 1204($t0)
    sw $t1, 1212($t0)
    sw $t1, 1216($t0)
    sw $t1, 1220($t0)
    sw $t1, 1228($t0)
    sw $t1, 1236($t0)
    sw $t1, 1244($t0)
    sw $t1, 1248($t0)
    sw $t1, 1252($t0)
    sw $t1, 1260($t0)
    sw $t1, 1264($t0)
    sw $t1, 1268($t0)
    sw $t1, 1324($t0)
    sw $t1, 1340($t0)
    sw $t1, 1348($t0)
    sw $t1, 1356($t0)
    sw $t1, 1364($t0)
    sw $t1, 1380($t0)
    sw $t1, 1388($t0)
    sw $t1, 1452($t0)
    sw $t1, 1468($t0)
    sw $t1, 1476($t0)
    sw $t1, 1484($t0)
    sw $t1, 1488($t0)
    sw $t1, 1492($t0)
    sw $t1, 1500($t0)
    sw $t1, 1504($t0)
    sw $t1, 1508($t0)
    sw $t1, 1516($t0)
    sw $t1, 1520($t0)
    sw $t1, 1524($t0)
    
    # Sleep for 2 seconds
    li $v0, 32
    li $a0, 2000
    syscall
    
    jal clear_pause_menu
    
    j key_loop
    
quit_from_pause:
    jal clear_pause_menu
    
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff
    
    sw $t1, 1836($t0)
    sw $t1, 1840($t0)
    sw $t1, 1844($t0)
    sw $t1, 1852($t0)
    sw $t1, 1860($t0)
    sw $t1, 1868($t0)
    sw $t1, 1876($t0)
    sw $t1, 1880($t0)
    sw $t1, 1884($t0)
    sw $t1, 1964($t0)
    sw $t1, 1972($t0)
    sw $t1, 1980($t0)
    sw $t1, 1988($t0)
    sw $t1, 1996($t0)
    sw $t1, 2008($t0)
    sw $t1, 2092($t0)
    sw $t1, 2100($t0)
    sw $t1, 2108($t0)
    sw $t1, 2116($t0)
    sw $t1, 2124($t0)
    sw $t1, 2136($t0)
    sw $t1, 2220($t0)
    sw $t1, 2228($t0)
    sw $t1, 2236($t0)
    sw $t1, 2244($t0)
    sw $t1, 2252($t0)
    sw $t1, 2264($t0)
    sw $t1, 2348($t0)
    sw $t1, 2352($t0)
    sw $t1, 2364($t0)
    sw $t1, 2368($t0)
    sw $t1, 2372($t0)
    sw $t1, 2380($t0)
    sw $t1, 2392($t0)
    sw $t1, 2484($t0)
    
    j respond_to_Q
    
flash_pause:
    lw $t0, ADDR_DSPL
    li $t1, 0x000000      # make $t1 black
    
    sw $t1, 940($t0)
    sw $t1, 944($t0)
    sw $t1, 948($t0)
    sw $t1, 1068($t0)
    sw $t1, 1076($t0)
    sw $t1, 1196($t0)
    sw $t1, 1200($t0)
    sw $t1, 1204($t0)
    sw $t1, 1324($t0)
    sw $t1, 1452($t0)
    sw $t1, 1836($t0)
    sw $t1, 1840($t0)
    sw $t1, 1844($t0)
    sw $t1, 1964($t0)
    sw $t1, 1972($t0)
    sw $t1, 2092($t0)
    sw $t1, 2100($t0)
    sw $t1, 2220($t0)
    sw $t1, 2228($t0)
    sw $t1, 2348($t0)
    sw $t1, 2352($t0)
    sw $t1, 2484($t0)
    
    jr $ra