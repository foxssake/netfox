# Modifying objects during rollback

There are cases where two objects interact and modify each other during
rollback. For example:

* Players shoving another
* An explosion displacing objects around it
* Two cars colliding
* A player shooting at another - if player stats are managed as part of
  rollback

## The problem with naive implementations

The simplest way to implement these mechanics is to just update the affected
object. For example, when one player shoves another, the shove direction can
simply be added to the target player's position. Doing this will not work
unfortunately.

Let's say that Player A is shoving Player B. With Player A being the local
player, we have input for its actions. With Player B being a remote player, it
won't be simulated. So even though its position was modified, this change will
not be recorded, and will be overridden by its last *known* position.

This may partially be fixed by enabling [prediction] for players.

Take another case, where Player B wants to shove Player A. With Player B being
a remote player, we only receive its input a few ticks after the fact. So we
need to resimulate Player B from an earlier tick. In one of these earlier tick,
Player A gets shoved.

Since Player A was already simulated and recorded for this earlier tick, it
being shoved will not be recorded.

In both cases, we need a way to tell netfox that a given object has been
modified ( *mutated* ), and its state history should be updated.

## Using Mutations

As hinted before, using Mutations enables modifying objects during rollback, in
a way that is taken into account by netfox.

When an object is modified during rollback, call `NetworkRollback.mutate()`,
passing said object as an argument.

As a result, the changes made to the object in the current tick will be
recorded. Since its history has changed, it will be resimulated from the point
of change - i.e. for all ticks after the change was made.

Make sure that `mutate()` is only called on objects that need it - otherwise,
ticks will be resimulated for objects that don't need it, resulting in worse
performance.

TODO: Code example

[prediction]: ./predicting-input.md
