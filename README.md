# btow

> **Stop managing dotfiles. Start managing profiles.**
> btow is a lightweight, declarative dotfile and profile manager for Linux.

btow does one thing extremely well:

**You describe your dotfile profiles. btow makes them exist on your system.**

No magic.
No background daemon.
No new language.

Just files. Just reality aligning to your description.

---

## Why btow exists

Managing dotfiles manually is a nightmare: copying, symlinking, backing up, and syncing across machines.

btow gives you:

* Declarative profiles
* Symlink or copy-based management
* Optional hashing to ensure integrity
* Import/export from files
* Compatibility with existing tools like bix

---

## Concepts

* **Profiles** – Named collections of dotfiles
* **Packages** – Optional per-profile file imports
* **Current** – The profile currently loaded on the system

Profiles can be:

* **Loaded** – Symlinks applied to `$HOME`
* **Installed** – Copied fully to `$HOME`

---

## Usage

```bash
# create a profile interactively
btow create work

# load a profile (symlinks)
btow load work

# install a profile (copy files)
btow install work

# remove a profile
btow remove work

# list all profiles
btow list
```

**Optional import from file:**

```bash
btow import mydotfiles.btow
```

btow will verify file integrity using hashes if available.

---

## Philosophy

* Declarative where it matters
* Imperative where practical
* Portable over clever
* Simple over fancy

btow chooses **practicality over ideology**.

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Bilal1545/btow/main/install.sh | bash
```

Yes, really. That’s it.

---

## License

Apache 2.0 – Take it. Fork it. Ship it.
Just don’t pretend you wrote it.