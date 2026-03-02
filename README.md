# update-corporate-ca

A team utility that installs corporate TLS inspection CA certificates (e.g., Zscaler / Capgemini)
into the Linux trust store and validates HTTPS connectivity.

**Default behavior on WSL:** automatically imports matching CA certificates from the Windows certificate stores.

---

## One-time setup

```bash
git clone <REPO_URL> ~/.dotfiles
cd ~/.dotfiles
./install.sh
```