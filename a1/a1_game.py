"""CSC148 Assignment 1
"""
from __future__ import annotations

import sys

import pygame

import a1
import constants

# Feel free to modify any of these constant values.

# Game Screen dimensions in pixels
SCREEN_WIDTH = 700
SCREEN_HEIGHT = 700

# Dimensions of the game board, in squares.
BOARD_WIDTH = 32
BOARD_HEIGHT = 32

# Number of milliseconds to wait between iterations of the main game loop.
# This changes the speed of the game. The main player can move at most
# once every LOOP_DELAY milliseconds.
LOOP_DELAY = 50

# Character icons
BACKGROUND_ICON = 'icons/Background.png'
BOUNDARY_ICON = 'icons/Boundary.png'
WHITE = 'icons/WhiteSquare.png'
RED_ICON = 'icons/RedGem.png'
ORANGE_ICON = 'icons/OrangeGem.png'
GREEN_ICON = 'icons/GreenGem.png'
BLUE_ICON = 'icons/BlueGem.png'
PURPLE_ICON = 'icons/PurpleGem.png'
DARK_ICON = 'icons/DarkGem.png'


def make_image(icon_file: str, width: int, height: int) -> pygame.surface:
    """
    A helper function for loading <icon_file> as a pygame image
    and scaling it to have dimensions <width> and <height>
    """
    pic = pygame.image.load(icon_file)
    return pygame.transform.scale(pic, (width, height))


def menu_screen(difficulty: str) -> str:
    """
    Displays the Menu Screen for Easy, Medium, Hard difficulties.
    """

    for event in pygame.event.get():
        # Stop if user closed the window.
        if event.type == pygame.constants.QUIT:
            sys.exit()
        if event.type == pygame.constants.KEYDOWN:
            if event.key == pygame.constants.K_e:
                difficulty = "e"
            if event.key == pygame.constants.K_m:
                difficulty = "m"
            if event.key == pygame.constants.K_h:
                difficulty = "h"
            if event.key == pygame.constants.K_t:
                difficulty = "t"

    return difficulty


class ColumnsGame:
    """The user interface for the Columns game!

    Attributes:
    - width: width of the underlying game board
    - height: height of the underlying game board
    - square_size: size of each square in the game
    - _board: the board containing the state of the game
    - _screen: the pygame screen to draw the stage on
    - _icon_map: the mapping from letter representations to image icons
    - _background_tile: image icon for the background
    - _last_state: the string representation of the last board state
    """

    width: int
    height: int
    square_size: int
    _board: a1.GameBoard
    _screen: pygame.Surface
    _icon_map: dict[str, pygame.Surface]
    _background_tile: pygame.Surface
    _boundary_tile: pygame.Surface
    _last_state: list[list[str]] | None

    def __init__(self, w: int, h: int) -> None:
        """Initialize this game to be of the given width <w> and height <h> in
        squares. If <board_string> is not specified, then a random board
        is generated. Otherwise, GameBoard.setup_from_grid is used to populate
        the board.
        """
        self._board = a1.GameBoard(w, h, 14)

        self.square_size = min(int(SCREEN_WIDTH / w),
                               int(SCREEN_HEIGHT / h))

        # Initialize a window of these pixel dimensions for display
        self._screen = pygame.display.set_mode((w * self.square_size,
                                                h * self.square_size)
                                               )

        # a function defined for convenience that we use to set up the
        # _icon_map below.
        def image_loader(x: str) -> pygame.surface:
            return make_image(x, self.square_size, self.square_size)

        # Initialize the background tile
        self._background_tile = image_loader(BACKGROUND_ICON)

        self._icon_map = {'R': image_loader(RED_ICON),
                          'O': image_loader(ORANGE_ICON),
                          'G': image_loader(GREEN_ICON),
                          'B': image_loader(BLUE_ICON),
                          'P': image_loader(PURPLE_ICON),
                          'D': image_loader(DARK_ICON),
                          'Z': image_loader(BOUNDARY_ICON),
                          'W': image_loader(WHITE)
                          }

        self._last_state = None
        self.height, self.width = self._board.height, self._board.width

    def draw(self) -> None:
        """
        Draw the given board state using pygame.
        """
        state = self._board.to_grid()
        self._last_state = state

        for x in range(len(state[0])):
            for y in range(len(state)):
                c = state[y][x]
                rectangle = pygame.Rect(x * self.square_size,
                                        y * self.square_size,
                                        self.square_size, self.square_size)
                # Draw the icon onto the rectangle.
                self._screen.blit(self._background_tile, (x * self.square_size,
                                                          y * self.square_size))
                if c in self._icon_map:
                    self._screen.blit(self._icon_map[c], rectangle)

        # Update the screen.
        pygame.display.flip()

    def draw_menu(self) -> None:
        """
        Draw the game over screen.
        """
        board = constants.MENU
        self._board.set_board(board)

    def draw_game(self) -> None:
        """
        Draw the game over screen.
        """
        board = constants.GAME
        self._board.set_board(board)

    def draw_end(self) -> None:
        """
        Draw the game over screen.
        """

    def play(self, difficulty: str = "") -> None:
        """
        Play the game!
        """
        # self.draw_menu()
        while difficulty == "":
            difficulty = menu_screen(difficulty)

        self._board.difficulty = difficulty
        self.draw_game()

        while not self._board.ended:
            pygame.time.wait(LOOP_DELAY)
            # Handle all inputs that are in the event queue,
            # i.e., that occurred since the last iteration.
            self._handle_user_input()

        # game has ended, print message
        self.draw_end()

        # Keep the screen on after the game has ended. Can be commented out
        while True:
            pygame.time.wait(LOOP_DELAY * 5)
            for event in pygame.event.get():
                # Stop if user closed the window.
                if event.type == pygame.constants.QUIT:
                    sys.exit()

    def _handle_user_input(self) -> None:
        """Handle user input, give characters their turns, and
        redraw the game board.
        """
        for event in pygame.event.get():
            # Stop if user closed the window.
            if event.type == pygame.constants.QUIT:
                sys.exit()
            if event.type == pygame.constants.KEYDOWN:
                key = None
                if event.key == pygame.constants.K_w:
                    key = "w"
                if event.key == pygame.constants.K_s:
                    key = "s"
                if event.key == pygame.constants.K_a:
                    key = "a"
                if event.key == pygame.constants.K_d:
                    key = "d"
                if event.key == pygame.constants.K_q:
                    key = "q"
                if key is not None:
                    self._board.handle_event(key)

            # Give every character a turn in the game and draw the board.
        self._board.give_turns()
        self.draw()


if __name__ == '__main__':
    rc = ColumnsGame(BOARD_WIDTH, BOARD_HEIGHT)

    rc.play()
