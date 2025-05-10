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

## Configuration and Usage

Go to the directory of voter and ec for specific instructions.

---

## Limitations

* **Experimental**: No formal security audit. Use only for study/demonstration.
* **Single EC**: Central authority issues tokens—no threshold or multi-party setup.
* **Replay Protection**: Based on one-time `h_n`, but stronger measures (timestamps, channels) may be needed.

---

## Nostr

As mentioned above, both the voter and the EC communicate by sending Gift Wrap events, but there are other messages that the EC publishes.

### Election

An addressable event kind `35000` with the election information in a serialized json object in the content field of the event, here an example of the json object:

```json
{
  "id": "f5f7",
  "name": "Libertad 2024",
  "start_time": 1746611643,
  "status": "open",
  "candidates": [
    {
      "id": 1,
      "name": "Donkey 🫏"
    },
    {
      "id": 2,
      "name": "Rat 🐀"
    },
    {
      "id": 3,
      "name": "Sheep 🐑"
    },
    {
      "id": 4,
      "name": "Sloth 🦥"
    }
  ],
  "end_time": 1746615243
}
```

The event would look like this:

```json
[
  "EVENT",
  "7157aabf-389e-4d3e-9656-4d818159dff2",
  {
    "tags": [
      [
        "d",
        "f5f7"
      ],
      [
        "expiration",
        "1747043643"
      ]
    ],
    "content": "{\"candidates\":[{\"id\":1,\"name\":\"Donkey 🫏\"},{\"id\":2,\"name\":\"Rat 🐀\"},{\"id\":3,\"name\":\"Sheep 🐑\"},{\"id\":4,\"name\":\"Sloth 🦥\"}],\"end_time\":1746615243,\"id\":\"f5f7\",\"name\":\"Libertad 2024\",\"start_time\":1746611643,\"status\":\"open\"}",
    "sig": "8b5bc04003c1d20ba98d33b2fd98a536d538d58afa1c9cfa81d3b693a3a20a764b51258e28335b10945439f7a09fca1d4d2ac40135a506e1bb4a8116259c46ab",
    "id": "557d833876048e50068dfb06b82344a058d8104f08578e8060623ec8004c29ac",
    "pubkey": "0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c",
    "created_at": 1746611643,
    "kind": 35000
  }
]
```

### Current status of the election

After each vote received the EC will publish another addressable event with kind `35001` with the current status of the election as a serialized json array in the content field, the event would like this:

```json
[
  "EVENT",
  "7157aabf-389e-4d3e-9656-4d818159dff2",
  {
    "tags": [
      [
        "d",
        "f5f7"
      ],
      [
        "expiration",
        "1747043706"
      ]
    ],
    "content": "[[\"Sheep 🐑\",2],[\"Donkey 🫏\",1]]",
    "sig": "3eb717f176be137d7adc0f9e6d52556c38d988bce59c2f683cbdc6f796df3a3e6d31aecf2866fa2df5d58ce7a287236f83e2c368a89015f7b8f4c5eea21e134d",
    "id": "7ae5c519f9e8886b70d0cef6155a69f3194e7b89cb88e589ed2012853915581e",
    "pubkey": "0000001ace57d0da17fc18562f4658ac6d093b2cc8bb7bd44853d0c196e24a9c",
    "created_at": 1746611706,
    "kind": 35001
  }
]
```

---

## License

This project is licensed under MIT. See [LICENSE](LICENSE) for details.

---

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
- [x] EC should change the status election depending `start_time` and `end_time`
- [x] voter: Show results in real time
