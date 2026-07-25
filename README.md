# ed portable Emacs for Windows

---

A00 Purpose

---

This repository keeps the launcher, installer, portable runtime, and Emacs configuration in predictable locations. Clone it on Windows, add the launcher to PATH once, then run `ed` from any directory. If neither a repository runtime nor an Emacs executable on PATH is available, `ed` explains the portable install and asks before downloading anything.

The installer defaults to GNU Emacs 30.2. Another two-part release can be selected with `-Version`, for example `install.cmd -Version 30.1`.

---

B00 Repository layout

---

| Path | Role |
| --- | --- |
| `ed.cmd` and `ed.ps1` | Launcher kept outside the Emacs init directory. |
| `install.cmd` and `install.ps1` | Verified download, extraction, and optional PATH setup. |
| `add-to-path.cmd` and `add-to-path.ps1` | Standalone, current-user-only PATH setup. |
| `lib/` | Shared runtime discovery and raw-registry PATH safety functions. |
| `emacs-init/` | `early-init.el`, `init.el`, and the literate configuration. |
| `runtime/` | Portable Emacs installations. Ignored by Git. |
| `downloads/` | Downloaded ZIP and checksum files. Ignored by Git. |
| `tools/` | PATH safety tests plus guarded Windows window, click, input, and screenshot utilities. |
| `docs/` | Static website source configured for [ed.awwtools.com](https://ed.awwtools.com/). |
| `devdocs/inbox/` | Review notes, PATH design, font guidance, validation evidence, and next steps. |

---

C00 Quick start

---

From the cloned repository:

```bat
add-to-path.cmd
```

Approve the current-user PATH change, open a new terminal, go to any project, and run:

```bat
ed
```

If no usable Emacs is available, the first run explains that GNU Emacs 30.2 is needed and asks before downloading. Approval downloads the GNU checksum file and downloads or reuses a matching complete Windows ZIP in `downloads/`, verifies SHA-256, extracts through staging into `runtime/`, and continues directly into Emacs with this repository's configuration.

To keep PATH untouched, run `ed.cmd` from the repository root instead.

---

D00 Explicit install

---

`install.cmd` performs the same verified portable installation without launching Emacs:

```bat
install.cmd
```

The default mirror order is the GNU redirector, the Berkeley mirror, the Waterloo mirror, and the main GNU server. A preferred starting mirror can be selected without losing fallback behavior:

```bat
install.cmd -Mirror Berkeley
install.cmd -Mirror Waterloo
install.cmd -Mirror GNU
```

To replace an existing installation of the same version:

```bat
install.cmd -Force
```

To leave PATH untouched without showing the PATH prompt:

```bat
install.cmd -SkipPathPrompt
```

---

E00 Launch

---

From the repository root:

```bat
ed.cmd
```

From any directory after adding the repository root to PATH:

```bat
ed
```

Open a directory or file:

```bat
ed C:\work\project
ed C:\work\project\README.md
```

The launcher first uses `runtime/current-bin.txt`, then searches `runtime/`, then falls back to an Emacs executable already present on PATH. The approval-driven bootstrap runs only when none of those locations provides Emacs. Declining starts no download, installs nothing, launches nothing, and returns exit code 2.

---

F00 Configuration workflow

---

Normal startup loads `emacs-init/init-config.el` directly. The source is `emacs-init/init-config.org`. After editing the Org file, run `M-x ed-reload-config`; this tangles and reloads the generated Lisp file.

Package, native compilation, backup, auto-save, Custom, and history data are written under `%LOCALAPPDATA%\emacs-ed` rather than into the Git repository. Any missing required ELPA package is installed during startup with bounded retry for transient network failures.

---

G00 Unicode, emoji, and battery display

---

No separate font installation is required on supported Windows systems. The configuration selects the first installed family from Cascadia Mono, Cascadia Code, JetBrains Mono, Consolas, and Fira Code, leaving Emacs' default in place if none is available. It assigns the Windows-provided `Segoe UI Symbol` and `Segoe UI Emoji` families when installed. It also enables Emacs' built-in battery display when Windows exposes a battery status provider.

Open [`devdocs/inbox/unicode-test.txt`](devdocs/inbox/unicode-test.txt) to verify symbols and emoji. Additional font guidance is in [`devdocs/inbox/FONTS.md`](devdocs/inbox/FONTS.md).

---

H00 PATH safety

---

`add-to-path.ps1` and the installer's optional PATH action modify only `HKCU\Environment\Path`. They read the raw registry value with `DoNotExpandEnvironmentNames`, preserve `REG_SZ` versus `REG_EXPAND_SZ`, avoid duplicates (including expanded equivalents), enforce the Windows length limit, verify the exact value after writing, and never touch the system PATH.

Only the stable repository root is added. Version-specific Emacs `bin` directories stay out of PATH, so changing the portable runtime does not require another PATH edit.

---

I00 Security boundaries

---

SHA-256 verification detects corruption and a mismatched archive. It does not provide the same publisher-authentication guarantee as verifying GNU's detached GPG signatures with a trusted signing key. GPG signature verification remains a recommended future enhancement.

The installer never performs a machine-wide installation and never writes the system PATH.
