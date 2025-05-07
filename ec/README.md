# Criptocracia - Electoral Commission

![logo](../logo.png)

*Disclaimer: The author is NOT a cryptographer and this work has not been reviewed. This means that there is very likely a fatal flaw somewhere. Criptocracia is still experimental and not production-ready.*

## Configuration

Manually add voters pubkeys in the file `voters_pubkeys.json`.

## Usage

1. Start the EC service:

   ```sh
   target/release/ec
   ```
2. The EC will publish the candidate list to Nostr and wait for blind signature requests.
3. Voter requests will be logged and served automatically.
4. Once votes arrive, EC will verify, tally, and publish results.

---

## Logging and Debugging

Logs are written to `app.log` in the current working directory. Set `log_level` in settings to `debug` for verbose output.