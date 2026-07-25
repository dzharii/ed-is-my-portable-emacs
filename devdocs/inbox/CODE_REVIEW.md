# Code review

---

A00 Scope

---

The review covered the original archive structure, launcher and setup files, the portable installer, shared safety functions, `.gitignore`, the Emacs entry files, the literate configuration, and the Windows test utilities.

---

B00 Findings and disposition

---

| Severity | Finding | Disposition |
| --- | --- | --- |
| High | The original archive placed `ed.ps1` and `emacs-init` files in one directory, while `ed.ps1` required a child `emacs-init` directory. A fresh checkout could not satisfy its own expected layout. | Fixed by moving the launcher to the repository root and the configuration into `emacs-init/`. |
| High | The original installer printed a PATH command based on `Environment.GetEnvironmentVariable('Path','User')` followed by `SetEnvironmentVariable`. Expandable registry strings can be returned in expanded form and then written back as concrete paths. | Removed. The new implementation reads `HKCU\Environment\Path` with `DoNotExpandEnvironmentNames`, preserves the registry value kind, and asks permission before writing. |
| High | The original installer trusted any single ZIP next to the script and did not verify origin or integrity. | Fixed with official GNU mirror choices, fallback, and GNU SHA-256 verification. |
| Medium | The original installer refused to install portable Emacs whenever any Emacs existed on PATH. Portable installations should be able to coexist. | Fixed. The local runtime is preferred without blocking an existing system installation. |
| Medium | Extraction occurred directly into the final directory. A failed extraction could leave a partial runtime. | Fixed with staging, executable validation, and move-after-validation. |
| Medium | `Install-PortableEmacs.cmd` required `pwsh` and used `ExecutionPolicy Unrestricted`. | Fixed. Both command wrappers prefer PowerShell 7, fall back to Windows PowerShell 5.1, use `NoProfile`, and use process-scoped `Bypass`. |
| Medium | The startup Eshell test inspected every live buffer for a visited file and referenced `ed-start-dir`, which the launcher never set. Package or startup buffers could suppress the intended Eshell. | Fixed. The launcher sets explicit Lisp variables through `--eval`; the startup hook uses those variables. |
| Medium | `init.el` loaded the Org file on every startup even though a generated Lisp file was committed. It also contained Custom output after the end marker. | Fixed. Normal startup loads `init-config.el`; Org remains the source and reload path. Custom writes to the local cache. |
| Medium | Package archive refresh errors were swallowed by `ignore-errors`, causing later package failures with less context. | Fixed by displaying a warning with the original error. |
| Low | The configuration used `seq-some`, `define-generic-mode`, and the Customize group `ed` without explicit setup. | Fixed with `require 'seq`, `require 'generic-x`, and `defgroup ed`. |
| Low | `ed-insert-file-name` inserted the full path despite its name and documentation. | Fixed to insert only the final file name. |
| Low | `.gitignore` did not cover the future portable runtime, downloads, native `.eln` output, Custom file, or common Windows metadata. | Fixed with repository-root rules and retained placeholders. |
| Low | Save-place, savehist, recentf, Eshell, project, bookmark, TRAMP, URL, and Org ID state could be written below `emacs-init/`. | Fixed by redirecting those files to `%LOCALAPPDATA%\emacs-ed`. |
| Low | Broad process-name termination during tests could kill unrelated Emacs sessions. | Replaced in the validation workflow with executable-path and verified-PID filtering. Window input also refuses to proceed unless the selected PID owns the foreground window. |

---

C00 Remaining risks

---

The installer validates SHA-256 using the checksum file served by the selected mirror. This is strong protection against accidental corruption, but a compromised mirror serving both files could defeat it. Detached GNU signature verification with a pinned trusted key would address that stronger threat model.

The package configuration installs unpinned current package versions from GNU ELPA, NonGNU ELPA, and MELPA. This is convenient but not reproducible. A future reproducibility pass should commit a package lock manifest or use a package manager with lock-file support.

The PowerShell files were parsed under PowerShell 7, the PATH logic passed isolated-registry tests, and the tangled Lisp loaded successfully in GNU Emacs 30.2. The clean install, clean package profile, path-with-spaces launcher, Unicode display, Eshell working directory, terminal toggle, window state, mouse click, keyboard input, save, and screenshot flows were exercised on Windows. See `VALIDATION.md`.

---

D00 Recommended release regression

---

Repeat the scenarios in `VALIDATION.md` in a disposable Windows account or CI runner for future launcher, installer, package-list, or Emacs-version changes. Persistent PATH acceptance should remain an explicit manual step; automated tests should continue using isolated temporary registry keys.
