![igneousmain](Assets/logo/igneous.png)

<div align="center">
	<h1>Igneous Engine</h1>
	<p>Easy FPS framework for use in Redcliff Studios games that supports modpacks for further customization</p>
</div>

# Setting up Igneous Engine

 ## Adding the main module
> Insert the [main module](Source/Igneous.luau) somewhere the client can access for example in `ReplicatedStorage`
> Require it inside the script you will use to control your weapons
>
> ```lua
> local Igneous = require(game.ReplicatedStorage.Igneous)
>```

## Adding Modpacks
> Inside `ReplicatedStorage` ensure you have a folder named **"IgneousModpacks"**
> That folder will store all of your modpacks.
> Heres an example of what it should look like:
>
> ```js
>ReplicatedStorage
>└── IgneousModpacks
>    └── Modpack
>        ├── Main.luau
>        ├── Server.server.luau
>        ├── Resources
>        └── Events
> ```
>
> All modpacks will automatically be managed by the main module once it has been required

# Creating modpacks

TODO - Modpack template, Make sure Server scripts have runcontext set to Server