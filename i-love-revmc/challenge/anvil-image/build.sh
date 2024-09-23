#!/bin/bash

git config --global advice.detachedHead false

git clone https://github.com/foundry-rs/foundry-fork-db.git
cd foundry-fork-db
git checkout 4cb682562f481ee2fa0cbfc55e811fea8d5fa02e
git apply ../foundry-fork-db.patch
cd ..

git clone https://github.com/paradigmxyz/revm-inspectors.git
cd revm-inspectors
git checkout c064ffaf5cb64f24f2773f3466202d6655c14a89
git apply ../revm-inspectors.patch
cd ..

git clone https://github.com/bluealloy/revm.git
cd revm
git checkout 3085f04ac6b144e7ac721abce9cbbf538ff6b7fe
git apply ../revm.patch
cd ..

git clone https://github.com/paradigmxyz/revmc.git
cd revmc
git checkout 9ad12ebe060ab25818ae1bf89febde70e08ca775
git apply ../revmc.patch
cd ..

git clone https://github.com/foundry-rs/foundry.git
cd foundry
git checkout 41d4e5437107f6f42c7711123890147bc736a609
git apply ../foundry.patch
cargo build --release --package anvil
cd ..

cd jit-compiler
clang c/linker.c -c -o libjit_dummy.o
cargo build --release
cd ..

mv jit-compiler jit-compiler-dir
cp foundry/target/release/anvil .
cp jit-compiler-dir/target/release/jit-compiler .
cp jit-compiler-dir/libjit_dummy.o .

rm -rf foundry-fork-db revm-inspectors revm revmc foundry jit-compiler-dir

# anvil path: /build/foundry/target/release/anvil
# jit-compiler path: /build/jit-compiler/target/release/jit-compiler
# dummy object: /build/jit-compiler/libjit_dummy.o