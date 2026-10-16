# MDTREE (`output.md`)


- $Path = `.`
- $FilterPath = ``
- $FilterName = ``
- $Include = ``
- $ExcludeDirs = ``
- $ExcludeFiles = ``
- $MaxFileSizeKB = `1024`
- $Output = `output.md`


Generated on `2026-10-15 23:25:55`

[TOC]

## File content `add-to-path.ps1`:

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
Safely adds the ed launcher directory to the current user's PATH.

.DESCRIPTION
Reads HKCU\Environment\Path without expanding references such as %JAVA_HOME%,
asks before changing it, preserves its registry type, writes only the repository
root, and verifies the exact raw value after writing.
#>
[CmdletBinding()]
param(
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This PATH helper currently supports Windows only.'
}

. (Join-Path $PSScriptRoot 'lib\Ed.Common.ps1')

function Read-EdConfirmation {
    param([Parameter(Mandatory)][string]$Question)
    $answer = Read-Host "$Question [y/N]"
    return -not [string]::IsNullOrWhiteSpace($answer) -and
        $answer.Trim().ToLowerInvariant() -in @('y', 'yes')
}

$repoRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd([char]92)
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'ed.cmd') -PathType Leaf)) {
    throw "ed.cmd was not found in the repository root: $repoRoot"
}

Write-Host ''
Write-Host 'ed user PATH setup' -ForegroundColor Cyan
Write-Host "  Add: $repoRoot" -ForegroundColor White
Write-Host '  Scope: current user only (HKCU\Environment\Path)' -ForegroundColor Gray
Write-Host '  Existing %VARIABLE% references will remain unexpanded.' -ForegroundColor Gray
Write-Host ''

if (-not $Yes -and -not (Read-EdConfirmation -Question 'Add this launcher directory to your user PATH')) {
    Write-Host 'PATH was not changed.' -ForegroundColor Yellow
    exit 2
}

$result = Add-EdUserPathEntriesPreservingExpansion -Entries @($repoRoot)
if ($result.Changed) {
    try {
        Send-EdEnvironmentChangedMessage
    }
    catch {
        Write-Host "PATH was written and verified, but the environment-change broadcast failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Write-Host 'User PATH updated and verified.' -ForegroundColor Green
}
else {
    Write-Host 'The launcher directory is already present in the user PATH.' -ForegroundColor Green
}
Write-Host 'Open a new terminal, then run: ed' -ForegroundColor Yellow

```

## File content `devdocs\inbox\CODE_REVIEW.md`:

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


## File content `devdocs\inbox\FONTS.md`:

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


## File content `devdocs\inbox\NEXT_STEPS.md`:

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


## File content `devdocs\inbox\PATH.md`:

# PATH update design

---

A00 Problem

---

A user PATH can be stored as `REG_EXPAND_SZ` and contain references such as `%USERPROFILE%` or `%LOCALAPPDATA%`. Reading that registry value through an API that expands variables and writing the expanded text back destroys the original representation, can make the value much longer, and can make later manual editing less practical.

---

B00 Implemented approach

---

`add-to-path.ps1` and `install.ps1` open `HKCU\Environment`, read `Path` with `RegistryValueOptions.DoNotExpandEnvironmentNames`, record the existing `RegistryValueKind`, append only a missing launcher entry, and write the new value using the same kind. When no prior value exists, they use `ExpandString`. The shared function verifies the raw value and type after writing.

The scripts update only the current user's PATH and ask first. They add only the repository root for `ed.cmd`; versioned runtime directories are intentionally excluded.

---

C00 Process behavior

---

Windows processes receive an environment block from their parent. The script broadcasts an environment-change message after writing the registry, but the terminal running the installer cannot retroactively change its parent's environment. Open a new terminal before testing the commands.

---

D00 Manual alternative

---

Decline the prompt and add this entry with the Windows Environment Variables user interface:

```text
<repository root>
```

The exact portable `bin` directory is private launcher state recorded relative to `runtime/` in `runtime/current-bin.txt`.

---

E00 References

---

Microsoft documents `RegistryValueOptions.DoNotExpandEnvironmentNames` as retrieving an expandable registry string without expanding embedded variables:

https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registryvalueoptions

Microsoft documents `RegistryValueKind.ExpandString` as the registry type that contains unexpanded environment-variable references:

https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registryvaluekind


## File content `devdocs\inbox\unicode-test.txt`:

```txt
Unicode display test

Latin: Cafe naive facade
Greek: Î•Î»Î»Î·Î½Î¹ÎºÎ¬
Cyrillic: ÐšÐ¸Ñ€Ð¸Ð»Ð»Ð¸Ñ†Ð°
Math: âˆ‘ âˆ« âˆš â‰  â‰¤ â‰¥
Symbols: âœ“ â˜… âš™ â˜‚
Battery: ðŸ”‹
Emoji: ðŸ˜€ ðŸš€ ðŸ§ª ðŸ› ï¸
CJK: æ—¥æœ¬èªž ä¸­æ–‡ í•œêµ­ì–´

```

## File content `devdocs\inbox\VALIDATION.md`:

# Windows validation

---

A00 Clean-machine bootstrap

---

Validated on Windows with neither `emacs` nor `runemacs` discoverable and with no runtime or download payloads beyond the repository's tracked placeholder files:

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
- opened `devdocs\inbox\unicode-test.txt` and visually checked Latin, Greek, Cyrillic, math, symbols, battery, emoji, and CJK glyphs;
- launched bare `ed` from a directory containing spaces and landed in Eshell at that exact directory;
- toggled the dedicated bottom terminal open and closed with `C-c t`;
- captured screenshots after each important state.

Generated profiles, screenshots, archives, and runtimes are intentionally ignored by Git.


## File content `docs\index.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">

  <title>ed â€” portable Emacs for Windows</title>
  <meta name="description" content="A small, portable Emacs setup for Windows. Keep the launcher and configuration together, then open any folder with ed.">
  <link rel="canonical" href="https://ed.awwtools.com/">

  <meta property="og:type" content="website">
  <meta property="og:site_name" content="ed">
  <meta property="og:title" content="ed â€” portable Emacs for Windows">
  <meta property="og:description" content="Keep the launcher and configuration together, then open any folder with ed.">
  <meta property="og:url" content="https://ed.awwtools.com/">
  <meta property="og:image" content="https://ed.awwtools.com/social-card.jpg">
  <meta property="og:image:secure_url" content="https://ed.awwtools.com/social-card.jpg">
  <meta property="og:image:type" content="image/jpeg">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="ed, portable Emacs for Windows. Your editor, from any folder.">
  <meta property="og:locale" content="en_US">

  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="ed â€” portable Emacs for Windows">
  <meta name="twitter:description" content="Keep the launcher and configuration together, then open any folder with ed.">
  <meta name="twitter:image" content="https://ed.awwtools.com/social-card.jpg">
  <meta name="twitter:image:alt" content="ed, portable Emacs for Windows. Your editor, from any folder.">

  <meta name="theme-color" content="#f2f1ec">
  <meta name="color-scheme" content="light">
  <link rel="icon" type="image/png" href="favicon.png">
  <link rel="apple-touch-icon" href="favicon.png">
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>

  <header class="site-header page-shell">
    <a class="wordmark" href="/" aria-label="ed home">ed</a>
    <nav aria-label="Primary">
      <a href="#install">Install</a>
      <a href="https://github.com/dzharii/ed-is-my-portable-emacs">Source</a>
    </nav>
  </header>

  <main id="main">
    <section class="hero page-shell" aria-labelledby="hero-title">
      <p class="kicker">Portable Emacs for Windows</p>
      <h1 id="hero-title">An editor you can take with you.</h1>
      <p class="lede">
        <strong>ed</strong> keeps an Emacs launcher and a practical configuration
        in one repository. Run it in the folder where you are already working,
        with the same tracked configuration on each Windows machine you use.
      </p>
      <pre class="launch-line" aria-label="Launch ed in the current project"><code><span class="prompt">C:\work\project&gt;</span> ed</code></pre>
      <p class="hero-links">
        <a class="text-link" href="#install">Install ed</a>
        <span aria-hidden="true">Â·</span>
        <a class="text-link" href="https://github.com/dzharii/ed-is-my-portable-emacs">Browse the source</a>
      </p>
    </section>

    <figure class="hero-figure page-shell">
      <img
        src="media/ed-writing-1024.png"
        width="1024"
        height="692"
        fetchpriority="high"
        alt="Emacs displaying a Markdown note with a heading, numbered steps, a quotation, and a checklist in a light theme.">
      <figcaption>
        An ordinary Markdown file on disk, opened with the configuration that
        ships in the repository.
      </figcaption>
    </figure>

    <section class="chapter page-shell" aria-labelledby="why-title">
      <header class="chapter-heading">
        <p class="folio">01 / What it changes</p>
        <h2 id="why-title">Less setup to reconstruct.</h2>
      </header>
      <div class="chapter-body">
        <dl class="reasons">
          <div>
            <dt>The setup stays visible</dt>
            <dd>
              The launcher and Emacs configuration live beside one another.
              Downloaded archives, the portable runtime, packages, and generated
              state stay out of the tracked source.
            </dd>
          </div>
          <div>
            <dt>It opens where you are</dt>
            <dd>
              Run <code>ed</code> in a directory, or pass it a file. A directory
              starts an Emacs shell there; a file opens directly.
            </dd>
          </div>
          <div>
            <dt>It remains Emacs</dt>
            <dd>
              ed adds a light theme, completion, file modes for everyday work,
              Magit, and a toggled terminal pane. Emacs key bindings remain,
              and a language server never starts unless you request it.
            </dd>
          </div>
        </dl>
      </div>
    </section>

    <section class="chapter page-shell" aria-labelledby="work-title">
      <header class="chapter-heading">
        <p class="folio">02 / At work</p>
        <h2 id="work-title">Writing and code share the same room.</h2>
      </header>
      <div class="chapter-body">
        <p class="section-intro">
          Notes, scripts, source, and data files can share one session without
          turning every buffer into an IDE.
        </p>

        <div class="figure-grid">
          <figure>
            <img
              src="media/ed-powershell-884.png"
              width="884"
              height="582"
              loading="lazy"
              decoding="async"
              alt="A PowerShell script open in Emacs with line numbers and syntax highlighting.">
            <figcaption>PowerShell syntax and line numbers.</figcaption>
          </figure>
          <figure>
            <img
              src="media/ed-kql-884.png"
              width="884"
              height="582"
              loading="lazy"
              decoding="async"
              alt="A Kusto Query Language query open in the custom ed KQL mode.">
            <figcaption>
              A small KQL mode highlights comments, keywords, strings, and
              numbers.
            </figcaption>
          </figure>
        </div>

        <p class="language-line">
          Markdown Â· Emacs Lisp Â· C# Â· Scala Â· PowerShell Â· JSON Â· YAML Â· KQL
        </p>

        <figure class="terminal-figure">
          <img
            src="media/ed-terminal-884.png"
            width="884"
            height="582"
            loading="lazy"
            decoding="async"
            alt="The Emacs shell showing the current project directory and the main Git branch.">
          <figcaption>
            With no file argument, ed starts Eshell in the directory from which
            it was launched. The same shell can be toggled below any buffer.
          </figcaption>
        </figure>
      </div>
    </section>

    <section class="chapter install page-shell" id="install" aria-labelledby="install-title">
      <header class="chapter-heading">
        <p class="folio">03 / Try it</p>
        <h2 id="install-title">Clone, add one command, open a folder.</h2>
      </header>
      <div class="chapter-body">
        <p>
          Clone the repository on Windows and run the PATH helper from its root:
        </p>
        <pre class="install-code"><code>git clone https://github.com/dzharii/ed-is-my-portable-emacs.git
cd ed-is-my-portable-emacs
add-to-path.cmd</code></pre>
        <p>
          The helper shows the current-user PATH change and asks before writing
          it. Open a new terminal, move to a project, and run:
        </p>
        <pre class="install-code"><code>ed</code></pre>
        <p>
          If no usable Emacs is available, ed explains the GNU Emacs 30.2
          download and asks before starting it. Declining starts no download
          and installs nothing.
        </p>
        <p class="install-links">
          <a class="source-link" href="https://github.com/dzharii/ed-is-my-portable-emacs">Get the source on GitHub <span aria-hidden="true">â†’</span></a>
          <a href="https://github.com/dzharii/ed-is-my-portable-emacs#ed-portable-emacs-for-windows">Read the installation notes</a>
        </p>
      </div>
    </section>
  </main>

  <footer class="site-footer page-shell">
    <p><strong>ed</strong> is public-domain configuration and tooling around GNU Emacs.</p>
    <p>Windows Â· GNU Emacs 30.2 by default Â· no account</p>
  </footer>
</body>
</html>

```

## File content `docs\style.css`:

```css
:root {
  --paper: #f2f1ec;
  --paper-deep: #e7e5dc;
  --ink: #242424;
  --muted: #62645f;
  --green: #2f684d;
  --green-dark: #194a34;
  --rule: #789181;
  --serif: Georgia, "Palatino Linotype", Palatino, "Book Antiqua", serif;
  --mono: "Cascadia Mono", "SFMono-Regular", Consolas, "Liberation Mono", monospace;
}

*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
}

body {
  margin: 0;
  background: var(--paper);
  color: var(--ink);
  font-family: var(--mono);
  font-size: 1rem;
  line-height: 1.65;
  text-rendering: optimizeLegibility;
}

img {
  display: block;
  max-width: 100%;
  height: auto;
}

a {
  color: var(--green-dark);
  text-decoration-color: var(--rule);
  text-decoration-thickness: 0.08em;
  text-underline-offset: 0.18em;
}

a:hover {
  color: var(--green);
  text-decoration-color: currentColor;
}

a:focus-visible {
  outline: 3px solid var(--green);
  outline-offset: 4px;
}

code,
pre {
  font: inherit;
}

code {
  color: var(--green-dark);
}

.page-shell {
  width: min(70rem, calc(100% - 4rem));
  margin-inline: auto;
}

.skip-link {
  position: fixed;
  z-index: 10;
  top: 0.75rem;
  left: 0.75rem;
  padding: 0.55rem 0.8rem;
  transform: translateY(-180%);
  background: var(--ink);
  color: var(--paper);
}

.skip-link:focus {
  transform: translateY(0);
}

.site-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  min-height: 5.25rem;
  padding-block: 1.6rem 1rem;
  border-bottom: 1px solid var(--ink);
}

.wordmark {
  color: var(--ink);
  font-family: var(--serif);
  font-size: 2.1rem;
  font-weight: 700;
  letter-spacing: -0.06em;
  line-height: 1;
  text-decoration: none;
}

.site-header nav {
  display: flex;
  gap: 1.5rem;
  font-size: 0.9rem;
}

.hero {
  padding-block: clamp(4.5rem, 10vw, 8rem) clamp(4rem, 8vw, 6.5rem);
}

.kicker,
.folio {
  margin: 0 0 1.25rem;
  color: var(--green);
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.09em;
  text-transform: uppercase;
}

.hero h1 {
  max-width: 61rem;
  margin: 0;
  font-family: var(--serif);
  font-size: clamp(3.5rem, 8.2vw, 6.25rem);
  font-weight: 700;
  letter-spacing: -0.055em;
  line-height: 0.95;
}

.lede {
  max-width: 48rem;
  margin: 2.5rem 0 0;
  font-size: clamp(1.05rem, 1.7vw, 1.3rem);
  line-height: 1.65;
}

.lede strong {
  font-family: var(--serif);
  font-size: 1.15em;
}

.launch-line {
  width: fit-content;
  max-width: 100%;
  margin: 2.4rem 0 0;
  padding: 0.75rem 1.1rem;
  overflow-x: auto;
  border-block: 1px solid var(--rule);
  color: var(--ink);
  font-size: 1.05rem;
  white-space: pre;
}

.prompt {
  color: var(--green);
}

.hero-links {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem 0.75rem;
  margin: 1.7rem 0 0;
  font-size: 0.92rem;
}

.text-link {
  font-weight: 700;
}

.hero-figure {
  margin-block: 0 6.5rem;
}

figure {
  margin: 0;
}

figure img {
  width: 100%;
  border: 1px solid var(--green-dark);
  background: #fff;
}

figcaption {
  max-width: 47rem;
  margin-top: 0.75rem;
  color: var(--muted);
  font-size: 0.82rem;
  line-height: 1.5;
}

.chapter {
  display: grid;
  grid-template-columns: minmax(12rem, 17rem) minmax(0, 1fr);
  gap: clamp(2rem, 6vw, 5.5rem);
  padding-block: clamp(4.25rem, 8vw, 7rem);
  border-top: 1px solid var(--ink);
}

.chapter-heading h2 {
  margin: 0;
  font-family: var(--serif);
  font-size: clamp(2rem, 3.8vw, 3.4rem);
  letter-spacing: -0.035em;
  line-height: 1.05;
}

.chapter-body {
  min-width: 0;
  max-width: 48rem;
}

.chapter-body > :first-child {
  margin-top: 0;
}

.chapter-body > :last-child {
  margin-bottom: 0;
}

.section-intro {
  margin-bottom: 3rem;
  font-family: var(--serif);
  font-size: 1.35rem;
  line-height: 1.5;
}

.reasons {
  margin: 0;
}

.reasons > div {
  display: grid;
  grid-template-columns: minmax(10rem, 13rem) minmax(0, 1fr);
  gap: 1.5rem;
  padding-block: 1.6rem;
  border-top: 1px solid var(--rule);
}

.reasons > div:last-child {
  border-bottom: 1px solid var(--rule);
}

.reasons dt {
  font-family: var(--serif);
  font-size: 1.2rem;
  font-weight: 700;
  line-height: 1.25;
}

.reasons dd {
  margin: 0;
}

.figure-grid {
  display: grid;
  gap: 3.25rem;
}

.figure-grid figure,
.terminal-figure {
  max-width: 47rem;
}

.language-line {
  margin: 3rem 0;
  padding-block: 1.2rem;
  border-block: 1px solid var(--rule);
  color: var(--green-dark);
  font-size: 0.85rem;
  font-weight: 700;
  line-height: 1.8;
}

.terminal-figure {
  margin-top: 3.5rem;
}

.install {
  border-bottom: 1px solid var(--ink);
}

.install .chapter-body > p {
  max-width: 43rem;
}

.install-code {
  margin: 1.5rem 0 2rem;
  padding: 1.35rem 1.5rem;
  overflow-x: auto;
  border-left: 4px solid var(--green);
  background: var(--paper-deep);
  color: var(--ink);
  line-height: 1.75;
  white-space: pre;
}

.install-code code {
  color: inherit;
}

.install-links {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.8rem 1.5rem;
  margin-top: 2.5rem;
}

.source-link {
  font-family: var(--serif);
  font-size: 1.25rem;
  font-weight: 700;
}

.site-footer {
  display: flex;
  justify-content: space-between;
  gap: 2rem;
  padding-block: 2.5rem 4rem;
  color: var(--muted);
  font-size: 0.8rem;
}

.site-footer p {
  margin: 0;
}

@media (max-width: 56rem) {
  .page-shell {
    width: min(100% - 2rem, 42rem);
  }

  .site-header {
    min-height: 4.5rem;
    padding-block: 1.25rem 0.9rem;
  }

  .site-header nav {
    gap: 1rem;
  }

  .hero {
    padding-block: 4.5rem 4rem;
  }

  .hero h1 {
    font-size: clamp(3.05rem, 14vw, 4.8rem);
  }

  .lede {
    margin-top: 2rem;
  }

  .hero-figure {
    margin-bottom: 4.5rem;
  }

  .chapter {
    grid-template-columns: 1fr;
    gap: 2.25rem;
    padding-block: 4.5rem;
  }

  .chapter-heading {
    max-width: 28rem;
  }

  .reasons > div {
    grid-template-columns: 1fr;
    gap: 0.65rem;
  }

  .section-intro {
    margin-bottom: 2.5rem;
    font-size: 1.2rem;
  }

  .figure-grid {
    gap: 2.5rem;
  }

  .site-footer {
    flex-direction: column;
    gap: 0.5rem;
    padding-bottom: 2.5rem;
  }
}

@media (max-width: 25rem) {
  body {
    font-size: 0.95rem;
  }

  .site-header nav {
    font-size: 0.82rem;
  }

  .hero h1 {
    font-size: 2.8rem;
  }

  .launch-line {
    font-size: 0.9rem;
  }

  .install-code {
    margin-inline: -1rem;
    padding-inline: 1rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  html {
    scroll-behavior: auto;
  }
}

```

## File content `ed.ps1`:

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
Launches the repository's portable Emacs configuration.

.DESCRIPTION
Opens Emacs in the current directory or in the directory represented by the
optional path. The launcher prefers the repository's portable runtime. On a
first run it clearly offers to download and install Emacs; no download starts
until the user approves it.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This launcher currently supports Windows only.'
}

. (Join-Path $PSScriptRoot 'lib\Ed.Common.ps1')

function Stop-WithError {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string[]]$Details
    )

    Write-Host ''
    Write-Host "ERROR: $Title" -ForegroundColor Red
    foreach ($detail in $Details) {
        Write-Host "  $detail" -ForegroundColor Red
    }
    Write-Host ''
    exit 1
}

function ConvertTo-ElispString {
    param([Parameter(Mandatory)][string]$Value)
    $escaped = $Value.Replace('\', '/').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function ConvertTo-WindowsCommandLineArgument {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0

    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) {
            $backslashes++
            continue
        }

        if ($character -eq [char]34) {
            if ($backslashes -gt 0) {
                [void]$builder.Append((-join (([string][char]92) * ($backslashes * 2))))
            }
            [void]$builder.Append('\"')
            $backslashes = 0
            continue
        }

        if ($backslashes -gt 0) {
            [void]$builder.Append((-join (([string][char]92) * $backslashes)))
            $backslashes = 0
        }
        [void]$builder.Append($character)
    }

    if ($backslashes -gt 0) {
        [void]$builder.Append((-join (([string][char]92) * ($backslashes * 2))))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

$repoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    $repoRoot = (Get-Location).Path
}
$initRoot = Join-Path $repoRoot 'emacs-init'
$runtimeRoot = Join-Path $repoRoot 'runtime'
$currentBinFile = Join-Path $runtimeRoot 'current-bin.txt'

if (-not (Test-Path -LiteralPath (Join-Path $initRoot 'init.el') -PathType Leaf)) {
    Stop-WithError -Title 'The emacs-init configuration folder is missing.' -Details @(
        "Expected: $initRoot\init.el",
        'Keep ed.cmd and ed.ps1 in the repository root.'
    )
}

$startDir = (Get-Location).Path
$openFile = $null

if (-not [string]::IsNullOrWhiteSpace($Path)) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Stop-WithError -Title 'The requested path does not exist.' -Details @("Path: $Path")
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) {
        $startDir = $item.FullName
    }
    else {
        $startDir = $item.DirectoryName
        $openFile = $item.FullName
    }
}

$emacs = Resolve-EdEmacsExecutable -RuntimeRoot $runtimeRoot -CurrentBinFile $currentBinFile
if (-not $emacs) {
    Write-Host ''
    Write-Host 'ed: portable Emacs is not installed yet.' -ForegroundColor Yellow
    Write-Host '    The installer will download the official GNU Emacs 30.2 ZIP' -ForegroundColor White
    Write-Host "    into $repoRoot\downloads and extract it under runtime." -ForegroundColor White
    Write-Host '    The installer will ask for approval before any download.' -ForegroundColor White
    Write-Host ''

    $engine = (Get-Process -Id $PID).Path
    & $engine -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'install.ps1') -SkipPathPrompt
    $installExitCode = $LASTEXITCODE
    if ($installExitCode -ne 0) {
        if ($installExitCode -eq 2) {
            Write-Host 'ed: installation was declined; nothing was launched.' -ForegroundColor Yellow
            exit 2
        }
        Stop-WithError -Title 'Portable Emacs installation did not complete.' -Details @(
            "Installer exit code: $installExitCode",
            "You can retry with $repoRoot\install.cmd."
        )
    }

    $emacs = Resolve-EdEmacsExecutable -RuntimeRoot $runtimeRoot -CurrentBinFile $currentBinFile -SkipSystemPath
    if (-not $emacs) {
        Stop-WithError -Title 'The installer completed but portable Emacs was not found.' -Details @(
            "Expected a runtime below: $runtimeRoot"
        )
    }
}

$startDirForElisp = $startDir.TrimEnd([char[]]@([char]92, [char]47)) + '/'
$openedFileValue = if ($openFile) { 't' } else { 'nil' }
$startupExpression = "(setq ed-start-dir $(ConvertTo-ElispString $startDirForElisp) ed-launch-opened-file $openedFileValue)"

$arguments = @(
    '--no-site-file',
    '--init-directory',
    $initRoot,
    '--eval',
    $startupExpression
)
if ($openFile) {
    $arguments += $openFile
}

$argumentString = ($arguments | ForEach-Object { ConvertTo-WindowsCommandLineArgument $_ }) -join ' '
$emacsBinPath = Split-Path  $emacs -Parent

if ($emacsBinPath -and $env:PATH -and -not($env:PATH.Contains(";$($emacsBinPath)"))) {
     $env:PATH += ";$($emacsBinPath)";
}

Write-Host 'ed: launching Emacs' -ForegroundColor Cyan
Write-Host "    executable : $emacs"
Write-Host "    init       : $initRoot"
Write-Host "    directory  : $startDir"
if ($openFile) {
    Write-Host "    file       : $openFile"
}

Start-Process -FilePath $emacs -ArgumentList $argumentString -WorkingDirectory $startDir | Out-Null

```

## File content `install.ps1`:

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
Installs a verified portable GNU Emacs build for Windows.

.DESCRIPTION
Downloads the complete Windows ZIP from an official GNU mirror, verifies it
against the GNU SHA-256 file, extracts it under runtime, and optionally adds the
repository root to the current user's PATH.

The PATH update reads the registry value without expanding embedded variables,
then writes it back using its original registry value type. This avoids replacing
values such as %USERPROFILE% with expanded absolute paths.

.PARAMETER Version
GNU Emacs release to install. The default is 30.2.

.PARAMETER Mirror
Preferred GNU mirror. Auto tries the GNU redirector, Berkeley, Waterloo, and the
main GNU server in that order. A named mirror is tried first, then the remaining
mirrors are used as fallbacks.

.PARAMETER Force
Replace an existing installation of the same version after the archive has
been verified.

.PARAMETER SkipPathPrompt
Do not offer to update the current user's PATH.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+$')]
    [string]$Version = '30.2',

    [ValidateSet('Auto', 'Berkeley', 'Waterloo', 'GNU')]
    [string]$Mirror = 'Auto',

    [switch]$Force,
    [switch]$SkipPathPrompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This installer currently supports Windows only.'
}

. (Join-Path $PSScriptRoot 'lib\Ed.Common.ps1')

[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkCyan
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "  [ .. ] $Message" -ForegroundColor Gray
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "  [ OK ] $Message" -ForegroundColor Green
}

function Read-Confirmation {
    param([Parameter(Mandatory)][string]$Question)
    $answer = Read-Host "$Question [y/N]"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $false
    }
    return $answer.Trim().ToLowerInvariant() -in @('y', 'yes')
}

function Join-UriPath {
    param(
        [Parameter(Mandatory)][string]$BaseUri,
        [Parameter(Mandatory)][string[]]$Segments
    )
    $value = $BaseUri.TrimEnd([char]47)
    foreach ($segment in $Segments) {
        $value += '/' + $segment.Trim([char]47)
    }
    return $value
}

function Invoke-FileDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destination
    )

    $partial = "$Destination.partial"
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $partial -UseBasicParsing -TimeoutSec 900
        if (-not (Test-Path -LiteralPath $partial -PathType Leaf)) {
            throw 'The download command completed without creating a file.'
        }
        Move-Item -LiteralPath $partial -Destination $Destination -Force
    }
    finally {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    }
}

function Get-ExpectedHash {
    param(
        [Parameter(Mandatory)][string]$ChecksumFile,
        [Parameter(Mandatory)][string]$ArchiveName
    )

    $escapedName = [Regex]::Escape($ArchiveName)
    foreach ($line in Get-Content -LiteralPath $ChecksumFile) {
        if ($line -match "^(?<hash>[0-9A-Fa-f]{64})\s+\*?$escapedName\s*$") {
            return $Matches.hash.ToUpperInvariant()
        }
    }
    throw "The checksum file does not contain an entry for $ArchiveName."
}

function Get-MirrorOrder {
    param([Parameter(Mandatory)][string]$Preferred)

    $all = @('Auto', 'Berkeley', 'Waterloo', 'GNU')
    if ($Preferred -eq 'Auto') {
        return $all
    }
    return @($Preferred) + @($all | Where-Object { $_ -ne $Preferred })
}

$repoRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    $repoRoot = (Get-Location).Path
}
$runtimeRoot = Join-Path $repoRoot 'runtime'
$downloadRoot = Join-Path $repoRoot 'downloads'
$majorVersion = ($Version -split '\.')[0]
$archiveName = "emacs-$Version.zip"
$checksumName = "emacs-$Version-sha256sum.txt"
$versionRoot = Join-Path $runtimeRoot "emacs-$Version"
$currentBinFile = Join-Path $runtimeRoot 'current-bin.txt'
$archivePath = Join-Path $downloadRoot $archiveName
$checksumPath = Join-Path $downloadRoot $checksumName

$mirrorBases = [ordered]@{
    Auto      = 'https://ftpmirror.gnu.org'
    Berkeley  = 'https://mirrors.ocf.berkeley.edu/gnu'
    Waterloo  = 'https://mirror.csclub.uwaterloo.ca/gnu'
    GNU       = 'https://ftp.gnu.org/gnu'
}

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

Write-Section 'Portable GNU Emacs installer'
Write-Step "Repository: $repoRoot"
Write-Step "Version: $Version"

$existingExecutable = Find-EdEmacsExecutable -Root $versionRoot
$binDir = $null

if ((Test-Path -LiteralPath $versionRoot) -and -not $existingExecutable -and -not $Force) {
    throw "The destination exists but does not contain Emacs: $versionRoot. Use -Force to replace it."
}

if ($existingExecutable -and -not $Force) {
    $binDir = Split-Path -Parent $existingExecutable.FullName
    Write-Ok "Emacs $Version is already installed at $binDir"
}
else {
    Write-Host ''
    Write-Host "  Archive: $archiveName" -ForegroundColor White
    Write-Host "  Download folder: $downloadRoot" -ForegroundColor White
    Write-Host "  Preferred mirror: $Mirror" -ForegroundColor White
    Write-Host ''

    if (-not (Read-Confirmation -Question "Download and install GNU Emacs $Version")) {
        Write-Host 'Installation cancelled. No download was started.' -ForegroundColor Yellow
        exit 2
    }

    $downloadSucceeded = $false
    $lastError = $null

    foreach ($mirrorName in (Get-MirrorOrder -Preferred $Mirror)) {
        $baseUri = $mirrorBases[$mirrorName]
        $releasePath = "emacs/windows/emacs-$majorVersion"
        $checksumUri = Join-UriPath -BaseUri $baseUri -Segments @($releasePath, $checksumName)
        $archiveUri = Join-UriPath -BaseUri $baseUri -Segments @($releasePath, $archiveName)

        Write-Section "Trying GNU mirror: $mirrorName"
        try {
            Write-Step "Downloading checksum from $checksumUri"
            Invoke-FileDownload -Uri $checksumUri -Destination $checksumPath
            $expectedHash = Get-ExpectedHash -ChecksumFile $checksumPath -ArchiveName $archiveName
            Write-Ok "Expected SHA-256: $expectedHash"

            $needsArchiveDownload = $true
            if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
                Write-Step 'Checking the existing local archive...'
                $existingHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToUpperInvariant()
                if ($existingHash -eq $expectedHash) {
                    Write-Ok 'The existing local archive is valid and will be reused.'
                    $needsArchiveDownload = $false
                }
                else {
                    Write-Host '  Existing archive checksum mismatch. It will be replaced.' -ForegroundColor Yellow
                    Remove-Item -LiteralPath $archivePath -Force
                }
            }

            if ($needsArchiveDownload) {
                Write-Step "Downloading $archiveUri"
                Invoke-FileDownload -Uri $archiveUri -Destination $archivePath
            }

            Write-Step 'Verifying SHA-256...'
            $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToUpperInvariant()
            if ($actualHash -ne $expectedHash) {
                throw "SHA-256 mismatch. Expected $expectedHash but received $actualHash."
            }

            Write-Ok "Verified $archiveName"
            $downloadSucceeded = $true
            break
        }
        catch {
            $lastError = $_.Exception.Message
            Write-Host "  Mirror failed: $lastError" -ForegroundColor Yellow
            Remove-Item -LiteralPath "$archivePath.partial" -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath "$checksumPath.partial" -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $downloadSucceeded) {
        throw "All GNU mirrors failed. Last error: $lastError"
    }

    Write-Section 'Extracting verified archive'
    $stagingRoot = Join-Path $runtimeRoot ".staging-$Version-$PID"
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue

    try {
        Write-Step "Extracting to staging folder: $stagingRoot"
        Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingRoot -Force
        $stagedExecutable = Find-EdEmacsExecutable -Root $stagingRoot
        if (-not $stagedExecutable) {
            throw 'The verified archive did not contain runemacs.exe or emacs.exe.'
        }

        if (Test-Path -LiteralPath $versionRoot) {
            if (-not $Force) {
                throw "The destination already exists: $versionRoot. Use -Force to replace it."
            }
            Remove-Item -LiteralPath $versionRoot -Recurse -Force
        }

        Move-Item -LiteralPath $stagingRoot -Destination $versionRoot
        $installedExecutable = Find-EdEmacsExecutable -Root $versionRoot
        if (-not $installedExecutable) {
            throw 'Emacs could not be found after moving the staged installation.'
        }
        $binDir = Split-Path -Parent $installedExecutable.FullName
    }
    finally {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Ok "Installed Emacs $Version at $versionRoot"
    Write-Ok "Emacs bin directory: $binDir"
}

$relativeBin = $binDir.Substring($runtimeRoot.Length).TrimStart([char]92)
Set-Content -LiteralPath $currentBinFile -Value $relativeBin -Encoding ASCII

if (-not $SkipPathPrompt) {
    Write-Section 'Optional user PATH update'
    Write-Host '  The update preserves unexpanded registry references such as %USERPROFILE%.' -ForegroundColor Gray
    Write-Host "  Repository launcher path: $repoRoot" -ForegroundColor White
    Write-Host '  Only the stable launcher path is added; versioned runtime paths stay private.' -ForegroundColor Gray
    Write-Host ''

    if (Read-Confirmation -Question 'Add the ed launcher directory to your user PATH') {
        $pathResult = Add-EdUserPathEntriesPreservingExpansion -Entries @($repoRoot)
        if ($pathResult.Changed) {
            try {
                Send-EdEnvironmentChangedMessage
            }
            catch {
                Write-Host "  PATH was written, but the environment-change broadcast failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            Write-Ok 'User PATH updated and verified without expanding existing environment-variable references.'
        }
        else {
            Write-Ok 'The repository launcher directory is already present in the user PATH.'
        }
        Write-Host '  Open a new terminal before using ed, emacs, or runemacs.' -ForegroundColor Yellow
    }
    else {
        Write-Host '  PATH was not changed. You can run ed.cmd directly from this folder.' -ForegroundColor Yellow
    }
}

Write-Section 'Ready'
Write-Host '  Launch in the current directory:' -ForegroundColor Gray
Write-Host "    $repoRoot\ed.cmd" -ForegroundColor White
Write-Host ''
Write-Host '  After adding the repository to PATH:' -ForegroundColor Gray
Write-Host '    ed' -ForegroundColor White
Write-Host ''

```

## File content `lib\Ed.Common.ps1`:

```powershell
#Requires -Version 5.1

Set-StrictMode -Version Latest

function Find-EdEmacsExecutable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return $null
    }

    foreach ($name in @('runemacs.exe', 'emacs.exe')) {
        $candidate = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $name -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($candidate) {
            return $candidate
        }
    }
    return $null
}

function Resolve-EdEmacsExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RuntimeRoot,
        [Parameter(Mandatory)][string]$CurrentBinFile,
        [switch]$SkipSystemPath
    )

    if (Test-Path -LiteralPath $CurrentBinFile -PathType Leaf) {
        $relativeBin = (Get-Content -LiteralPath $CurrentBinFile -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($relativeBin) -and
            -not [IO.Path]::IsPathRooted($relativeBin)) {
            $recordedBin = Join-Path $RuntimeRoot $relativeBin
            foreach ($name in @('runemacs.exe', 'emacs.exe')) {
                $candidate = Join-Path $recordedBin $name
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    return $candidate
                }
            }
        }
    }

    $portable = Find-EdEmacsExecutable -Root $RuntimeRoot
    if ($portable) {
        return $portable.FullName
    }

    if (-not $SkipSystemPath) {
        foreach ($name in @('runemacs', 'emacs')) {
            $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($command) {
                return $command.Source
            }
        }
    }
    return $null
}

function Get-EdComparablePath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $candidate = $Value.Trim().Trim('"').TrimEnd([char[]]@([char]92, [char]47))
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return ''
    }
    return [Environment]::ExpandEnvironmentVariables($candidate)
}

function Add-EdUserPathEntriesPreservingExpansion {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string[]]$Entries,
        [string]$RegistrySubKey = 'Environment'
    )

    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($RegistrySubKey, $true)
    if (-not $key) {
        throw "Could not open HKCU\$RegistrySubKey for writing."
    }

    try {
        $options = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        $pathExists = $null -ne $key.GetValue('Path', $null, $options)
        $rawPath = [string]$key.GetValue('Path', '', $options)
        $valueKind = if ($pathExists) {
            $key.GetValueKind('Path')
        }
        else {
            [Microsoft.Win32.RegistryValueKind]::ExpandString
        }

        if ($valueKind -notin @(
                [Microsoft.Win32.RegistryValueKind]::String,
                [Microsoft.Win32.RegistryValueKind]::ExpandString)) {
            throw "HKCU\$RegistrySubKey\Path has unsupported registry type: $valueKind."
        }

        $existingParts = @()
        if (-not [string]::IsNullOrWhiteSpace($rawPath)) {
            $existingParts = @($rawPath -split ';' |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }

        $entriesToAppend = New-Object System.Collections.Generic.List[string]
        foreach ($entry in $Entries) {
            $literalEntry = $entry.Trim().TrimEnd([char[]]@([char]92, [char]47))
            if ([string]::IsNullOrWhiteSpace($literalEntry)) {
                throw 'A blank PATH entry was requested.'
            }

            $normalized = Get-EdComparablePath -Value $literalEntry
            $comparisonParts = @($existingParts) + @($entriesToAppend)
            $exists = $false
            foreach ($part in $comparisonParts) {
                if ((Get-EdComparablePath -Value $part).Equals(
                        $normalized, [StringComparison]::OrdinalIgnoreCase)) {
                    $exists = $true
                    break
                }
            }
            if (-not $exists) {
                [void]$entriesToAppend.Add($literalEntry)
            }
        }

        if ($entriesToAppend.Count -eq 0) {
            return [pscustomobject]@{
                Changed = $false
                Before = $rawPath
                After = $rawPath
                Kind = $valueKind
            }
        }

        $newPath = $rawPath
        if (-not [string]::IsNullOrEmpty($newPath) -and -not $newPath.EndsWith(';')) {
            $newPath += ';'
        }
        $newPath += ($entriesToAppend -join ';')
        if ($newPath.Length -gt 32767) {
            throw 'The requested user PATH would exceed the Windows environment-variable length limit.'
        }

        if (-not $PSCmdlet.ShouldProcess("HKCU\$RegistrySubKey\Path", 'Append PATH entries')) {
            return [pscustomobject]@{
                Changed = $false
                Before = $rawPath
                After = $rawPath
                Kind = $valueKind
            }
        }

        $key.SetValue('Path', $newPath, $valueKind)
        $writtenPath = [string]$key.GetValue('Path', '', $options)
        $writtenKind = $key.GetValueKind('Path')
        if ($writtenPath -cne $newPath -or $writtenKind -ne $valueKind) {
            if ($pathExists) {
                $key.SetValue('Path', $rawPath, $valueKind)
            }
            else {
                $key.DeleteValue('Path', $false)
            }
            throw 'PATH verification failed after writing; the original registry value was restored.'
        }

        return [pscustomobject]@{
            Changed = $true
            Before = $rawPath
            After = $newPath
            Kind = $valueKind
        }
    }
    finally {
        $key.Dispose()
    }
}

function Send-EdEnvironmentChangedMessage {
    [CmdletBinding()]
    param()

    if (-not ([System.Management.Automation.PSTypeName]'EdEnvironmentBroadcast').Type) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class EdEnvironmentBroadcast
{
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint flags, uint timeout, out UIntPtr result);
}
'@ | Out-Null
    }

    $result = [UIntPtr]::Zero
    [void][EdEnvironmentBroadcast]::SendMessageTimeout(
        [IntPtr]0xffff,
        0x001A,
        [UIntPtr]::Zero,
        'Environment',
        0x0002,
        5000,
        [ref]$result)
}

```

## File content `README.md`:

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


## File content `tools\README.md`:

# Test tools

`Test-PathSafety.ps1` exercises the shared PATH implementation against a temporary key below `HKCU\Software\ed-is-my-portable-emacs\Tests`. It never targets the real user PATH.

```powershell
.\tools\Test-PathSafety.ps1
```

`window-tool.ps1` targets one explicit process ID. Keyboard input first verifies that the same window is foreground; otherwise it refuses to type.

```powershell
.\tools\window-tool.ps1 -ProcessId 1234 -Screenshot .\work\emacs.png
.\tools\window-tool.ps1 -ProcessId 1234 -Click
.\tools\window-tool.ps1 -ProcessId 1234 -Keys '^x'
.\tools\window-tool.ps1 -ProcessId 1234 -State Maximize
```

`WindowAutomation.psm1` exposes the underlying commands for test scripts:

- `Get-EdWindow`
- `Get-EdWindowRectangle`
- `Set-EdWindowBounds`
- `Set-EdWindowState`
- `Set-EdWindowForeground`
- `Invoke-EdWindowClick`
- `Send-EdWindowKeys`
- `Save-EdWindowScreenshot`

Resolve the target PID from its executable path below this repository's `runtime` directory. Never select a process only by the generic name `emacs`.


## File content `tools\Test-PathSafety.ps1`:

```powershell
#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\Ed.Common.ps1')

function Assert-Ed {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
    Write-Host "  [ OK ] $Message" -ForegroundColor Green
}

$testRoot = 'Software\ed-is-my-portable-emacs\Tests'
$testName = [Guid]::NewGuid().ToString('N')
$testSubKey = "$testRoot\$testName"
$base = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($testSubKey)
$options = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames

try {
    Write-Host 'PATH safety tests (isolated temporary HKCU key)' -ForegroundColor Cyan

    $raw = 'C:\Tools;%JAVA_HOME%\bin;%USERPROFILE%\bin;'
    $base.SetValue('Path', $raw, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    $result = Add-EdUserPathEntriesPreservingExpansion -Entries @('D:\portable ed') -RegistrySubKey $testSubKey
    $actual = [string]$base.GetValue('Path', '', $options)
    Assert-Ed ($result.Changed) 'a missing entry is appended'
    Assert-Ed ($actual -ceq "$raw" + 'D:\portable ed') 'raw %VARIABLE% references are byte-for-byte preserved'
    Assert-Ed ($base.GetValueKind('Path') -eq [Microsoft.Win32.RegistryValueKind]::ExpandString) 'REG_EXPAND_SZ type is preserved'

    $beforeSecondAdd = $actual
    $second = Add-EdUserPathEntriesPreservingExpansion -Entries @('d:\PORTABLE ED\') -RegistrySubKey $testSubKey
    $afterSecondAdd = [string]$base.GetValue('Path', '', $options)
    Assert-Ed (-not $second.Changed) 'duplicate detection is case-insensitive and slash-insensitive'
    Assert-Ed ($afterSecondAdd -ceq $beforeSecondAdd) 'an idempotent call does not rewrite PATH'

    $env:ED_PATH_TEST_HOME = 'C:\VariableRoot'
    $variableRaw = '%ED_PATH_TEST_HOME%\bin'
    $base.SetValue('Path', $variableRaw, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    $expandedDuplicate = Add-EdUserPathEntriesPreservingExpansion -Entries @('C:\VariableRoot\bin') -RegistrySubKey $testSubKey
    Assert-Ed (-not $expandedDuplicate.Changed) 'an expanded equivalent of an existing %VARIABLE% entry is not duplicated'
    Assert-Ed ([string]$base.GetValue('Path', '', $options) -ceq $variableRaw) 'expanded-equivalent detection leaves raw text untouched'

    $plainRaw = 'C:\Plain'
    $base.SetValue('Path', $plainRaw, [Microsoft.Win32.RegistryValueKind]::String)
    [void](Add-EdUserPathEntriesPreservingExpansion -Entries @('C:\Added') -RegistrySubKey $testSubKey)
    Assert-Ed ($base.GetValueKind('Path') -eq [Microsoft.Win32.RegistryValueKind]::String) 'REG_SZ type is preserved'

    $base.SetValue('Path', $raw, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    [void](Add-EdUserPathEntriesPreservingExpansion -Entries @('C:\WhatIf') -RegistrySubKey $testSubKey -WhatIf)
    Assert-Ed ([string]$base.GetValue('Path', '', $options) -ceq $raw) '-WhatIf makes no registry change'

    $base.SetValue('Path', [byte[]](1, 2, 3), [Microsoft.Win32.RegistryValueKind]::Binary)
    $unsupportedRejected = $false
    try {
        [void](Add-EdUserPathEntriesPreservingExpansion -Entries @('C:\Never') -RegistrySubKey $testSubKey)
    }
    catch {
        $unsupportedRejected = $_.Exception.Message -like '*unsupported registry type*'
    }
    Assert-Ed $unsupportedRejected 'an unsupported PATH registry type is rejected'
    Assert-Ed ($base.GetValueKind('Path') -eq [Microsoft.Win32.RegistryValueKind]::Binary) 'rejection does not rewrite the unsupported value'

    Write-Host 'All PATH safety tests passed.' -ForegroundColor Cyan
}
finally {
    Remove-Item Env:\ED_PATH_TEST_HOME -ErrorAction SilentlyContinue
    $base.Dispose()
    $testsKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\ed-is-my-portable-emacs', $true)
    if ($testsKey) {
        try {
            $testsKey.DeleteSubKeyTree("Tests\$testName", $false)
        }
        finally {
            $testsKey.Dispose()
        }
    }
}

```

## File content `tools\WindowAutomation.psm1`:

```powershell
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ([System.Management.Automation.PSTypeName]'EdWindowNative').Type) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class EdWindowNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(
        IntPtr hWnd, int x, int y, int width, int height, bool repaint);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
'@ | Out-Null
}

function Get-EdWindow {
    [CmdletBinding()]
    param(
        [int]$ProcessId,
        [string]$TitlePattern = '*',
        [int]$TimeoutSeconds = 15
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $processes = if ($ProcessId) {
            @(Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
        }
        else {
            @(Get-Process | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
        }

        $match = $processes |
            Where-Object {
                $_.MainWindowHandle -ne [IntPtr]::Zero -and
                $_.MainWindowTitle -like $TitlePattern
            } |
            Select-Object -First 1
        if ($match) {
            return $match
        }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "No visible window matched process '$ProcessId' and title '$TitlePattern' within $TimeoutSeconds seconds."
}

function Get-EdWindowRectangle {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][Diagnostics.Process]$Process)

    process {
        $rect = New-Object EdWindowNative+RECT
        if (-not [EdWindowNative]::GetWindowRect($Process.MainWindowHandle, [ref]$rect)) {
            throw "Could not read the window rectangle for PID $($Process.Id)."
        }
        [pscustomobject]@{
            Left = $rect.Left
            Top = $rect.Top
            Width = $rect.Right - $rect.Left
            Height = $rect.Bottom - $rect.Top
            Right = $rect.Right
            Bottom = $rect.Bottom
        }
    }
}

function Set-EdWindowState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [ValidateSet('Restore', 'Minimize', 'Maximize')]
        [string]$State
    )

    $command = switch ($State) {
        Restore { 9 }
        Minimize { 6 }
        Maximize { 3 }
    }
    if (-not [EdWindowNative]::ShowWindow($Process.MainWindowHandle, $command)) {
        # ShowWindow returns the prior visibility state, not success. Refreshing
        # and validating the handle is the meaningful check.
        $Process.Refresh()
        if ($Process.MainWindowHandle -eq [IntPtr]::Zero) {
            throw "The window for PID $($Process.Id) is no longer available."
        }
    }
}

function Set-EdWindowBounds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [ValidateRange(-10000, 10000)][int]$Left,
        [ValidateRange(-10000, 10000)][int]$Top,
        [ValidateRange(320, 10000)][int]$Width,
        [ValidateRange(240, 10000)][int]$Height
    )

    [void][EdWindowNative]::ShowWindow($Process.MainWindowHandle, 9)
    if (-not [EdWindowNative]::MoveWindow(
            $Process.MainWindowHandle, $Left, $Top, $Width, $Height, $true)) {
        throw "Could not resize the window for PID $($Process.Id)."
    }

    $actual = Get-EdWindowRectangle -Process $Process
    if ($actual.Left -ne $Left -or $actual.Top -ne $Top -or
        $actual.Width -ne $Width -or $actual.Height -ne $Height) {
        throw "Window bounds verification failed for PID $($Process.Id): expected ($Left,$Top) ${Width}x${Height}, received ($($actual.Left),$($actual.Top)) $($actual.Width)x$($actual.Height)."
    }
}

function Set-EdWindowForeground {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Diagnostics.Process]$Process)

    if ([EdWindowNative]::IsIconic($Process.MainWindowHandle)) {
        [void][EdWindowNative]::ShowWindow($Process.MainWindowHandle, 9)
    }
    [void][EdWindowNative]::SetForegroundWindow($Process.MainWindowHandle)

    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    do {
        if ([EdWindowNative]::GetForegroundWindow() -eq $Process.MainWindowHandle) {
            return
        }
        Start-Sleep -Milliseconds 100
        [void][EdWindowNative]::SetForegroundWindow($Process.MainWindowHandle)
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "Refusing input: PID $($Process.Id) did not become the foreground window."
}

function Invoke-EdWindowClick {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [ValidateRange(0.05, 0.95)][double]$HorizontalRatio = 0.5,
        [ValidateRange(0.05, 0.95)][double]$VerticalRatio = 0.5
    )

    Set-EdWindowForeground -Process $Process
    $rect = Get-EdWindowRectangle -Process $Process
    $x = [int]($rect.Left + ($rect.Width * $HorizontalRatio))
    $y = [int]($rect.Top + ($rect.Height * $VerticalRatio))
    if (-not [EdWindowNative]::SetCursorPos($x, $y)) {
        throw "Could not move the pointer to ($x, $y)."
    }
    [EdWindowNative]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [EdWindowNative]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Send-EdWindowKeys {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [Parameter(Mandatory)][string]$Keys
    )

    Set-EdWindowForeground -Process $Process
    if ([EdWindowNative]::GetForegroundWindow() -ne $Process.MainWindowHandle) {
        throw "Refusing input: PID $($Process.Id) is not the foreground window."
    }
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
}

function Save-EdWindowScreenshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [Parameter(Mandatory)][string]$Path
    )

    $rect = Get-EdWindowRectangle -Process $Process
    if ($rect.Width -le 0 -or $rect.Height -le 0) {
        throw "The window for PID $($Process.Id) has no visible area."
    }

    $absolutePath = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $absolutePath
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $bitmap = New-Object Drawing.Bitmap $rect.Width, $rect.Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen(
            $rect.Left,
            $rect.Top,
            0,
            0,
            [Drawing.Size]::new($rect.Width, $rect.Height))
        $bitmap.Save($absolutePath, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    return Get-Item -LiteralPath $absolutePath
}

Export-ModuleMember -Function @(
    'Get-EdWindow',
    'Get-EdWindowRectangle',
    'Set-EdWindowState',
    'Set-EdWindowBounds',
    'Set-EdWindowForeground',
    'Invoke-EdWindowClick',
    'Send-EdWindowKeys',
    'Save-EdWindowScreenshot'
)

```

## File content `tools\window-tool.ps1`:

```powershell
#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Screenshot')]
param(
    [Parameter(Mandatory)][int]$ProcessId,

    [Parameter(Mandatory, ParameterSetName = 'Screenshot')]
    [string]$Screenshot,

    [Parameter(Mandatory, ParameterSetName = 'Click')]
    [switch]$Click,

    [Parameter(Mandatory, ParameterSetName = 'Keys')]
    [string]$Keys,

    [Parameter(Mandatory, ParameterSetName = 'State')]
    [ValidateSet('Restore', 'Minimize', 'Maximize')]
    [string]$State
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'WindowAutomation.psm1') -Force

$window = Get-EdWindow -ProcessId $ProcessId
switch ($PSCmdlet.ParameterSetName) {
    Screenshot { Save-EdWindowScreenshot -Process $window -Path $Screenshot }
    Click { Invoke-EdWindowClick -Process $window }
    Keys { Send-EdWindowKeys -Process $window -Keys $Keys }
    State { Set-EdWindowState -Process $window -State $State }
}

```


