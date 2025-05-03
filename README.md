# Criptocracia

![logo](logo.png)

*Disclaimer: The author is NOT a cryptographer and this work has not been reviewed. This means that there is very likely a fatal flaw somewhere. Criptocracia is still experimental and not production-ready.*

## Context
The critical need for secure, transparent, and anonymous electronic‑voting systems is becoming ever more pressing, especially in settings where trust in central authorities is limited—addressing concerns that authoritarian regimes may use electoral systems to stay in power. The historical challenges of electoral fraud underscore the importance of exploring robust solutions. Modern cryptography provides powerful tools for building systems that can withstand manipulation and allow for public verification.

## Goal
The goal of leveraging open technologies such as the Rust programming language and the Nostr protocol, along with cryptographic techniques (initially, blind signatures), to develop a fraud-resistant and publicly auditable voting system is recognized.

## Fundamental Requirements
Derived from the initial consultation, the key security properties for this system are:
- Vote Secrecy/Anonymity: Voter choices must remain hidden from the Election Center (EC) and third parties.
- Voter Authentication: Only eligible voters, identified by their Nostr public keys, are eligible to participate.
- Vote Uniqueness: Each voter may cast only one valid vote.
- Verifiability/Auditability: The electoral process and results must be publicly verifiable without compromising the identity of the voter, minimizing the trust required in the central tallying authority. (This central tallying authority may be comprised of a committee composed of a representative from each voting option.)
- Nostr's Role: Nostr is proposed as the underlying communication layer. Its decentralized, public/private event-based features can be used for both vote transmission and the implementation of a public bulletin board. Features such as NIP-59 Gift Wrap 2 are used to encrypt data during transmission, protecting the confidentiality of the vote in transit.

## Voters
Registered users with a Nostr key pair (public and private). The public key (voter_pk) identifies the voter to the Electoral Commission.

## Electoral Commission (EC)
- Maintains a record of the public keys of authorized voters.
- Issues anonymous voting tokens using blind signatures.
- Receives encrypted votes.
- Verifies the validity of the tokens and prevents double voting.
- Performs the final count (the counting mechanism itself is outside the scope of this blind signature scheme).

## Nostr: Communication protocol used for:
- Requesting blind signatures (via encrypted direct messages).
- Casting encrypted votes (using NIP-59 Gift Wrap).

## Voting Protocol:
### Blind Signature Request:
- A registered voter generates a unique identifier for their vote (nonce n) and calculates its hash (h_n).
- The voter "blinds" the hash h_n using a random blinding factor r and the EC's blind signing public key (pk_bs_ce).
- The voter sends the blinded hash (blinded_h_n) to the EC via an encrypted Nostr direct message, authenticating themselves with their voter_pk.

### Blind Signature Issuance by the EC:
- The EC receives the request, verifies that voter_pk is registered and has not previously requested a signature for this election.
- If valid, the EC signs the blinded hash (blinded_h_n) with their blind signing private key (sk_bs_ce), obtaining blind_sig.
- The EC internally marks that voter_pk has already received their authorization (to prevent multiple requests).
- The EC sends blind_sig back to the voter via encrypted Nostr DM.
### Token Collection and Voting:
- The voter receives the blind_sig and unblinds it using the factor r, obtaining the actual token signature on h_n. They verify that the token is valid with pk_bs_ce. The pair (h_n, token) is now their anonymous voting credential.
- The voter prepares their actual vote (vote_content) and encrypts it using NIP-59 Gift Wrap, addressed to the EC's Nostr public key.
- The voter packages the encrypted vote (encrypted_vote) along with the credential (h_n, token) and sends it to the EC via Nostr (using Gift Wrap to anonymize the transmission).
### Reception and Validation by the EC:
- The EC receives the packet sent by the voter and extracts encrypted_vote, h_n, and token.
- The EC verifies that the token is a valid signature on h_n using pk_bs_ce.
- The EC consults an internal database (used_tokens) to verify if the identifier h_n has already been used.
- If the signature is valid and h_n has not been used previously:
- The EC stores encrypted_vote for the final count.
- The EC adds h_n to the used_tokens database to mark it as used.
- If the signature is invalid or h_n has already been used, the EC discards the vote.

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
- [ ] EC receive vote
- [ ] EC Count votes and publish to Nostr
