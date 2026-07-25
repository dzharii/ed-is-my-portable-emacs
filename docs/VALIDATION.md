# Windows validation

---

A00 Clean-machine bootstrap

---

Validated on Windows with neither `emacs` nor `runemacs` discoverable and with empty `runtime/` and `downloads/` directories:

- declining the prompt returned exit code 2, downloaded nothing, and launched nothing;
- approving through `ed.cmd` downloaded GNU Emacs 30.2, verified SHA-256 `414D3A1A21147AF257EBD98BDD15976FDCB5ED0563F6DE89F76D4A4B5DAD9C72`, extracted through staging, wrote `runtime/current-bin.txt`, and continued into the local `runemacs.exe`;
- the downloaded executable reported GNU Emacs 30.2;
- a clean `%LOCALAPPDATA%` profile installed all 13 declared packages plus dependencies; a deliberately observed transient GNU ELPA failure succeeded through bounded retry.

---

B00 PATH safety

---

`tools/Test-PathSafety.ps1` passed against isolated temporary HKCU registry keys for:

- byte-for-byte preservation of `%JAVA_HOME%` and `%USERPROFILE%` references;
- preservation of both `REG_EXPAND_SZ` and `REG_SZ`;
- idempotent, case-insensitive, trailing-slash-insensitive duplicate handling;
- recognition of a literal path equivalent to an existing expandable entry;
- no mutation under `-WhatIf`;
- rejection of unsupported registry value types without rewriting them.

The real user PATH was captured before and after both refusal-flow tests. Its type, 2,332-character raw value, and embedded references remained exactly unchanged.

---

C00 Visible user acceptance

---

The included Windows automation tools were used against the repository runtime's verified PID, with foreground-window validation before input:

- opened `work\path with spaces\uat file.txt`;
- restored and maximized the window, clicked inside the editor, typed a sentence, saved with `C-x C-s`, and verified the bytes on disk;
- opened `docs\unicode-test.txt` and visually checked Latin, Greek, Cyrillic, math, symbols, battery, emoji, and CJK glyphs;
- launched bare `ed` from a directory containing spaces and landed in Eshell at that exact directory;
- toggled the dedicated bottom terminal open and closed with `C-c t`;
- captured screenshots after each important state.

Generated profiles, screenshots, archives, and runtimes are intentionally ignored by Git.
