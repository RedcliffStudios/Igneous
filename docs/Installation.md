---
sidebar_position: 2
---

# Installation

### Method 1 - Package Manager (Wally)

Using Wally, just add `igneous = "notkaif/igneous@2.0.0"` to your wally.toml
Then run

```sh
 wally install
```

 in the command line!

- Need the exported Luau types?
- Using `wally-package-types` run

```sh
wally-package-types --sourcemap sourcemap.json Packages/
```

### Method 2 - Manual

1. Visit the [latest release](https://github.com/RedcliffStudios/Igneous/releases/latest)
2. Under *Assets*, find the .rbxm file and import it into Studio`
    - Note: This does not automatically update