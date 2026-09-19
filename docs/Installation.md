---
sidebar_position: 2
---

# Installation

### Method 1 - Package Manager (Wally)

Using Wally, just add `Igneous = "notkaif/igneous@4.0.0"` to your wally.toml
Then run

```sh
 wally install
```

 in the command line!

Igneous pulls in [Trove](https://github.com/Sleitnick/RbxUtil), [Motus](https://redcliffstudios.github.io/Motus) and [Spring](https://sleitnick.github.io/RbxUtil/api/Spring) itself, so you don't need to add those separately. Spring is what the bundled Recoil modpack runs on.

- Need the exported Luau types?
- Using `wally-package-types` run

```sh
wally-package-types --sourcemap sourcemap.json Packages/
```

### Method 2 - Manual

1. Visit the [latest release](https://github.com/RedcliffStudios/Igneous/releases/latest)
2. Under *Assets*, find the .rbxm file and import it into Studio
    - Note: This does not automatically update

## Setting up modpacks

**Igneous does very little on its own.** The core gives you a viewmodel bound to the camera, a stat layer, resource pools and `Cast`. Firing, reloading and aiming are modpacks, and without them a weapon has no `SetFiring`, `Reload` or `SetAiming`.

Copy the modpacks you want from [`Modpacks/`](https://github.com/RedcliffStudios/Igneous/tree/master/Modpacks) into a folder named `Modpacks` inside `ReplicatedStorage`:

```
ReplicatedStorage
├── Packages
│   └── Igneous
└── Modpacks
    ├── Firing
    ├── Reloading
    ├── Aiming
    ├── Recoil
    └── BulletHoles
```

Igneous finds that folder anywhere in `ReplicatedStorage` and registers every ModuleScript in it. If the folder hasn't replicated yet it retries once a second for five seconds before warning. Modpacks added later are picked up automatically, and modpacks living elsewhere can be registered by hand:

```lua
Igneous.RegisterModpack(SomeModuleScript)
```

### Load order

Modpacks register one frame after Igneous is first required. The delay is deliberate, so a modpack can `require` Igneous at its top level without a cyclic require. In practice this never matters, since game code requires its modules at startup and creates weapons afterwards. If you create *and fire* a weapon in the same frame as the very first `require(Igneous)`, the extensions won't exist yet.

## A note on where Igneous runs

Igneous is client-only. It reads `Players.LocalPlayer` and drives the camera, so requiring it on the server raises an error immediately rather than failing silently later. Anything authoritative belongs in a modpack that talks to the server. See [Weapon Mods & Recipes](/docs/Runtime).
