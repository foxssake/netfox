
# Physics

At the time of writing official Godot releases have no support for manually stepping physics simulations. As such if you want to use physics nodes with rollback such as RigidBody you will need to run either a fork that supports stepping or use an alternate physics addon that exposes stepping.


## Known Options

[Building Godot manually](https://docs.godotengine.org/en/stable/contributing/development/compiling/index.html) with the[ stepping PR](https://github.com/godotengine/godot/pull/76462)
[Rapier Physics Addon ](https://godot.rapier.rs/)
[Blazium](https://blazium.app/) Fork


## Enabling Physics Engine Rollback

Depending on your physics engine option enable the relevant physics driver and add the node to your scene tree. ( PhysicsDriver2/3D or RapierPhysicsDriver2/3D )

These Nodes will stop the built in physics process system in Godot and step physics at netfox's network tick rate.

![[physics-enable.png]]

## Configuration Options

Physics Factor - How many steps to break down the physics simulation by. If you are running a network tick rate of 30 but require higher accuracy collision that a physics simulation of 60 can provide you would set this to 2.

Rollback Physics Space - Will rollback all objects in the scene tree. Depending on how complex your scene tree is you may wish to only rollback specific nodes for performance rather than the entire simulation space.


## NetworkRigidBody

RigidBodies can be used with [RollbackSynchronizer] or [StateSynchronizer] using NetworkRigidBody2/3D Nodes. They are a direct drop in replacement and will keep clients in sync with the server's simulation.

The only configuration required is to add `physics_state` as a State Property in the synchronizer.


![[network-rigid-body.png]]