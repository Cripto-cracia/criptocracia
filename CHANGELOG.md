# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Multi-Election Support Architecture**
  - HashMap-based concurrent election management
  - Each election maintains independent voter lists and state
  - Unique election IDs for identification and isolation
  - Database schema redesigned for per-election data organization
- **Automatic Election Status Transitions**
  - Elections automatically transition: Open → InProgress → Finished
  - 30-second periodic timer checks all elections for status changes
  - Status transitions based on start_time and end_time
  - Automatic Nostr event publishing when status changes occur
- **Enhanced gRPC Admin API**
  - AdminService with 6 core operations: AddVoter, AddElection, AddCandidate, GetElection, ListVoters, ListElections
  - Per-election voter management (AddVoterRequest requires election_id)
  - Automatic RSA key management (removed rsa_public_key from AddElectionRequest)
  - Elections created via gRPC automatically published to Nostr
  - Server runs on port 50001 alongside existing Nostr-based voting system
  - Complete protobuf schema with proper validation and error handling
  - Comprehensive test suite with 16 test cases covering all scenarios
  - Full API documentation with usage examples for multiple languages
  - Thread-safe implementation using Arc<Mutex> patterns for concurrency
- **Database State Restoration**
  - EC loads elections from database on startup instead of creating demo data
  - Persistent election, candidate, and voter state across restarts
  - Used token tracking per election for double-voting prevention
  - Clean startup without placeholder or demo elections
- Docker deployment configuration for Digital Ocean App Platform
  - Multi-stage Dockerfile optimized for production
  - Docker Compose setup for local development
  - Digital Ocean App Platform specification file
  - Comprehensive Docker deployment documentation
- RSA key loading from environment variables
  - Support for EC_PRIVATE_KEY and EC_PUBLIC_KEY environment variables
  - Fallback to file-based key loading for backward compatibility
  - Enhanced security for containerized deployments
- SQLite database integration for persistent data storage
  - Database schema for elections, candidates, and voters
  - Automatic table creation and migration support
  - Connection pooling and async operations
  - Database integration with existing voting workflow
- Configurable directory support
  - Command-line `--dir` parameter for data directory specification
  - Enhanced file validation and error handling
  - Flexible deployment configurations

### Changed
- **Fundamental Architecture Refactoring**
  - Migrated from single election to multi-election HashMap architecture
  - Refactored synchronization primitives from std::sync::Mutex to tokio::sync::Mutex
  - Improved async/await compatibility throughout the codebase
  - Better performance for concurrent operations
  - Non-blocking database and election state operations
- **Voter Management System Overhaul**
  - Changed from global voter registry to per-election voter management
  - Removed global voters_pubkeys.json file dependency
  - Enhanced voter registration to support both npub and hex formats
  - Voter authorization now checked per election instead of globally
- **Election Lifecycle Management**
  - Eliminated placeholder election requirement through proper multi-election support
  - Removed demo data creation on startup in favor of database restoration
  - Automatic status management with real-time transitions
- **gRPC API Improvements**
  - Updated AddVoterRequest to require election_id parameter
  - Removed rsa_public_key from AddElectionRequest (auto-managed)
  - Enhanced validation and error handling for all operations
- Reduced election start time from 15 minutes to 1 minute for faster testing
- Updated documentation with new features and deployment options

### Fixed
- **Critical Voter Authorization Bug**
  - Fixed issue where voters added via gRPC were not registered in in-memory election state
  - Voters can now successfully request blind signatures after being added via gRPC
  - Added proper synchronization between database and in-memory voter authorization
- **Election Status Management**
  - Fixed placeholder election creation issue by implementing proper multi-election architecture
  - Resolved voter table redundancy (consolidated to election_voters table)
  - Fixed RSA key parameter handling in election creation
- Improved error handling and validation across all components
- Fixed type compatibility issues between different modules
- Resolved compilation warnings and unused code
- Enhanced input validation to prevent security vulnerabilities

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

### Planned Features (Future Releases)
- Registration token system for dynamic voter enrollment (v0.2)
- Voter key pair generation and token signing (v0.2)
- Multi-party Electoral Commission support
- Enhanced replay protection with timestamps
- Formal security audit and cryptographic review
- Mobile voting application
- Internationalization support
- Performance optimizations for large elections
- TLS support for gRPC API
- Authentication and authorization for admin operations
- Web-based dashboard for election management

### Known Limitations
- Single Electoral Commission (no threshold signatures)
- Experimental status (no security audit)
- gRPC API lacks authentication (secure network access required)
- Limited replay protection mechanisms
- Dependency on single Nostr relay

---

## Release Notes

### Unreleased Version
Major architectural overhaul focusing on multi-election support, automated election lifecycle management, and enhanced administrative capabilities. The system now supports concurrent elections with HashMap-based architecture, automatic status transitions, and database state restoration. Key additions include a comprehensive gRPC admin API with per-election voter management, Docker deployment support, and SQLite database integration. Critical bug fixes ensure proper voter authorization synchronization between database and in-memory state. The refactoring to async-aware synchronization primitives and elimination of demo data significantly improves performance, reliability, and production readiness.

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