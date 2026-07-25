# Fonts for Unicode and emoji on Windows Emacs

---

A00 Included behavior

---

No font binaries are included in this repository. The Emacs configuration uses the first installed family from its preferred monospaced-font list for ordinary text. It checks for `Segoe UI Symbol` and `Segoe UI Emoji` before adding them as fontset fallbacks; a missing family is skipped.

With those Windows fonts present, this is sufficient for ordinary Unicode text, symbols, and standard emoji such as the battery emoji in `unicode-test.txt`. Color rendering depends on the Windows Emacs rendering path and should not be assumed; correct glyph coverage is the primary target.

---

B00 Preferred text fonts

---

| Priority | Font | Reason |
| --- | --- | --- |
| 1 | Cascadia Mono | Microsoft monospaced font designed for terminal and developer use. |
| 2 | Cascadia Code | Similar metrics with programming ligatures. |
| 3 | JetBrains Mono | Broad developer-focused glyph coverage. |
| 4 | Consolas | Common Windows fallback. |
| 5 | Fira Code | Developer font with ligatures. |

The configuration selects the first installed family from that order.

---

C00 Private-use icons

---

Nerd Fonts and Powerline variants provide many battery, branch, and status icons through the Unicode Private Use Area. Those code points are not interoperable unless the same patched font is installed everywhere. Prefer standard Unicode or plain text in files. Use a patched font only for UI elements such as the mode line.

Microsoft's Cascadia repository provides `Cascadia Code PL`, which includes Powerline symbols. Nerd Fonts also publishes patched Cascadia variants. Either can be an optional user choice, but neither should silently replace the default font.

---

D00 Suggested future automatic installer

---

A separate `install-fonts.ps1` should present explicit choices, ask before downloading, use versioned publisher release URLs, verify a publisher-provided checksum when available, and install only for the current user. It should not commit font binaries to Git and should not assume that a package manager is present.

This was left as a documented next step because a reliable implementation needs a pinned release and verification policy for every selected font source. The current Windows fallback configuration works without that additional installer.

---

E00 References

---

https://learn.microsoft.com/en-us/typography/font-list/segoe-ui-emoji

https://learn.microsoft.com/en-us/typography/font-list/segoe-ui-symbol

https://github.com/microsoft/cascadia-code
