#include <solana_sdk.h>

#define HEAP_START_ADDRESS_ (uint64_t)0x300000000
#define HEAP_LENGTH_ (uint64_t)(32 * 1024)
#define HEAP_END_ADDRESS_ (HEAP_START_ADDRESS_ + HEAP_LENGTH_)

#define ERROR_BLAZ 42

#define CALLER 0
#define DATA_ACCOUNT 1
#define PROGRAM_ID 2
#define SYSTEM_ID 3

#define INIT 0
#define DEPOSIT 1
#define WITHDRAW 2

typedef struct __attribute__((packed)) {
    uint8_t bump;
    uint8_t type;
    uint64_t amount;
    uint64_t msg_size;
    uint8_t msg[0];
} UserInput;

typedef struct BlazAllocator {
    uint64_t free_ptr;
} BlazAllocator;

BlazAllocator *init_allocator();
void *malloc(BlazAllocator *self, uint64_t size);

uint64_t memcmp(const void *s1, const void *s2, uint64_t n);
void memcpy(void *dst, const void *src, uint64_t size);
uint64_t strlen(const char *str);
void strcpy(char *dst, const char *src);

extern uint64_t entrypoint(const uint8_t *input) {
    // User provided keys
    SolPubkey caller_key;
    SolPubkey data_account_key;
    SolPubkey program_id;
    SolPubkey system_id;

    uint8_t seed[] = {'B', 'L', 'A', 'Z'};
    uint8_t user_bump;

    const SolSignerSeed seeds[] = {{seed, SOL_ARRAY_SIZE(seed)},
                                   {&user_bump, 1}};
    SolPubkey data_account_key_verify;

    uint8_t len_actions;

    SolAccountInfo accounts[4];
    SolParameters params = (SolParameters){.ka = accounts};

    BlazAllocator *allocator = init_allocator();

    if (!sol_deserialize(input, &params, SOL_ARRAY_SIZE(accounts))) {
        return ERROR_INVALID_ARGUMENT;
    }

    memcpy(&caller_key, accounts[CALLER].key, SIZE_PUBKEY);
    memcpy(&data_account_key, accounts[DATA_ACCOUNT].key, SIZE_PUBKEY);
    memcpy(&program_id, accounts[PROGRAM_ID].key, SIZE_PUBKEY);
    memcpy(&system_id, accounts[SYSTEM_ID].key, SIZE_PUBKEY);

    if (!accounts[CALLER].is_signer) {
        return ERROR_BLAZ;
    }

    if (memcmp(&program_id, params.program_id, SIZE_PUBKEY) != 0) {
        return ERROR_BLAZ;
    }

    len_actions = params.data[0];
    if (len_actions == 0 || len_actions > 3) {
        return ERROR_BLAZ;
    }

    uint64_t offset = 1;

    while (len_actions--) {
        UserInput *current_input = (UserInput *)(params.data + offset);

        offset += sizeof(uint8_t);
        user_bump = current_input->bump;
        if (sol_create_program_address(seeds, SOL_ARRAY_SIZE(seeds),
                                       &program_id,
                                       &data_account_key_verify) != SUCCESS) {
            return ERROR_BLAZ;
        }

        if (memcmp(&data_account_key, &data_account_key_verify, SIZE_PUBKEY) !=
            0) {
            return ERROR_BLAZ;
        }

        offset += sizeof(uint8_t);
        switch (current_input->type) {
            case INIT: {
                if (accounts[DATA_ACCOUNT].data_len != 0) {
                    return ERROR_BLAZ;
                }

                // create data account
                {
                    SolAccountMeta arguments[] = {
                        {&caller_key, true, true},
                        {&data_account_key, true, true}};
                    uint8_t creation_ix_data[4 + 8 + 8 + SIZE_PUBKEY];
                    *(uint64_t *)(creation_ix_data + 4) =
                        10000000000;  // 10 SOL
                    *(uint64_t *)(creation_ix_data + 4 + 8) =
                        MAX_PERMITTED_DATA_INCREASE;
                    memcpy(creation_ix_data + 4 + 8 + 8, &program_id,
                           SIZE_PUBKEY);

                    const SolInstruction instruction = {
                        &system_id, arguments, SOL_ARRAY_SIZE(arguments),
                        creation_ix_data, SOL_ARRAY_SIZE(creation_ix_data)};
                    const SolSignerSeeds signers_seeds[] = {
                        {seeds, SOL_ARRAY_SIZE(seeds)}};

                    if (sol_invoke_signed(
                            &instruction, accounts, SOL_ARRAY_SIZE(accounts),
                            signers_seeds,
                            SOL_ARRAY_SIZE(signers_seeds)) != SUCCESS) {
                        return ERROR_BLAZ;
                    }

                    accounts[DATA_ACCOUNT].data_len = SIZE_PUBKEY;
                    memcpy(accounts[DATA_ACCOUNT].data, &caller_key,
                           SIZE_PUBKEY);
                }

                break;
            }
            case DEPOSIT: {
                offset += sizeof(uint64_t);
                uint64_t amount = current_input->amount;
                offset += sizeof(uint64_t);
                char *message =
                    (char *)malloc(allocator, current_input->msg_size);

                if (message != NULL) {
                    strcpy(message, (char *)&current_input->msg);
                    offset += strlen(message) + 1;
                }

                // transfer the amount from caller to data account
                {
                    SolAccountMeta arguments[] = {
                        {accounts[CALLER].key, true, true},
                        {accounts[DATA_ACCOUNT].key, true, false}};
                    uint8_t transfer_ix_data[] = {2, 0, 0, 0, 0, 0,
                                                  0, 0, 0, 0, 0, 0};

                    *(uint64_t *)(transfer_ix_data + 4) = amount;
                    const SolInstruction instruction = {
                        &system_id, arguments, SOL_ARRAY_SIZE(arguments),
                        transfer_ix_data, SOL_ARRAY_SIZE(transfer_ix_data)};

                    if (sol_invoke(&instruction, accounts,
                                   SOL_ARRAY_SIZE(accounts)) != SUCCESS) {
                        return ERROR_BLAZ;
                    }
                }
                break;
            }
            case WITHDRAW: {
                offset += sizeof(uint64_t);
                uint64_t amount = current_input->amount;
                offset += sizeof(uint64_t);
                char *message =
                    (char *)malloc(allocator, current_input->msg_size);

                if (message != NULL) {
                    strcpy(message, (char *)&current_input->msg);
                    offset += strlen(message) + 1;
                }

                // only owner can withdraw
                if (memcmp(accounts[DATA_ACCOUNT].data, &caller_key,
                           SIZE_PUBKEY) != 0) {
                    return ERROR_BLAZ;
                }

                *accounts[DATA_ACCOUNT].lamports -= amount;
                *accounts[CALLER].lamports += amount;
                break;
            }
            default:
                return ERROR_BLAZ;
        }
    }

    return SUCCESS;
}

BlazAllocator *init_allocator() {
    BlazAllocator *allocator = (BlazAllocator *)HEAP_START_ADDRESS_;
    allocator->free_ptr = HEAP_START_ADDRESS_ + sizeof(BlazAllocator);
    return allocator;
}

void *malloc(BlazAllocator *self, uint64_t size) {
    if (size == 0) {
        return NULL;
    }

    uint64_t size_aligned = (size + 7) & ~7;

    if (self->free_ptr + size_aligned > HEAP_END_ADDRESS_) {
        return NULL;
    }

    uint64_t *ptr = (uint64_t *)self->free_ptr;
    self->free_ptr += size_aligned;

    return ptr;
}

uint64_t memcmp(const void *s1, const void *s2, uint64_t n) {
    const uint8_t *p1 = (const uint8_t *)s1;
    const uint8_t *p2 = (const uint8_t *)s2;
    for (uint64_t i = 0; i < n; i++) {
        if (p1[i] != p2[i]) {
            return p1[i] - p2[i];
        }
    }
    return 0;
}

void memcpy(void *dst, const void *src, uint64_t size) {
    uint8_t *dst8 = (uint8_t *)dst;
    const uint8_t *src8 = (const uint8_t *)src;
    for (uint64_t i = 0; i < size; i++) {
        dst8[i] = src8[i];
    }
}

uint64_t strlen(const char *str) {
    uint64_t len = 0;
    while (str[len] != '\0') {
        len++;
    }
    return len;
}

void strcpy(char *dst, const char *src) {
    uint64_t i = 0;
    while (src[i] != '\0') {
        dst[i] = src[i];
        i++;
    }
    dst[i] = '\0';
}