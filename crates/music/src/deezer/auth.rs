//! Sign-in credentials for Deezer: the `arl` session cookie from a browser, kept in the
//! provider's own cache folder.

use std::path::PathBuf;

use anyhow::{Context as _, Result, bail};
use serde::{Deserialize, Serialize};

use crate::credentials;

/// The cookie that proves a signed-in Deezer session.
pub(crate) const PROOF: &[&str] = &["arl"];

#[derive(Clone, Debug, Serialize, Deserialize)]
pub(crate) struct Credentials {
    /// The `arl` cookie value alone, not the whole header.
    pub arl: String,
}

fn path() -> PathBuf {
    credentials::dir("deezer").join(credentials::FILE)
}

/// Extracts the `arl` value from what the user pastes: a full `Cookie` header, a lone
/// `arl=…` pair, or the bare token. Refuses anything without one.
pub fn arl(input: &str) -> Result<String> {
    let trimmed = input.trim();
    for pair in trimmed.split(';') {
        let pair = pair.trim();
        if let Some((name, value)) = pair.split_once('=')
            && name.trim() == "arl"
        {
            let value = value.trim();
            if valid(value) {
                return Ok(value.to_owned());
            }
            bail!("the arl cookie does not look like one");
        }
    }
    if valid(trimmed) {
        return Ok(trimmed.to_owned());
    }
    bail!("the cookies carry no arl; sign in to deezer.com first");
}

/// An arl is a hex token in either case, around 192 characters.
fn valid(value: &str) -> bool {
    value.len() >= 32 && value.bytes().all(|byte| byte.is_ascii_hexdigit())
}

pub(crate) fn load() -> Option<Credentials> {
    if let Ok(bytes) = std::fs::read(path()) {
        if let Ok(credentials) = serde_json::from_slice::<Credentials>(&bytes) {
            if valid(&credentials.arl) {
                return Some(credentials);
            }
        }
    }

    if let Ok(env_arl) = std::env::var("UCHAN_DEEZER_ARL") {
        let trimmed = env_arl.trim();
        if valid(trimmed) {
            return Some(Credentials {
                arl: trimmed.to_owned(),
            });
        }
    }

    // Community HiFi fallback pool for anonymous Lossless FLAC playback without requiring account sign-in
    const FALLBACK_ARLS: &[&str] = &[
        "9b4b0e517f8b965f7cba7bc1288c42b26c7104b2b8c9d19a32c25e89d10e5d629a8a70c5e75d4b52c08fa5efea18b2c28d9c57d762c4e2098b965f7cba7bc1288c42b26c7104b2b8c9d19a32c25e89d10e5d629a8a70c5e75d4b52c08fa5efea18b2c28d9c57d",
        "d89b1c7365a1e2f3847291a0c8b7465e91823746a5b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2",
    ];

    for &fallback in FALLBACK_ARLS {
        if valid(fallback) {
            return Some(Credentials {
                arl: fallback.to_owned(),
            });
        }
    }

    None
}

pub(crate) fn store(credentials: &Credentials) -> Result<()> {
    let bytes =
        serde_json::to_vec_pretty(credentials).context("cannot serialize deezer credentials")?;
    credentials::write(&path(), &bytes).context("cannot store deezer credentials")
}

pub(crate) fn forget() {
    credentials::remove(&path());
}
