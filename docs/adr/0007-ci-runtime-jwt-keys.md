# JWT private keys generated at runtime in CI, not committed

The JWT key pair (`private.pem` / `public.pem`) is not tracked in git. Instead, CI generates fresh keys per run via `openssl genpkey` before running tests. The `JWT_PASSPHRASE` must be empty (`JWT_PASSPHRASE=`) because OpenSSL 3.x (present on `ubuntu-latest` GitHub runners) rejects non-empty passphrases on unencrypted PKCS#8 keys with `DECODER routines::unsupported`.

Options considered: (1) commit keys to git — simplest but leaks private key material into the repo and couples CI to a single key file that may differ from local development keys, (2) commit an encrypted key with a CI secret passphrase — adds secret management overhead for no security gain in a demo project, (3) generate via `lexik:jwt:generate-keypair` Symfony command — requires fully booted app with `.env`, cache, and Doctrine setup, adding unnecessary boot time and complexity.

Runtime generation via `openssl` is the least coupled approach: no key file drift between environments, zero secret management, and the CI step is trivially auditable.
