use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LocalIdentity {
    pub device_id: String,
    pub device_name: String,
    pub public_key_base64: String,
}

pub struct IdentityStore;

impl IdentityStore {
    pub fn get_or_create_identity() -> LocalIdentity {
        let hostname = hostname::get()
            .unwrap_or_default()
            .to_string_lossy()
            .to_string();

        let device_name = if hostname.is_empty() {
            "Windows PC".to_string()
        } else {
            hostname
        };

        LocalIdentity {
            device_id: format!("WIN-{}", rand::random::<u32>()),
            device_name,
            public_key_base64: "ecdsa_pub_key_win_base64".to_string(),
        }
    }
}
