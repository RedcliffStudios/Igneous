---
sidebar_position: 1
---

# Viewmodel Structure

An Igneous Viewmodel must contain 2 items to function properly:

1. A Primary Part
   - The viewmodel must be a Model instance
   - The primary part is where the viewmodel will bind to the camera
   - Igneous warns if the Model has no PrimaryPart, because it then pivots around its bounding box instead
2. An Animator
   - Igneous animates your viewmodels using [Motus](https://redcliffstudios.github.io/Motus)

## Where it lives

`Igneous.new()` clones the template you hand it, so one template can back any number of weapons and the original is never touched.

While equipped, the clone is parented to `Workspace.CurrentCamera`. That keeps it out of the way of other systems' workspace queries, and it follows the camera if one is swapped out at runtime. Unequipped, it is parked in `ReplicatedStorage`. `Weapon:Destroy()` destroys the clone.

`Weapon:GetIgnored()` always lists the viewmodel and the player's current character, and is rebuilt on every respawn. Resolver modpacks filter against it, so a weapon can never shoot itself or its owner.
