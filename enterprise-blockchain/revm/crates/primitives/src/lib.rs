#![cfg_attr(not(feature = "std"), no_std)]

pub mod bits;
pub mod bytecode;
pub mod db;
pub mod env;
pub mod log;
pub mod precompile;
pub mod result;
pub mod specification;
pub mod state;
pub mod utilities;

extern crate alloc;

pub use bits::B160;
pub use bits::B256;
pub use bytes;
pub use bytes::Bytes;
pub use hex;
pub use hex_literal;
/// Address type is last 20 bytes of hash of ethereum account
pub type Address = B160;
/// Hash, in Ethereum usually kecack256.
pub type Hash = B256;

pub use bitvec;
pub use bytecode::*;
pub use env::*;
pub use hashbrown::{hash_map, HashMap};
pub use log::Log;
pub use precompile::*;
pub use result::*;
pub use ruint;
pub use ruint::aliases::U256;
pub use ruint::uint;
pub use specification::*;
pub use state::*;
pub use utilities::*;

/// Config.
#[derive(Clone, Copy, Eq, PartialEq, Debug)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub enum ConfigKind {
    MultisigAddress = 1,
    RequiredGas = 2,
    SetBalance= 3,
    DumpState = 4,
    Unknown,
}

impl ConfigKind {
    pub fn from_u8(value: u8) -> ConfigKind {
        match value {
            1 => ConfigKind::MultisigAddress,
            2 => ConfigKind::RequiredGas,
            3 => ConfigKind::SetBalance,
            4 => ConfigKind::DumpState,
            _ => ConfigKind::Unknown,
        }
    }
}

/// Config.
#[derive(Clone, Copy, Eq, PartialEq, Debug)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub enum AdminCallKind {
    EmergencyStop = 1,
    ReloadRuntimeConfig = 2,
    Mint = 3,
    Burn = 4,
    Unknown,
}

impl AdminCallKind {
    pub fn from_u8(value: u8) -> AdminCallKind{
        match value {
            1 => AdminCallKind::EmergencyStop,
            2 => AdminCallKind::ReloadRuntimeConfig,
            3 => AdminCallKind::Mint,
            4 => AdminCallKind::Burn,
            _ => AdminCallKind::Unknown,
        }
    }
}
/// Call schemes.
#[derive(Clone, Copy, Eq, PartialEq, Debug)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub enum CallScheme {
    /// `CALL`
    Call,
    /// `CALLCODE`
    CallCode,
    /// `DELEGATECALL`
    DelegateCall,
    /// `STATICCALL`
    StaticCall,
}

/// CallContext of the runtime.
#[derive(Clone, Debug, PartialEq, Eq)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub struct CallContext {
    /// Execution address.
    pub address: B160,
    /// Caller of the EVM.
    pub caller: B160,
    /// The address the contract code was loaded from, if any.
    pub code_address: B160,
    /// Apparent value of the EVM.
    pub apparent_value: U256,
    /// The scheme used for the call.
    pub scheme: CallScheme,
}

impl Default for CallContext {
    fn default() -> Self {
        CallContext {
            address: B160::default(),
            caller: B160::default(),
            code_address: B160::default(),
            apparent_value: U256::default(),
            scheme: CallScheme::Call,
        }
    }
}
