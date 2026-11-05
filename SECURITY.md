# Security policy

Rondo asks for powerful macOS permissions (Accessibility, Screen Recording, optionally Full Disk Access) and runs command-line tools that can delete files (Mole, through Disk Clean). Security reports are taken seriously.

## Supported versions

Only the [latest release](https://github.com/simone98dm/Rondo/releases/latest) gets security fixes. Please update before reporting.

## Reporting a vulnerability

**Please don't open a public issue.** Report it privately through GitHub:

1. Go to the repository's **Security** tab → **Report a vulnerability**
   ([direct link](https://github.com/simone98dm/Rondo/security/advisories/new)).
2. Describe the problem, the impact, and the steps to reproduce. A proof of concept, the Rondo and macOS versions, and logs help a lot.

You'll get an acknowledgement within a week. Once a fix is released, the advisory is published and you're credited, unless you prefer otherwise.

## What's in scope

- Rondo deleting, moving or overwriting files the user didn't confirm (for example a Disk Clean action that runs without its preview, or a converter writing over an existing file).
- Running commands or code from untrusted input: file names, file contents, clipboard, Mole's output.
- Misuse of the Accessibility, Screen Recording or Full Disk Access permissions Rondo has been granted, or exposing what they can read.
- Data leaving the Mac. Rondo makes no network calls apart from the update check; anything else is a bug.

## Out of scope

- Bugs in [Mole](https://github.com/tw93/mole) itself: report them to Mole (see its security policy). Rondo's handling of Mole's output is in scope.
- Problems that need an already compromised Mac or an attacker with the user's admin password.
