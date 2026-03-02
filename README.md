# update-corporate-ca

A team utility that installs corporate TLS inspection CA certificates (e.g., Zscaler / Capgemini)
into the Linux trust store and validates HTTPS connectivity.

This is distributed via `.dotfiles` and installed as a system command.

---

## One-time setup

1. Clone `.dotfiles`
2. Run:

```bash
cd .dotfiles
./install.sh