---
sidebar_position: 1
---

# Viewmodel Structure

An Igneous Viewmodel must contain 2 items to function properly:

1. A Primary Part
   - The viewmodel must be a Model instance
   - The primary part is where the viewmodel will bind to the camera
2. An Animator
   - Igneous animates your viewmodels using [Motus](https://redcliffstudios.github.io/Motus)