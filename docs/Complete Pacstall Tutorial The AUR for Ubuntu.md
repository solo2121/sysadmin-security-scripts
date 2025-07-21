
Pacstall is a powerful package manager for Ubuntu and Debian-based systems that brings an Arch-like user repository (AUR) experience. It allows users to install the latest software from source or pre-built packages easily.

---

## **Table of Contents**
1. [What is Pacstall?](#what-is-pacstall)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Searching for Packages](#searching-for-packages)
5. [Installing Packages](#installing-packages)
6. [Removing Packages](#removing-packages)
7. [Updating Packages](#updating-packages)
8. [Creating Custom Pacscripts](#creating-custom-pacscripts)
9. [Troubleshooting](#troubleshooting)
10. [Conclusion](#conclusion)

---

## **1. What is Pacstall?** <a name="what-is-pacstall"></a>
Pacstall is a package manager that:
- Provides an **AUR-like** experience for Ubuntu/Debian.
- Allows installing **bleeding-edge software** from source or pre-built binaries.
- Supports **dependency resolution**.
- Uses **Pacscripts** (similar to PKGBUILDs in Arch Linux).

---

## **2. Installation** <a name="installation"></a>
### **Prerequisites**
- Ubuntu/Debian-based system
- `git`, `curl`, `sudo`, and `build-essential` installed.

### **Install Pacstall**
Run the following command to install Pacstall:
```bash
sudo bash -c "$(curl -fsSL https://pacstall.dev/q/install)"
```
This will:
1. Install dependencies.
2. Clone the Pacstall repository.
3. Set up the necessary directories.

Verify installation:
```bash
pacstall --version
```

---

## **3. Basic Usage** <a name="basic-usage"></a>
Pacstall commands follow a simple structure:
```bash
pacstall [command] [options] [package]
```

Common commands:
| Command | Description |
|---------|-------------|
| `-I, --install` | Install a package |
| `-R, --remove` | Remove a package |
| `-S, --search` | Search for packages |
| `-U, --update` | Update Pacstall and packages |
| `-L, --list` | List installed packages |
| `-Qi, --info` | Show package info |

---

## **4. Searching for Packages** <a name="searching-for-packages"></a>
To search for available packages:
```bash
pacstall -S <package-name>
```
Example:
```bash
pacstall -S neovim
```
This will list matching packages from the Pacstall repository.

---

## **5. Installing Packages** <a name="installing-packages"></a>
### **Install from the Repo**
```bash
pacstall -I <package-name>
```
Example:
```bash
pacstall -I neovim-git
```

### **Install from a Custom Pacscript**
If you have a `.pacscript` file:
```bash
pacstall -I ./custom-package.pacscript
```

### **Install with Additional Options**
Some packages allow customization:
```bash
pacstall -I <package> -D "OPTION=value"
```

---

## **6. Removing Packages** <a name="removing-packages"></a>
To uninstall a package:
```bash
pacstall -R <package-name>
```
Example:
```bash
pacstall -R neovim-git
```

To remove dependencies no longer needed:
```bash
sudo apt autoremove
```

---

## **7. Updating Packages** <a name="updating-packages"></a>
### **Update Pacstall Itself**
```bash
pacstall -U
```

### **Update All Installed Packages**
```bash
pacstall -Up
```

### **Update a Specific Package**
```bash
pacstall -I <package-name> --update
```

---

## **8. Creating Custom Pacscripts** <a name="creating-custom-pacscripts"></a>
Pacscripts define how a package is built. Example (`neovim-git.pacscript`):
```bash
name='neovim-git'
version='nightly'
description='Hyperextensible Vim-based text editor (Git version)'
url='https://github.com/neovim/neovim'

deps=('cmake' 'git' 'ninja-build' 'gettext' 'libtool' 'libuv-dev')

build() {
  git clone --depth 1 https://github.com/neovim/neovim.git
  cd neovim
  make CMAKE_BUILD_TYPE=RelWithDebInfo
  sudo make install
}
```

### **Install a Local Pacscript**
```bash
pacstall -I ./neovim-git.pacscript
```

---

## **9. Troubleshooting** <a name="troubleshooting"></a>
### **Common Issues**
1. **Missing Dependencies**  
   Ensure all `deps` in the Pacscript are installed.

2. **Build Failures**  
   Check logs in `/var/log/pacstall/`.

3. **Permission Errors**  
   Run with `sudo` if needed.

4. **Broken Packages**  
   Reinstall or report issues on [GitHub](https://github.com/pacstall/pacstall).

---

## **10. Conclusion** <a name="conclusion"></a>
Pacstall brings the flexibility of the AUR to Ubuntu/Debian, allowing easy installation of the latest software. With this guide, you can:
- Install, remove, and update packages.
- Search for new software.
- Create custom Pacscripts.

### **Useful Links**
- [Pacstall GitHub](https://github.com/pacstall/pacstall)
- [Pacstall Documentation](https://pacstall.dev/docs)

Happy packaging! 🚀