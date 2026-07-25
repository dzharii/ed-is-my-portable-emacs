# Recommended next steps

---

A00 Automatic font installation

---

Add a separate `install-fonts.ps1` rather than mixing font changes into the Emacs runtime installer. It should offer Cascadia Mono, Cascadia Code PL, or a selected Nerd Font; ask before downloading; pin a release; verify checksums or a signature; install for the current user; and record exactly what it installed so removal is possible. Keep font binaries out of Git.

---

B00 Stronger release authentication

---

The current installer verifies the archive against GNU's SHA-256 file from the same mirror. The stronger design is to download the detached signature and verify it with GnuPG against a pinned GNU Emacs Windows build key or a documented trusted-key bootstrap procedure. This protects against a mirror that serves a modified archive and a matching modified checksum.

---

C00 Reversible PATH management

---

Add an `uninstall.ps1` command that removes only the exact repository-root launcher entry previously added by this repository. It should use the same raw registry access as the installer, preserve the original registry value type, avoid normalizing unrelated entries, and ask before changing the user PATH. Versioned runtime directories are never added to PATH.

---

D00 Reproducible packages

---

The current Emacs configuration installs the current package versions from GNU ELPA, NonGNU ELPA, and MELPA. Add a package manifest or lock file before using this setup in controlled development environments. The lock should include package versions and archive sources and should have an explicit update command.

---

E00 Windows CI

---

Turn the completed manual scenarios in `VALIDATION.md` into a Windows CI or disposable-VM regression job. Keep persistent PATH acceptance manual; run automated PATH cases against an isolated temporary registry key. Continue filtering any test cleanup by both repository runtime path and PID.
