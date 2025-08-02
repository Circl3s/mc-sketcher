# MC Sketcher
A Minecraft datapack all about custom paintings (and more).

## What is this?
This is a PowerShell script that generates a datapack and a resourcepack which, when used together, allow you to add an arbitrary number of custom paintings to Minecraft.

## What does it do?
- **Add your favourite images to Minecraft!** This script will automatically detect optimal painting size for your images, crop and scale them accordingly, and generate a datapack that registers them as new painting variants.
- **Choose your quality!** The script generates three resourcepacks with different resolutions: x16, x32, and "HD" (x256). You can also choose if you want your downscaled images to be pixelated (default) or smooth. Once the datapack is loaded you can freely choose and switch between these options.
- **Pick painting variants instead of choosing randomly!** By putting a painting into the stonecutter, you can choose a specific variant to place (including vanilla ones). You can revert a specific painting back to the default random one by putting it in the crafting grid.
- **See painting variants at a glance!** Specific paintings will display their art while in your inventory (including vanilla ones - optional).

## What do I need to get started?
- PowerShell
- ffmpeg
- 7zip

You need **ffmpeg** to mess with images, **7zip** to compress the final packs (I'm trying to do it with `Compress-Archive`, but uhh... it's not working), **PowerShell** to actually run the script, and of course some **images** you like.

## How do I use this?
1. First, prepare a folder to put your images in. By default the script will look for a folder named `images` alongside it.
2. Label your images. If you want your variants to be nicely labeled like tha vanilla ones, your images need to follow this convention:
   ```
   <Author> - <Title>[ - <X>x<Y>].<extension>
   ```
   Author and title are simple - those will appear when hovered over the variant. You can also optionally specify a custom size for your painting. The script prefers smallest possible paintings, by default capping its estimations at 4x4 blocks (biggest vanilla painting), but custom variants can be as big as 16x16 blocks!

   Some examples of valid filenames:
   ```
   Leonardo da Vinci - Mona Lisa.jpg
   M.C. Escher - Relativity - 3x3.png
   Unknown - Some Long Meme - 1x8.jpg
   ```
3. Run the script.
   ```
   PS> ./generate.ps1
   ```
   For the most basic usage that's all you need to do, but the script has some options:
   - `-Path <path>`: Specify a custom image folder.
   - `-Smooth`: Enables bicubic filtering, making the lowres paintings smoother.
   - `-VanillaThumbnails`: Enables inventory previews for vanilla paintings. Note that this option uses default vanilla paintings, so they will be incorrect if you're using another resourcepack that changes the default paintings. This option may change in the future.
4. Install the packs. The `build` folder should be populated by 4 .zip files: one datapack and three resourcepacks. Put the datapack in your `.minecraft/saves/<world>/datapacks` folder, and resourcepacks in your `.minecraft/resourcepacks` folder and enable the one you like in settings.

## What does it not do? (TO-DO)
- [x] Generate paintings
- [x] Add variant crafting
- [x] Add variant item textures
- [ ] Support animations
- [ ] Generate vanilla-esque picture frames around images
- [ ] Destroyed paintings drop the correct variant
- [ ] Branding
