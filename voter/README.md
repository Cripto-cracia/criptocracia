# Criptocracia - Voter

![logo](../logo.png)

*Disclaimer: The author is NOT a cryptographer and this work has not been reviewed. This means that there is very likely a fatal flaw somewhere. Criptocracia is still experimental and not production-ready.*

## Configuration

Voter use a TOML settings file (auto-initialized on first run) stored in `~/.voter/settings.toml`. Edit it to specify:

```toml
# ~/.criptocracia/settings.toml
secret_key = "<your_nostr_nsec_key>"
ec_public_key = "<EC_nostr_npub_key>"
log_level = "info"
relays = ["wss://relay.mostro.network"]
```

* `secret_key`: Nostr private key for signing Gift Wrap messages.
* `ec_public_key`: EC’s Nostr public key (used by `voter` to encrypt requests).
* `relays`: List of Nostr relays

---

## Usage

1. List available elections:

   ```sh
   target/release/voter
   ```
2. Select an election and request a token (navigate UI with arrow keys and press Enter).
3. After receiving the blinded signature, choose your candidate and press Enter to cast your vote.
4. Vote confirmation appears in the UI, and the EC processes it asynchronously.

---

## Logging and Debugging

Logs are written to `app.log` in the current working directory. Set `log_level` in settings to `debug` for verbose output.