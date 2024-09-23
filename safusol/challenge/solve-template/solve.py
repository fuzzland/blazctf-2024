# sample solve script to interface with the server
import pwn

# if you don't know what this is doing, look at server code and also sol-ctf-framework read_instruction:
# https://github.com/otter-sec/sol-ctf-framework/blob/rewrite-v2/src/lib.rs#L237
# feel free to change the accounts and ix data etc. to whatever you want
account_metas = [
    ("user",           "sw"), # signer + writable
    ("program",        "-r"), # read only
    ("system program", "-r"), # read only
    ("admin",          "-r"), # read only
]

HOST = "localhost"
PORT = 1337
p = pwn.remote(HOST, PORT)

with open("build/solve.so", "rb") as f:
    solve = f.read()

p.sendlineafter(b"program pubkey: \n", b"FuzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzLand")
p.sendlineafter(b"program len: \n", str(len(solve)).encode())
p.send(solve)

accounts = {
    "system program": "11111111111111111111111111111111",
}

for l in p.recvuntil(b"num accounts: \n", drop=True).strip().split(b"\n"):
    [name, pubkey] = l.decode().split(": ")
    accounts[name] = pubkey


instruction_data = b""

p.sendline(str(len(account_metas)).encode())
for name, perms in account_metas:
    p.sendline(f"{perms} {accounts[name]}".encode())

p.sendlineafter(b"ix len: \n", str(len(instruction_data)).encode())
p.send(instruction_data)

p.interactive()