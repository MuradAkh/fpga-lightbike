![Logo][logo]
# Light Bikes on FPGA

Light bikes on FPGA is a locally-multiplayer game, inspired by the popular movie [Tron][tron]. It involves up to 3 players, each with their own uniquely-coloured bike on a game board. Much like the game Snake, any player who touches the boundaries or any trail left behind by the players will immediately die. Rounds are counted up in the end to determine the winner of the game, and the last person standing will win each round.

## Our Milestones
### Week 1.

This week of our project will implement the following features:
* Set up basic data-structures within a dual-port ram module for the game board, which involves an ```80x60``` grid of ```2 bit words```. Each of the words will represent the current state of the cell, ```ie. Empty or occupied by player 0, 1, or 2```.
* Set up data-structures within our datapath to represent the players' current ```position```, ```direction```, ```turning```, and ```death state```.
* Implement a game clock to handle ```i/o``` from the keyboard, move the players based on their ```direction```, simultaneously.
* Implement a ```keyboard driver``` to make use of a synchronous reset, and a lookup table to check which ```key code``` was ```made``` during the previous clock cycle.
* Use the port ```a``` of the ram module to handle game-logic (player claiming the cell as their own. However, logic for detecting collision will not be in this milestone).
* Use the port ```b``` of the ram module to repeatedly read from ram, and draw the states of the board to the screen.

The main use of this week will be to set up the basic infrastructure to be able to quickly implement features in the future. Even though some code will be unused in this milestone, it makes sense to implement now, while we can make concrete decisions about design choices.

### Week 2.
This week will be focused on implementing core-functionality of the game. Features such as collision and quality-of-life upgrades will be the work needed to be done this week.

Features such as the following:
* Any bugs discovered in Week 1
   * Fix: rendering issues where we get a off-by-one error. Perhaps let the read time run for a few clock cycles more?
   * Fix: about 25% chance of compiling to a version where the player dies upon each keystroke. Perhaps the same issue as above)
   * Fix: the ```DISP_CYCLE``` is not running for the intended amount of time? (32 game ticks)
   * Fix: FSM issues regarding the read-write cycle of game logic. Probably because it gets triggered before the game-clock ticks.
   * Fix: Bug where colours will be mixed up while rendering. Off-by-one issue.
   * Fix: Players interleaving when they land on the same block during the same clock cycle. (It's a feature, not a bug. I promise)
* Implement collision between players.
* Refactoring of the code. (Separate FSM and Datapath)
* Upon death, the player's trail should no longer occupy the board (use port ```b``` for this functionality, as it is controlled by the drawing loop, which runs on 50Mhz. Thus, we can use it to ensure the player's trail is no longer on the board when on the next ```game tick```.)

At this point, most of the core-functionality of the game should be finished. Other things such as main menu, player selection, extending to more player etc, will be handled in Week 3.

### Week 3.
We will use this week to polish up the game, adding additional quality-of-life improvements, as well as fix any previous bugs we have encountered:
* Any bugs discovered in Week 2
   * When the draw loop clears the board, sometimes we get visual artifacting. (Perhaps we are counting by two each loop?)
* Implement a score counter, output to hex
* Implement power-ups such as ```jumping``` to avoid other players' trails
* Implement ability to select colours without recompiling
* Let the players choose how many players will play (during runtime)
* Implement a pause? (unsure about this one, will do if we have time. Worst comes to worst, just halt the ```game clock``` when pause is clicked.)
* Fading the screen between transitions (although we only have ```2-bit``` colour channels, not sure how this would look in the end)

After this week, the game will be done!

## Concept Art


[logo]: ./assets/logo.png
[tron]: https://en.wikipedia.org/wiki/Tron
