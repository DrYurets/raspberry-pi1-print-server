# Contributing

Thanks for your interest! This is a small utility project — contributions
of any size are welcome.

## What helps most

- **Testing on other printers** — the setup is written for HP LaserJet 1020,
  but the same approach fits other foo2zjs-driven printers
  (LJ 1000/1005/1018, P1005–P1008, P1505). Report what works.
- **Docs improvements** — clearer steps, translations are welcome
  (`docs/` is currently in Russian).
- **Bug reports** — when opening an issue, please include output of
  `sudo bash diagnostics.sh` from the Pi.

## Pull requests

1. Fork, branch off `main`, keep commits small and in English.
2. Keep shell scripts POSIX-ish (`bash`, no exotic deps), idempotent,
   and tested on a real Pi if possible.
3. Update docs if behaviour changes.
