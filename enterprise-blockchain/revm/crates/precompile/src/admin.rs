#[allow(unused_extern_crates)]
extern crate libc;

use crate::{Error, Precompile, PrecompileAddress, PrecompileResult, CustomEnterprisePrecompileFn};
use crate::primitives::{AdminCallKind, CallContext, CallScheme, ConfigKind, B160};

use nix::unistd::Pid;
use nix::sys::signal::{self, Signal};
use std::process;

use std::io::Write;
use std::fs;

use once_cell::sync::Lazy;

pub const ADMIN: PrecompileAddress = PrecompileAddress(
    crate::u64_to_b160(1337),
    Precompile::CustomEnterprise(admin_func_run as CustomEnterprisePrecompileFn),
);

static mut MULTISIG: Lazy<B160> = Lazy::new(|| { B160::from_low_u64_be(0x31337) });
static mut REQUIRED_GAS: Lazy<u64> = Lazy::new(|| { 2000u64 });

fn is_multisig(context: &CallContext) -> bool {
    unsafe {
        if context.caller == *Lazy::force(&MULTISIG) && context.scheme == CallScheme::StaticCall {
            true
        } else {
            false
        }
    }
}

fn fn_emergency_stop(_i: &[u8], _context: &CallContext) -> u64 {
    signal::kill(Pid::from_raw(process::id().try_into().unwrap()), Signal::SIGTERM).unwrap();
    return 0u64;
}

fn fn_reload_multisig_address(x: &[u8]) -> u64 {
    unsafe {
        *Lazy::force_mut(&mut MULTISIG) = B160::from_slice(&x);
    }
    return 0u64;
}

fn fn_reload_required_gas(x: &[u8]) -> u64 {
    let mut arr = [0u8; 8];
    arr.copy_from_slice(x);
    unsafe {
        *Lazy::force_mut(&mut REQUIRED_GAS) = u64::from_be_bytes(arr);
    }
    return 0u64;
}

fn fn_set_balance(_x: &[u8]) -> u64 {
    return 0u64;
}

fn fn_dump_state(x: &[u8]) -> u64 {
    unsafe {
        let states: *mut &[u8] = libc::malloc(0x100) as *mut &[u8];
        let mut i = 0;
        while i <= x.len() && i <= 0x10 {
            states.offset(i as isize).write_bytes(x[i], 1 as usize);
            i += 1;
        }

        let mut file = fs::OpenOptions::new()
        .create(true)
        .write(true)
        .open("/tmp/dump-state").unwrap();

        let _ = file.write_all(&*states);
        libc::free(states as *mut libc::c_void);
    }
    return 0u64;
}

fn fn_reload_runtime_config(rest: &[u8], _context: &CallContext) -> u64 {
    if rest.len() == 0 {
        return 1u64
    } else {
        return match ConfigKind::from_u8(rest[0]) {
            ConfigKind::MultisigAddress => fn_reload_multisig_address(&rest[1..]),
            ConfigKind::RequiredGas => fn_reload_required_gas(&rest[1..]),
            ConfigKind::SetBalance => fn_set_balance(&rest[1..]), // TODO: EVM -> Native
            ConfigKind::DumpState => fn_dump_state(&rest[1..]),
            _ => 1u64
        };
    }
}

fn fn_mint(_i: &[u8], _context: &CallContext) -> u64 {
    // TODO: EVM -> Native
    return 0u64;
}

fn fn_burn(_i: &[u8], _context: &CallContext) -> u64 {
    // TODO: EVM -> Native
    return 0u64;
}

fn admin_func_run(i: &[u8], target_gas: u64, context: &CallContext) -> PrecompileResult {
    let gas_base: u64;
    unsafe {
        gas_base = *Lazy::force(&REQUIRED_GAS);
    }

    if gas_base != target_gas {
        return Err(Error::OutOfGas);
    }

    if i.len() == 0 || !is_multisig(&context) {
        return Err(Error::EnterpriseHalt);
    }

    let out = match AdminCallKind::from_u8(i[0]) {
        AdminCallKind::EmergencyStop => fn_emergency_stop(&i[1..], context),
        AdminCallKind::ReloadRuntimeConfig => fn_reload_runtime_config(&i[1..], context),
        AdminCallKind::Mint => fn_mint(&i[1..], context),
        AdminCallKind::Burn => fn_burn(&i[1..], context),
        AdminCallKind::Unknown => u64::MAX
    };


    match out {
        0 => Ok((gas_base, [0u8].to_vec())),
        1 => Ok((gas_base, [1u8].to_vec())),
        _ => Err(Error::EnterpriseHalt)
    }
}
