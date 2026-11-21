# Security Policy

## Scope

This project is a set of setup scripts for a home LAN print server.
Relevant security considerations:

- **CUPS is exposed to the local network** on port 631 (`Allow @LOCAL`).
  Do not expose that port to the internet — it's designed for a trusted LAN.
- The setup enables remote CUPS administration for LAN clients and relies
  on the `lpadmin` group for authentication.
- Firmware `sihp1020.dl` is downloaded over **HTTP** from
  `foo2zjs.rkkda.com` by `getweb` — this is how the upstream project
  distributes it; verify the file if this concerns you.

## Reporting a Vulnerability

Please open a private report via GitHub
(**Security → Report a vulnerability**) or email dr.yurets@gmail.com.
Do not file public issues for vulnerabilities.
