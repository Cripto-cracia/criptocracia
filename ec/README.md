# Criptocracia - Electoral Commission

![logo](../logo.png)

*Disclaimer: The author is NOT a cryptographer and this work has not been reviewed. This means that there is very likely a fatal flaw somewhere. Criptocracia is still experimental and not production-ready.*

---

## Prerequisites

* Rust toolchain (>= 1.86.0)
* Nostr relay endpoint (e.g., `wss://relay.mostro.network`)

Ensure you have Git and Cargo installed. Clone the repository:

```sh
git clone https://github.com/grunch/criptocracia.git
cd criptocracia/ec
```

---

## Install dependencies

To compile on Ubuntu/Pop!\_OS, please install [cargo](https://www.rust-lang.org/tools/install), then run the following commands:

```bash
sudo apt update
sudo apt install -y cmake build-essential libsqlite3-dev pkg-config libssl-dev protobuf-compiler ca-certificates
```

## Building the Project

From the workspace root:

```sh
# Build both binaries in release mode
cargo build --release
```

The binary will be in `target/release/ec`.

---

## Configuration

In order to work with blind signatures we need to create a RSA private key

```sh
# 1) Generate private key (RSA 2048 bits)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out ec_private.pem

# 2) Extract the public key
openssl rsa -in ec_private.pem -pubout -out ec_public.pem
```

Now you can share publicly the public key to all voters, they need to include it in their voter client.

To simplify the testing of this project we have already created a couple of keys and included them in this repository.

---

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
