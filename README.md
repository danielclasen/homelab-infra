# Homelab Infrastructure

This repository contains Kubernetes configurations and infrastructure definitions for a homelab setup. Secrets are managed using [SOPS](https://github.com/getsops/sops).

## Git Hooks Setup

This repository includes a pre-commit hook to prevent accidentally committing unencrypted SOPS secrets. To enable this hook, you need to link it to your local `.git/hooks` directory.

From the root of the repository, run the following command:

```bash
ln -sf .hooks/pre-commit .git/hooks/pre-commit
```

**Prerequisites for the hook:**

*   **`yq`**: The pre-commit hook script requires `yq` (version 4+, by Mike Farah) to parse YAML files. Please ensure it's installed and available in your PATH. You can find installation instructions [here](https://github.com/mikefarah/yq#install).

This will ensure that the hook checks for unencrypted secrets before you make a commit.
