## neovim-config

**This config uses Lazy as package manager**

<details closed>
<summary>Images (Click to expand!)</summary>

![](/assets/sc.png)
![](/assets/sc2.png)
![](/assets/sc4.png)

</details>

### How to use this Neovim Config ?

**Steps :**

1. Install Latest Neovim
2. clone this repository in your .config folder
3. Run `nvim` in your terminal

   For Linux :

   ```
     git clone https://github.com/harshevo/nvim-cconfig.git ~/.config/nvim
   ```

   For Windows :

   If you are using CMD -

   ```
   git clone https://github.com/harshevo/nvim-cconfig.git %USERPROFILE%\AppData\Local\nvim && nvim
   ```

   If you are using pwsh:

   ```
   git clone https:://github.comr/harshevo/nvim-cconfig.git $ENV:USERPROFILE\AppData\Local\nvim && nvim
   ```

   If any of the above path is not working :

   For CMD : %LOCALAPPDATA%\nvim

   ```
   C:\Users\%USERNAME%\AppData\Local\nvim
   ```

   For PowerShell : $ENV:LocalAppData\nvim

   ```
   C:\Users\$ENV:USERNAME\AppData\Local\nvim
   ```

- ColorScheme can be changed in ColorScheme.lua
- Keymaps are in custom/core/keymaps.lua

**Keymaps**

> [!NOTE]
> leader == space

1. File Tree Toggle : leader + e
2. Telescope Find Files : leader + ff
3. Telescope Find with Grep : leader + fg
