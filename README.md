# btow

> A declarative dotfile and home-profile manager inspired by GNU Stow.

btow is a lightweight tool for managing dotfiles across your entire `$HOME` directory using profiles.

It is inspired by [GNU Stow](https://www.gnu.org/software/stow/), but instead of mirroring directory structures, btow works at the file level.

You define which files should exist in your home directory, and btow applies them as a profile.

---

## Difference from GNU Stow

Stow is directory-based and typically operates on structured dotfile repositories.

btow is path-based and works directly across arbitrary locations in `$HOME`.

This allows a single profile to manage scattered configuration like:

- `~/.bashrc`
- `~/.config/nvim/init.lua`
- `~/scripts/tools.sh`

---

## Usage

```bash
btow create work
btow load work
btow list
btow remove work
````

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Bilal1545/btow/main/install.sh | bash
```

---

## License

Apache 2.0
