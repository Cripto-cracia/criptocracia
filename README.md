# Criptocracia

![logo](logo.png)

*Disclaimer: The author is NOT a cryptographer and this work has not been reviewed. This means that there is very likely a fatal flaw somewhere. Criptocracia is still experimental and not production-ready.*

**Criptocracia** is an experimental, open-source electronic voting system built in Rust. It leverages blind RSA signatures to ensure vote secrecy, voter anonymity and integrity, and uses the Nostr protocol (NIP-59 Gift Wrap) for decentralized, encrypted message transport.

## Context
The critical need for secure, transparent, and anonymous electronic‑voting systems is becoming ever more pressing, especially in settings where trust in central authorities is limited—addressing concerns that authoritarian regimes may use electoral systems to stay in power. The historical challenges of electoral fraud underscore the importance of exploring robust solutions. Modern cryptography provides powerful tools for building systems that can withstand manipulation and allow for public verification.

## Goal
The goal of leveraging open technologies such as the Rust programming language and the Nostr protocol, along with cryptographic techniques (initially, blind signatures), to develop a fraud-resistant and publicly auditable voting system is recognized.

## Fundamental Requirements
Derived from the initial consultation, the key security properties for this system are:
- Vote Secrecy/Anonymity: Voter choices must remain hidden from the Electoral Commission (EC) and third parties.
- Voter Authentication: Only eligible voters, identified by their Nostr public keys, are eligible to participate.
- Vote Uniqueness: Each voter may cast only one valid vote.
- Verifiability/Auditability: The electoral process and results must be publicly verifiable without compromising the identity of the voter, minimizing the trust required in the central tallying authority. (This central tallying authority may be comprised of a committee composed of a representative from each voting option.)
- Nostr's Role: Nostr is proposed as the underlying communication layer. Its decentralized, public/private event-based features can be used for both vote transmission and the implementation of a public bulletin board. Features such as NIP-59 Gift Wrap are used to encrypt data during transmission, protecting the confidentiality of the vote in transit.

## Voters
Registered users with a Nostr key pair (public and private). The public key (voter_pk) identifies the voter to the Electoral Commission.

## Electoral Commission (EC)
- Maintains a record of the public keys of authorized voters.
- Issues anonymous voting tokens using blind signatures.
- Receives encrypted votes.
- Verifies the validity of the tokens and prevents double voting.
- Performs and publish in Nostr the final count

## Nostr: Communication protocol used for:
- Requesting blind signatures (via NIP-59 Gift Wrap).
- Casting encrypted votes (via NIP-59 Gift Wrap).

## Architecture

Criptocracia is organized as a Cargo workspace containing two main binaries:

* **ec**: The Electoral Commission service that registers voters, issues blind signatures on voting tokens, receives anonymized votes, verifies them, and publishes results.
* **voter**: The client-side application used by registered voters to request a blind-signed token, unblind it, and cast their vote.

Shared workspace dependencies include:

* `blind-rsa-signatures v0.15.2` for RSA-based blind signature operations.
* `nostr-sdk v0.41.0` (feature `nip59`) for Gift Wrap message encryption and transport.
* `base64`, `num-bigint-dig`, `sha2`, and other utility crates for serialization and hashing.

---

## Cryptographic Protocol

1. **Blind Signature Request**

   * Voter generates a random nonce (128-bit BigUint) and computes `h_n = SHA256(nonce)`.
   * Voter blinds `h_n` using the EC's RSA public key to obtain `blinded_h_n` and a blinding factor.
   * `blinded_h_n` is Base64-encoded and sent to the EC via an encrypted Nostr Gift Wrap message.

2. **Blind Signature Issuance**

   * EC verifies the sender’s Nostr public key against the authorized voter list.
   * EC uses its RSA secret key to sign `blinded_h_n`, producing a blind signature.
   * EC encodes the blind signature in Base64 and returns it via Gift Wrap.

3. **Unblinding and Voting**

   * Voter decodes the blind signature, unblinds it using the stored blinding factor, and verifies the resulting token against the EC’s public RSA key.
   * The voter packages `(h_n, token, blinding_factor, candidate_id)` into a colon-delimited payload, Base64-encodes the first three parts, and sends via Gift Wrap with a freshly generated Nostr key pair to anonymize origin.

4. **Vote Reception and Tally**

   * EC receives the vote payload, decodes `h_n`, `token`, and `blinding_factor` from Base64, and parses `candidate_id`.
   * EC verifies the signature on `h_n` and checks that `h_n` has not been used before (prevents double voting).
   * Valid votes are recorded, tallied, and results published to Nostr as a custom event.

---

## Prerequisites

* Rust toolchain (>= 1.86.0)
* Nostr relay endpoint (e.g., `wss://relay.mostro.network`)

Ensure you have Git and Cargo installed. Clone the repository:

```sh
git clone https://github.com/grunch/criptocracia.git
cd criptocracia
```

---

## Building the Project

From the workspace root:

```sh
# Build both binaries in release mode
cargo build --release
```

Artifacts will be in `target/release/ec` and `target/release/voter`.

---

## Configuration

Voter binary use a TOML settings file (auto-initialized on first run) stored in `~/.voter/settings.toml`. Edit it to specify:

```toml
# ~/.criptocracia/settings.toml
secret_key = "<your_nostr_nsec_key>"
ec_public_key = "<EC_nostr_npub_key>"
log_level = "info"
relays = ["wss://relay.mostro.network"]
```

* `secret_key`: Nostr private key for signing Gift Wrap messages.
* `ec_public_key`: EC’s Nostr public key (used by `voter` to encrypt requests).

---

## Usage

### Running the Electoral Commission (EC)

1. Start the EC service:

   ```sh
   target/release/ec
   ```
2. The EC will publish the candidate list to Nostr and wait for blind signature requests.
3. Voter requests will be logged and served automatically.
4. Once votes arrive, EC will verify, tally, and publish results.

### Running the Voter Client

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

---

## Limitations

* **Experimental**: No formal security audit. Use only for study/demonstration.
* **Single EC**: Central authority issues tokens—no threshold or multi-party setup.
* **Replay Protection**: Based on one-time `h_n`, but stronger measures (timestamps, channels) may be needed.

---

## License

This project is licensed under MIT. See [LICENSE](LICENSE) for details.


## Todo list
- [x] EC publish list of candidates as a Nostr event
- [x] EC: Add manually voters pubkeys
- [ ] EC create a list of registration tokens to be send to voters (v0.2)
- [ ] Voter creates key pair and sign the token (v0.2)
- [ ] Voter send the registration token to EC in a gift wrap (v0.2)
- [ ] EC receives the registration token and save the voter's pubkey (v0.2)
- [x] Voter generates a nonce, hash it and send it to EC
- [x] voter: Add CLI to handle arguments
- [x] EC: async waiting for events and handle logs
- [x] Voter: List elections on voter UI
- [x] Voter: User select election and get list of candidates
- [x] EC blind sign the voting token and send it back to the voter
- [x] Voter cast vote
- [x] EC receive vote
- [x] EC Count votes and publish to Nostr
