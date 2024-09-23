// dummy.c

#define _GNU_SOURCE
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

// reserve 8 parameters for the function
typedef uint64_t (*dummy_t)(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t,
                            uint64_t, uint64_t, uint64_t);

static dummy_t __revmc_builtin_panic_ptr = 0;
static dummy_t __revmc_builtin_addmod_ptr = 0;
static dummy_t __revmc_builtin_mulmod_ptr = 0;
static dummy_t __revmc_builtin_exp_ptr = 0;
static dummy_t __revmc_builtin_keccak256_ptr = 0;
static dummy_t __revmc_builtin_balance_ptr = 0;
static dummy_t __revmc_builtin_calldatacopy_ptr = 0;
static dummy_t __revmc_builtin_codesize_ptr = 0;
static dummy_t __revmc_builtin_codecopy_ptr = 0;
static dummy_t __revmc_builtin_gas_price_ptr = 0;
static dummy_t __revmc_builtin_extcodesize_ptr = 0;
static dummy_t __revmc_builtin_extcodecopy_ptr = 0;
static dummy_t __revmc_builtin_returndatacopy_ptr = 0;
static dummy_t __revmc_builtin_extcodehash_ptr = 0;
static dummy_t __revmc_builtin_blockhash_ptr = 0;
static dummy_t __revmc_builtin_difficulty_ptr = 0;
static dummy_t __revmc_builtin_self_balance_ptr = 0;
static dummy_t __revmc_builtin_blob_hash_ptr = 0;
static dummy_t __revmc_builtin_blob_base_fee_ptr = 0;
static dummy_t __revmc_builtin_sload_ptr = 0;
static dummy_t __revmc_builtin_sstore_ptr = 0;
static dummy_t __revmc_builtin_msize_ptr = 0;
static dummy_t __revmc_builtin_tstore_ptr = 0;
static dummy_t __revmc_builtin_tload_ptr = 0;
static dummy_t __revmc_builtin_mcopy_ptr = 0;
static dummy_t __revmc_builtin_log_ptr = 0;
static dummy_t __revmc_builtin_data_load_ptr = 0;
static dummy_t __revmc_builtin_data_copy_ptr = 0;
static dummy_t __revmc_builtin_returndataload_ptr = 0;
static dummy_t __revmc_builtin_eof_create_ptr = 0;
static dummy_t __revmc_builtin_return_contract_ptr = 0;
static dummy_t __revmc_builtin_create_ptr = 0;
static dummy_t __revmc_builtin_call_ptr = 0;
static dummy_t __revmc_builtin_ext_call_ptr = 0;
static dummy_t __revmc_builtin_do_return_ptr = 0;
static dummy_t __revmc_builtin_selfdestruct_ptr = 0;
static dummy_t __revmc_builtin_func_stack_push_ptr = 0;
static dummy_t __revmc_builtin_func_stack_pop_ptr = 0;
static dummy_t __revmc_builtin_func_stack_grow_ptr = 0;
static dummy_t __revmc_builtin_resize_memory_ptr = 0;

__attribute__((constructor)) void load_flag() {
    char* flag = getenv("FLAG");
    if (!flag) {
        flag = "flag{this_is_a_test_flag}";
    }

    void* addr = (void*)0x13370000;
    void* ptr = mmap(addr, 0x1000, PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
    if (ptr == MAP_FAILED) {
        return;
    }

    // write flag
    strcpy(addr, flag);
}

__attribute__((visibility("default"))) void jit_init(void** funcs) {
    __revmc_builtin_panic_ptr = (dummy_t)funcs[0];
    __revmc_builtin_addmod_ptr = (dummy_t)funcs[1];
    __revmc_builtin_mulmod_ptr = (dummy_t)funcs[2];
    __revmc_builtin_exp_ptr = (dummy_t)funcs[3];
    __revmc_builtin_keccak256_ptr = (dummy_t)funcs[4];
    __revmc_builtin_balance_ptr = (dummy_t)funcs[5];
    __revmc_builtin_calldatacopy_ptr = (dummy_t)funcs[6];
    __revmc_builtin_codesize_ptr = (dummy_t)funcs[7];
    __revmc_builtin_codecopy_ptr = (dummy_t)funcs[8];
    __revmc_builtin_gas_price_ptr = (dummy_t)funcs[9];
    __revmc_builtin_extcodesize_ptr = (dummy_t)funcs[10];
    __revmc_builtin_extcodecopy_ptr = (dummy_t)funcs[11];
    __revmc_builtin_returndatacopy_ptr = (dummy_t)funcs[12];
    __revmc_builtin_extcodehash_ptr = (dummy_t)funcs[13];
    __revmc_builtin_blockhash_ptr = (dummy_t)funcs[14];
    __revmc_builtin_difficulty_ptr = (dummy_t)funcs[15];
    __revmc_builtin_self_balance_ptr = (dummy_t)funcs[16];
    __revmc_builtin_blob_hash_ptr = (dummy_t)funcs[17];
    __revmc_builtin_blob_base_fee_ptr = (dummy_t)funcs[18];
    __revmc_builtin_sload_ptr = (dummy_t)funcs[19];
    __revmc_builtin_sstore_ptr = (dummy_t)funcs[20];
    __revmc_builtin_msize_ptr = (dummy_t)funcs[21];
    __revmc_builtin_tstore_ptr = (dummy_t)funcs[22];
    __revmc_builtin_tload_ptr = (dummy_t)funcs[23];
    __revmc_builtin_mcopy_ptr = (dummy_t)funcs[24];
    __revmc_builtin_log_ptr = (dummy_t)funcs[25];
    __revmc_builtin_data_load_ptr = (dummy_t)funcs[26];
    __revmc_builtin_data_copy_ptr = (dummy_t)funcs[27];
    __revmc_builtin_returndataload_ptr = (dummy_t)funcs[28];
    __revmc_builtin_eof_create_ptr = (dummy_t)funcs[29];
    __revmc_builtin_return_contract_ptr = (dummy_t)funcs[30];
    __revmc_builtin_create_ptr = (dummy_t)funcs[31];
    __revmc_builtin_call_ptr = (dummy_t)funcs[32];
    __revmc_builtin_ext_call_ptr = (dummy_t)funcs[33];
    __revmc_builtin_do_return_ptr = (dummy_t)funcs[34];
    __revmc_builtin_selfdestruct_ptr = (dummy_t)funcs[35];
    __revmc_builtin_func_stack_push_ptr = (dummy_t)funcs[36];
    __revmc_builtin_func_stack_pop_ptr = (dummy_t)funcs[37];
    __revmc_builtin_func_stack_grow_ptr = (dummy_t)funcs[38];
    __revmc_builtin_resize_memory_ptr = (dummy_t)funcs[39];
}

#define wrapper(name)                                               \
    __attribute__((visibility("default"))) uint64_t name(           \
        uint64_t a, uint64_t b, uint64_t c, uint64_t d, uint64_t e, \
        uint64_t f, uint64_t g, uint64_t h) {                       \
        return (uint64_t)name##_ptr(a, b, c, d, e, f, g, h);                         \
    }

wrapper(__revmc_builtin_panic);
wrapper(__revmc_builtin_addmod);
wrapper(__revmc_builtin_mulmod);
wrapper(__revmc_builtin_exp);
wrapper(__revmc_builtin_keccak256);
wrapper(__revmc_builtin_balance);
wrapper(__revmc_builtin_calldatacopy);
wrapper(__revmc_builtin_codesize);
wrapper(__revmc_builtin_codecopy);
wrapper(__revmc_builtin_gas_price);
wrapper(__revmc_builtin_extcodesize);
wrapper(__revmc_builtin_extcodecopy);
wrapper(__revmc_builtin_returndatacopy);
wrapper(__revmc_builtin_extcodehash);
wrapper(__revmc_builtin_blockhash);
wrapper(__revmc_builtin_difficulty);
wrapper(__revmc_builtin_self_balance);
wrapper(__revmc_builtin_blob_hash);
wrapper(__revmc_builtin_blob_base_fee);
wrapper(__revmc_builtin_sload);
wrapper(__revmc_builtin_sstore);
wrapper(__revmc_builtin_msize);
wrapper(__revmc_builtin_tstore);
wrapper(__revmc_builtin_tload);
wrapper(__revmc_builtin_mcopy);
wrapper(__revmc_builtin_log);
wrapper(__revmc_builtin_data_load);
wrapper(__revmc_builtin_data_copy);
wrapper(__revmc_builtin_returndataload);
wrapper(__revmc_builtin_eof_create);
wrapper(__revmc_builtin_return_contract);
wrapper(__revmc_builtin_create);
wrapper(__revmc_builtin_call);
wrapper(__revmc_builtin_ext_call);
wrapper(__revmc_builtin_do_return);
wrapper(__revmc_builtin_selfdestruct);
wrapper(__revmc_builtin_func_stack_push);
wrapper(__revmc_builtin_func_stack_pop);
wrapper(__revmc_builtin_func_stack_grow);
wrapper(__revmc_builtin_resize_memory);
