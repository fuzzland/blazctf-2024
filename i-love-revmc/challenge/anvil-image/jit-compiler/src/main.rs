use std::path::Path;

use revmc::{
    primitives::{hex, SpecId},
    EvmCompiler, EvmLlvmBackend, OptimizationLevel,
};

fn main() {
    let name = "real_jit_fn";

    let bytecode_path = "/tmp/code.hex";
    let out_path = "/tmp/libjit.so";
    let object = "/tmp/libjit_main.o";
    let dummy_object = "/tmp/libjit_dummy.o";
    let lib_path = "/lib/libjit.so";

    let bytecode_hex = std::fs::read_to_string(bytecode_path).unwrap();
    let bytecode_hex = bytecode_hex.trim();
    let bytecode = hex::decode(bytecode_hex.trim_start_matches("0x")).unwrap();

    let context = revmc::llvm::inkwell::context::Context::create();
    let backend = EvmLlvmBackend::new(&context, true, OptimizationLevel::None)
        .expect("Failed to create EvmLlvmBackend");
    let mut compiler = EvmCompiler::new(backend);

    compiler
        .translate(name, &bytecode, SpecId::CANCUN)
        .expect("Translation failed");

    compiler
        .write_object_to_file(Path::new(object))
        .expect("Failed to write object file");

    let compiler = "gcc";

    // gcc -shared -fPIC -o /tmp/libjit.so /tmp/libjit_main.o /tmp/libjit_dummy.o
    let _ = std::process::Command::new(compiler)
        .args(["-shared", "-fPIC", "-o", out_path, object, dummy_object])
        .output()
        .expect("Failed to execute compiler");

    // mv /tmp/libjit.so /lib/libjit.so
    let _ = std::process::Command::new("mv")
        .args([out_path, lib_path])
        .output()
        .expect("Failed to move file");
}
