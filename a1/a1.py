"""CSC148 Assignment 1
"""

from __future__ import annotations

import random


# Directions dx, dy
LEFT = (-1, 0)
RIGHT = (1, 0)
UP = (0, -1)
DOWN = (0, 1)
TOPLEFT = (-1, -1)
TOPRIGHT = (1, -1)
BOTLEFT = (-1, 1)
BOTRIGHT = (1, 1)
DIRECTIONS = [LEFT, RIGHT, UP, DOWN, TOPLEFT, BOTRIGHT, BOTLEFT, TOPRIGHT]


class GameBoard:
    """A game board on which the game is played.

    Public Attributes:
    - ended: whether this game has ended or not
    - turns: how many turns have passed in the game
    - width: how many squares wide this board is
    - height: how many squares high this board is

    Private Attributes:
    - _player: the player of the game.
    - _board: a list of lists where each inner list is a row of the gameboard
    and each inner list is a list of lists where each inner list represents a
    square and contains the characters on that square.

    Representation Invariants:
    - self.turns >= 0
    - self.width > 0
    - self.height > 0
    - self.ended is True if and only if the game has ended


    Sample Usage:
    See examples in individual method docstrings.
    """

    ended: bool
    turns: int
    width: int
    height: int
    animate: bool
    _player: Player | None
    _board: list[list[list[Character]]]
    _land_locations: list[int] | None # for player

    def __init__(self, w: int, h: int, *args) -> None:
        """Initialize this Board to be of the given width <w> and height <h> in
        squares. A board is initially empty (no characters) and no turns have
        been taken.

        >>> b = GameBoard(3, 3)
        >>> b.width == 3
        True
        >>> b.height == 3
        True
        >>> b.turns == 0
        True
        >>> b.ended
        False
        """

        self.ended = False
        self.turns = 0

        self.width = w
        self.height = h

        self.animate = False

        self._player = None

        self._board = [[[] for i in range(w)] for j in range(h)]

        if args:
            land_height = args[0]
            if isinstance(land_height, int):
                self._land_locations= [land_height for i in range(6)]

    def set_board(self, board: list[list[list[str]]], *args) -> None:
        """Set the board to a preconfigured one.
        Preconditions:
        - len(board) = self.height
        - len(board[0]) = self.width
        - each string is a symbol of a valid character
        """
        clear = False
        if args:
            if isinstance(args[0], bool):
                if args[0]:
                    self._player = Player(self)
                else:
                    clear = True
        for i in range(len(board)):
            row = board[i]
            for j in range(len(row)):
                character = row[j]
                if character:
                    symbol = character[0]
                    character_factory(symbol, self, j, i)
                else:
                    if clear:
                        self._board[i][j] = []

    def get_land_location(self, index: int) -> int:
        if not self._land_locations:
            return 0
        if 0 <= index <= 6:
            return self._land_locations[index]
        return 0

    def update_land_location(self, index: int, new_ll: int) -> None:
        if not self._land_locations:
            return
        if 0 <= index <= 6 and self.on_board(index, new_ll):
            self._land_locations[index] = new_ll

    def place_character(self, c: Character) -> None:
        """Record that character <c> is on this board.

        Note: This method should only be called from Character.__init__.

        IMPORTANT:
        The decisions you made about new private attributes for class GameBoard
        will determine what you do here.

        Preconditions:
        - c.board == self
        - self.on_board(c.x, c.y)
        - Character <c> has not already been placed on this board.
        - The tile (c.x, c.y) does not already contain a character.

        Note: The testing will depend on this method to set up the board,
        as the Character.__init__ method calls this method.

        >>> b = GameBoard(3, 2)
        >>> r = Raccoon(b, 1, 1)  # when a Raccoon is created, it is placed on b
        >>> b.at(1, 1)[0] == r  # requires GameBoard.at be implemented to work
        True
        """
        self._board[c.y][c.x].append(c)

    def remove_character(self, x: int, y: int) -> None:
        """Remove character on position <x>, <y> from this board.
        If there is no character then nothing happens.

        Preconditions:
        - self.on_board(x, y)
        """
        c = self._board[y][x]
        if c:
            c.pop(0)


    def update_pos(self, x: int, y: int, c: Character) -> None:
        """Update the position of Character <c> on the gameboard to
        tile (x,y).

        Preconditions:
        - c.board == self
        - c in self.at(c.x, c.y)
        - The tile (x, y) is empty.

        >>> b = GameBoard(3, 2)
        >>> r = RecyclingBin(b, 1, 1)
        >>> b.update_pos(2, 1, r)
        >>> b.at(1, 1) == []
        True
        >>> b.at(2, 1)[0] == r
        True
        """
        if len(self._board[c.y][c.x]) == 1 and self._board[c.y][c.x][0] == c:
            self._board[c.y][c.x].remove(c)
            self._board[y][x].append(c)
            c.x = x
            c.y = y

    def at(self, x: int, y: int) -> list[Character]:
        """Return the characters at tile (x, y).

        If there are no characters or if the (x, y) coordinates are not
        on the board, return an empty list.

        Note: The testing will depend on this method to allow us to
        access the Characters on your board, since we don't know how
        you have chosen to store them in your private attributes,
        so make sure this method is working properly!

        >>> b = GameBoard(3, 2)
        >>> r = Raccoon(b, 1, 1)
        >>> b.at(1, 1)[0] == r
        True
        >>> p = Player(b, 0, 1)
        >>> b.at(0, 1)[0] == p
        True
        """
        x = self._board[y][x][:]
        return x

    def to_grid(self) -> list[list[str]]:
        """
        Return the game state as a list of lists of letters where:

        'R': RED_ICON
        'O': ORANGE_ICON
        'G': GREEN_ICON
        'B': BLUE_ICON
        'P': PURPLE_ICON
        'D': DARK_ICON
        '-' = Empty tile

        Each inner list represents one row of the game board.

        >>> b = GameBoard(3, 2)
        >>> _ = Player(b, 0, 0)
        >>> _ = Raccoon(b, 1, 1)
        >>> _ = GarbageCan(b, 2, 1, True)
        >>> b.to_grid()
        [['P', '-', '-'], ['-', 'R', 'C']]
        """
        new_list = []
        for row in self._board:
            row_list = []
            for tile in row:
                if not tile:
                    row_list.append('-')
                else:
                    row_list.append(tile[0].get_symbol())
            new_list.append(row_list)
        return new_list

    # a helper method you may find useful in places
    def on_board(self, x: int, y: int) -> bool:
        """Return True iff the position x, y is within the boundaries of this
        board (based on its width and height), and False otherwise.
        """
        return 0 <= x <= self.width - 1 and 0 <= y <= self.height - 1

    def give_turns(self) -> None:
        """Give every turn-taking character one turn in the game.

        The Player should take their turn and the number of turns
        should be incremented by one.

        After all turns are taken, check_game_ended should be called to
        determine if the game is over.

        Precondition:
        self._player is not None
        """
        turn = self._player.take_turn()
        if turn:
            self.turns += 1  # PROVIDED, DO NOT CHANGE
            self.check_game_ended()  # PROVIDED, DO NOT CHANGE

    def handle_event(self, event: str) -> None:
        """Handle a user-input event.

        The board's Player records the event that happened, so that when the
        Player gets a turn, it can make the move that the user input indicated.

        Preconditions:
        - event in wasdq
        """
        self._player.record_event(event)

    def check_game_ended(self) -> None:
        """Check if this game has ended. A game ends when all the raccoons on
        this game board are either inside a can or trapped.

        If the game has ended:
        - update the ended attribute to be True

        If the game has not ended:
        - update the ended attribute to be False

        >>> b = GameBoard(3, 2)
        >>> _ = Raccoon(b, 1, 0)
        >>> _ = Player(b, 0, 0)
        >>> _ = RecyclingBin(b, 1, 1)
        >>> b.check_game_ended() is None
        True
        >>> b.ended
        False
        >>> _ = RecyclingBin(b, 2, 0)
        >>> b.check_game_ended()
        11
        >>> b.ended
        True
        """
        if self._player.landed:
            length_1 = len(self._board[1][1])
            length_2 = len(self._board[2][1])
            length_3 = len(self._board[3][1])
            if length_1 == 1 or length_2 == 1 or length_3 == 1:
                self.ended = True
        return None


class Character:
    """A character that has (x,y) coordinates and is associated with a given
    board.

    This class is abstract and should not be directly instantiated.

    NOTE: To reduce the amount of documentation in subclasses, we have chosen
    not to repeat information about the public attributes in each subclass.
    Remember that the attributes are not inherited, but only exist once we call
    the __init__ of the parent class.

    Attributes:
    - board: the game board that this Character is on
    - x: the x-coordinate of this Character on the board
    - y: the y-coordinate of this Character on the board

    Representation Invariants:
    - self.board.on_board(x, y)
    - self is on self.board
    """
    board: GameBoard
    x: int
    y: int

    def __init__(self, board: GameBoard, x: int, y: int) -> None:
        """Initialize this Character on the given <board>, and
        at tile (<x>, <y>).

        When a Character is initialized, it is placed on <board>
        by calling the board's place_character method.

        Preconditions:
        - board.on_board(x, y)
        - The tile (x, y) of <board> does not already contain a character.
        """
        self.board = board
        self.x, self.y = x, y
        self.board.place_character(self)  # this associates self with the board!

    def move(self, direction: tuple[int, int]) -> bool:
        """
        If possible, move this character to the tile:

        (self.x + direction[0], self.y + direction[1]).

        Note: Each child class defines its own version of what is possible.

        Return True if the move was successful and False otherwise.
        """
        raise NotImplementedError

    def get_symbol(self) -> str:
        """
        Return a single letter representing this Character.
        """
        raise NotImplementedError


class Player:
    """The Player of this game.

    Attributes:
    - _last_event: The direction corresponding to the last keypress event that
    the user made, or None if there is currently no keypress event to process.
    - _col_hitbox: The index on the board where the bottom square of the column.
    - landed: if player landed the column
    - _to_update: list of locations to update
    - _to_check: for recursive call to _find_connections()
    """

    board: GameBoard
    col : tuple[Character, Character, Character] # bottom to top
    next_col : tuple[Character, Character, Character] # bottom to top
    landed: bool
    _last_event: str | None
    _col_hitbox: tuple[int, int]
    _to_update: list[tuple[int, int]]
    _to_check: list[tuple[int, int]]

    def __init__(self, b: GameBoard) -> None:
        """Initialize this Player with board <b>.
        """

        self.board = b
        self.landed = False
        self._last_event = None
        self._col_hitbox = (1,3) # y: 4th row (3), x: 2nd index (1)
        self._to_update = []
        self._to_check = []
        self.get_next_col()
        self.start_turn()

    def get_next_col(self) -> None:
        """Random generate new 3x1 column and store in self.col"""
        i = 0
        characters = []
        while i < 3:
            n = random.choice(['R', 'O', 'G', 'B', 'P', 'D'])
            c = character_factory(n, self.board, 8, 3 - i)
            characters.append(c)
            i += 1
        self.next_col = tuple(characters)

    def start_turn(self) -> None:
        """Prepare to start the turn by moving the next column to the current
        column position and generating a new next column."""
        self.col = self.next_col
        for c in self.next_col:
            self.board.update_pos(1, c.y, c)
        self.get_next_col()
        self._col_hitbox = (1, 3)

    def record_event(self, event: str) -> None:
        """Record that <event> is the last key press that the user
        has specified for this Player to move. Next time take_turn is called,
        this will be used.
        Preconditions:
        - event is wasd
        """
        self._last_event = event

    def take_turn(self) -> bool:
        """Take a turn in the game.

        For a Player, this means responding to the last user input recorded
        by a call to record_event.
        """
        if self.landed:
            self.start_turn()
        self.landed = False

        if self._to_update:
            self._update_game()
            return self.landed

        if self._to_check:
            self._find_connection(self._to_check)
            return self.landed

        if self._last_event == "gravity" and not self.landed:
            success = self.move(DOWN)
            if not success:
                self.land()
            self._last_event = None

        if self._last_event == "w":
            self.shuffle()
            self._last_event = None

        if self._last_event == "a":
            self.move(LEFT)
            self._last_event = None

        if self._last_event == "d":
            self.move(RIGHT)
            self._last_event = None

        if self._last_event == "s":
            self.land()
            self._last_event = None

        if self._last_event == "q":
            self.board.ended = True
            self._last_event = None

        return self.landed

    def move(self, direction: tuple[int, int]) -> bool:
        x = self._col_hitbox[0]
        y = self._col_hitbox[1]
        new_x = x + direction[0]
        new_y = y + direction[1]
        if self.board.on_board(new_x, new_y):
            tile = self.board.at(new_x, new_y)
        else:
            return False
        if not tile:
            self.board.update_pos(new_x, new_y, self.col[0])
            self._col_hitbox = (new_x, new_y)
            new_y = new_y - 1
            self.board.update_pos(new_x, new_y, self.col[1])
            new_y = new_y - 1
            self.board.update_pos(new_x, new_y, self.col[2])
            return True
        else:
            return False

    def shuffle(self) -> None:
        column = list(self.col[:])
        ref = [(0, 0), (0, 0), (0, 0)]
        for i in range(len(self.col)):
            c = self.col[i]
            self.board.remove_character(c.x, c.y)
            ref[i] = (c.x, c.y)
        for i in range(len(self.col)):
            c = self.col[i]
            if i == 2:
                c.x, c.y = ref[0]
                column[0] = c
                self.board.place_character(c)
            else:
                c.x, c.y = ref[i+1]
                column[i+1] = c
                self.board.place_character(c)
        self.col = tuple(column)

    def land(self) -> None:
        x = self._col_hitbox[0]
        new_y = self.board.get_land_location(x-1) # account for list index
        if not (self.board.on_board(x, new_y)):
            return
        if new_y < self._col_hitbox[1]:
            return
        if (self.board.at(x, new_y) and not
        self.col[0] == self.board.at(x, new_y)[0]):
            return
        if (self.board.on_board(x, new_y-1) and
                self.board.on_board(x, new_y-2)):
            self.board.update_pos(x, new_y, self.col[0])
            self.board.update_pos(x, new_y-1, self.col[1])
            self.board.update_pos(x, new_y-2, self.col[2])
            self.board.update_land_location(x-1, new_y-3)
            locations = [(self.col[0].x, self.col[0].y),
                         (self.col[1].x, self.col[1].y),
                         (self.col[2].x, self.col[2].y)]
            self._find_connection(locations)

    def _find_connection(self, targets: list[tuple[int, int]]) -> list[int]:
        connections = []
        for root_x, root_y in targets:
            character = self.board.at(root_x, root_y)
            if not character:
                continue
            root_color = character[0].get_symbol()
            for i in range(4):
                connection = []
                i = 2 * i
                d1 = DIRECTIONS[i]
                d2 = DIRECTIONS[i + 1]
                self._flood_fill(root_x, root_y, root_color, connection, d1)
                self._flood_fill(root_x, root_y, root_color, connection, d2)
                if len(connection) >= 3:
                    for xy in connection:
                        if xy not in connections:
                            connections.append(xy)
        locations = []
        update = []
        connections.sort() # lowest to highest numbers
        for xy in connections:
            x = xy % 128
            y = (xy - x) // 128
            locations.append((x, y))
            update.append((x, y))
            self.board.remove_character(x, y)
            character_factory('L', self.board, x, y)
            y += -1
            c = self.board.at(x, y)
            while y != 1 and c:
                locations.append((x, y))
                update.append((x, y))
                y += -1
                c = self.board.at(x, y)
            current_ll = self.board.get_land_location(x-1)
            self.board.update_land_location(x-1, current_ll + 1)
        self._to_check = locations
        self._to_update = update
        if not locations:
            self.landed = True
            self.board.animate = False
        else:
            self.board.animate = True
        return connections

    def _update_game(self) -> None:
        """Paints black the x, y from _to_update and moves the block above down
        to its place."""
        x, y = self._to_update.pop(0)
        self.board.remove_character(x, y)
        y += -1
        c = self.board.at(x, y)
        if c:
            self.board.update_pos(x, y+1, c[0])


    def _flood_fill(self, x: int, y: int, color: str,
                   connection: list[int], direction: tuple[int, int]) -> None:
        xy = (y * 128) + x
        if xy not in connection:
            connection.append(xy)
        new_x = x + direction[0]
        new_y = y + direction[1]
        new_color = ""
        c = self.board.at(new_x, new_y)
        if c:
            new_color = c[0].get_symbol()
        if new_color == color:
            self._flood_fill(new_x, new_y, new_color,
                             connection, direction)


class Red(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "R"


class Orange(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "O"


class Green(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "G"


class Blue(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "B"


class Purple(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "P"


class Dark(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "D"


class Light(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "L"


class Boundary(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "Z"


class White(Character):
    def move(self, direction: tuple[int, int]) -> bool:
        return False

    def get_symbol(self) -> str:
        return "W"


def character_factory(symbol: str, b: GameBoard, x: int, y: int) -> Character:
    if symbol == "R":
        return Red(b, x, y)
    elif symbol == "O":
        return Orange(b, x, y)
    elif symbol == "G":
        return Green(b, x, y)
    elif symbol == "B":
        return Blue(b, x, y)
    elif symbol == "P":
        return Purple(b, x, y)
    elif symbol == "D":
        return Dark(b, x, y)
    elif symbol == "L":
        return Light(b, x, y)
    elif symbol == "Z":
        return Boundary(b, x, y)
    elif symbol == "W":
        return White(b, x, y)
    else:
        return Character(b, x, y)
