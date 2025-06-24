# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2024-01-XX

### Added
- Support for both npub and hex formats in voter registration
- Comprehensive test suite for election logic and blind signature flow
- RSA public key publishing on Nostr events
- Real-time election status updates based on start/end times
- Vote result publishing with live updates
- Message type system for better data handling
- Validation for vote reception
- Demo RSA keys for testing

### Changed
- Improved error handling to avoid panics
- Refactored code organization and structure
- Enhanced UI layout and candidate display
- Updated README documentation with Nostr event examples
- Better formatting of election results
- Removed unused RSA crate dependency

### Fixed
- RSA public key parsing error handling
- Election status transitions based on time
- Token validation and blind signature flow
- Message handling and JSON parsing

## [0.1.0] - 2024-01-XX

### Added
- Initial implementation of Criptocracia voting system
- Electoral Commission (EC) service with blind signature support
- Voter client with terminal UI (TUI) interface
- Blind RSA signature protocol implementation
- Nostr protocol integration with NIP-59 Gift Wrap encryption
- Voter registration system with pubkey management
- Election management with candidate lists
- Vote tallying and result publication
- Async event handling for Nostr messages
- Configuration management for voter settings
- Logging system with configurable levels
- Demo data and test keys

### Core Features
- **Blind Signatures**: Anonymous voting tokens using RSA blind signatures
- **Nostr Integration**: Decentralized communication via Nostr relays
- **Vote Privacy**: Voter choices hidden from Electoral Commission
- **Double Voting Prevention**: Nonce-based replay protection
- **Public Verifiability**: Election results published to Nostr
- **Real-time Updates**: Live vote tallies and election status

### Security Properties
- Vote secrecy through cryptographic blinding
- Voter authentication via Nostr public keys
- Anonymous vote casting with ephemeral keypairs
- Public audit trail through Nostr events

### Technical Implementation
- Rust workspace with two binaries (ec, voter)
- Dependencies: blind-rsa-signatures, nostr-sdk, ratatui
- RSA-2048 key generation for blind signatures
- SHA-256 hashing for nonce generation
- Base64 encoding for message transport
- JSON serialization for structured data

### Documentation
- Comprehensive README with setup instructions
- Individual README files for EC and voter components
- TODO list tracking development progress
- Code documentation and examples

### Development Infrastructure
- Cargo workspace configuration
- Shared dependencies management
- Test framework setup
- Git repository with structured commits
- Issue tracking and pull request workflow

## [Unreleased]

### Planned Features
- Registration token system for dynamic voter enrollment (v0.2)
- Voter key pair generation and token signing (v0.2)
- Multi-party Electoral Commission support
- Enhanced replay protection with timestamps
- Formal security audit and cryptographic review
- Mobile voting application
- Internationalization support
- Performance optimizations for large elections

### Known Limitations
- Single Electoral Commission (no threshold signatures)
- Experimental status (no security audit)
- Manual voter registration process
- Limited replay protection mechanisms
- Dependency on single Nostr relay

---

## Release Notes

### Version 0.1.1
This release focuses on stability improvements and enhanced voter registration support. The major addition is support for both npub (Bech32) and hex formats for voter public keys, making the system more user-friendly. Comprehensive testing was added to ensure cryptographic operations work correctly.

### Version 0.1.0
The initial release of Criptocracia implements the core blind signature voting protocol with Nostr integration. This is an experimental release intended for research and demonstration purposes. The system successfully demonstrates anonymous voting with public verifiability, though it has not undergone formal security review.

### Development History
The project evolved through several major milestones:
1. **Foundation** (Jan 2024): Initial project structure and basic Rust workspace
2. **Crypto Integration** (Jan 2024): Blind RSA signature implementation
3. **Nostr Protocol** (Jan 2024): Integration with decentralized messaging
4. **User Interface** (Jan 2024): Terminal-based voter client
5. **Mobile Development** (Jan-Feb 2024): Flutter mobile app (later removed)
6. **Stability** (Feb 2024): Error handling and test coverage improvements

The project demonstrates a working prototype of cryptographic voting with novel use of the Nostr protocol for decentralized election infrastructure.