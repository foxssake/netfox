# Input prediction example

A simple demo game, using netfox's `RollbackSynchronizer` to demonstrate input
prediction.

Players control marbles, that behave somewhat similar to cars - they can change
direction, but gradually, and never on the spot. They can also speed up or slow
down, but only gradually.

This lends them well to input decay - when there's no input available, the game
assumes that the player is slowly letting go of the gas. This is a more
accurate prediction than assuming that the marble stops immediately, thus
resulting in less noticeable glitches with bad network conditions.
