#include <solana_sdk.h>

#define ERROR_BLAZ 42

#define CALLER 0
#define VAULT_ACCOUNT 1
#define BALANCE_ACCOUNT 2
#define PROGRAM_ID 3
#define SYSTEM_ID 4
#define CONFIG_ACCOUNT 5

#define NUM_ACCOUNTS 6

#define INIT 0xe1c7392a
#define REGISTER 0x1aa3a008
#define DEPOSIT 0xb6b55f25
#define WITHDRAW 0x2e1a7d4d
#define TOGGLE 0x40a3d246

typedef struct __attribute__((packed)) {
    uint32_t selector;
    uint8_t data[0];
} Calldata;

typedef struct __attribute__((packed)) {
    uint8_t owner[SIZE_PUBKEY];
    bool locked;
} ConfigAccount;

typedef struct __attribute__((packed)) {
    uint64_t balance;
} BalanceAccount;

uint64_t memcmp(const void *s1, const void *s2, uint64_t n);
void memcpy(void *dst, const void *src, uint64_t size);

uint64_t init(uint8_t *data, SolAccountInfo *accounts);
uint64_t register_user(uint8_t *data, SolAccountInfo *accounts);
uint64_t deposit(uint8_t *data, SolAccountInfo *accounts);
uint64_t withdraw(uint8_t *data, SolAccountInfo *accounts);
uint64_t toggle(uint8_t *data, SolAccountInfo *accounts);

extern uint64_t entrypoint(const uint8_t *input) {
    SolAccountInfo accounts[NUM_ACCOUNTS];
    SolParameters params = (SolParameters){.ka = accounts};

    if (!sol_deserialize(input, &params, NUM_ACCOUNTS)) {
        return ERROR_BLAZ;
    }

    if (memcmp(accounts[PROGRAM_ID].key, params.program_id, SIZE_PUBKEY) != 0) {
        return ERROR_BLAZ;
    }

    if (accounts[CALLER].is_signer == false) {
        return ERROR_BLAZ;
    }

    Calldata *input_data = (Calldata *)params.data;

    uint32_t selector = input_data->selector;

    switch (selector) {
        case INIT: {
            if (*accounts[VAULT_ACCOUNT].lamports != 0 ||
                accounts[CONFIG_ACCOUNT].data_len != 0) {
                return ERROR_BLAZ;
            }

            return init((uint8_t *)&input_data->data,
                        (SolAccountInfo *)&accounts);
        }
        case REGISTER: {
            if (memcmp(accounts[VAULT_ACCOUNT].owner, params.program_id,
                       SIZE_PUBKEY) != 0 ||
                accounts[BALANCE_ACCOUNT].data_len != 0) {
                return ERROR_BLAZ;
            }

            return register_user((uint8_t *)&input_data->data,
                                 (SolAccountInfo *)&accounts);
        }
        case DEPOSIT: {
            if (memcmp(accounts[VAULT_ACCOUNT].owner, params.program_id,
                       SIZE_PUBKEY) != 0 ||
                memcmp(accounts[BALANCE_ACCOUNT].owner, params.program_id,
                       SIZE_PUBKEY) != 0 ||
                accounts[BALANCE_ACCOUNT].data_len == 0) {
                return ERROR_BLAZ;
            }

            return deposit((uint8_t *)&input_data->data,
                           (SolAccountInfo *)&accounts);
        }
        case WITHDRAW: {
            if (memcmp(accounts[VAULT_ACCOUNT].owner, params.program_id,
                       SIZE_PUBKEY) != 0 ||
                memcmp(accounts[BALANCE_ACCOUNT].owner, params.program_id,
                       SIZE_PUBKEY) != 0 ||
                memcmp(accounts[CONFIG_ACCOUNT].owner, params.program_id,
                       SIZE_PUBKEY) != 0 ||
                accounts[BALANCE_ACCOUNT].data_len == 0 ||
                accounts[CONFIG_ACCOUNT].data_len == 0) {
                return ERROR_BLAZ;
            }

            return withdraw((uint8_t *)&input_data->data,
                            (SolAccountInfo *)&accounts);
        }
        case TOGGLE: {
            if (memcmp(accounts[CONFIG_ACCOUNT].owner, params.program_id,
                       SIZE_PUBKEY) != 0 ||
                accounts[CONFIG_ACCOUNT].data_len == 0) {
                return ERROR_BLAZ;
            }

            return toggle((uint8_t *)&input_data->data,
                          (SolAccountInfo *)&accounts);
        }
    }
    return SUCCESS;
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

uint64_t init(uint8_t *data, SolAccountInfo *accounts) {
    {
        uint8_t vault_seed[] = {'V', 'A', 'U', 'L', 'T'};

        uint8_t user_bump = data[0];
        const SolSignerSeed seeds[] = {{vault_seed, SOL_ARRAY_SIZE(vault_seed)},
                                       {&user_bump, 1}};
        SolAccountMeta arguments[] = {
            {accounts[CALLER].key, true, true},
            {accounts[VAULT_ACCOUNT].key, true, true}};

        uint8_t creation_ix_data[4 + 8 + 8 + SIZE_PUBKEY];
        *(uint64_t *)(creation_ix_data + 4) = 10000000000;  // 10 SOL
        *(uint64_t *)(creation_ix_data + 4 + 8) = MAX_PERMITTED_DATA_INCREASE;
        memcpy(creation_ix_data + 4 + 8 + 8, accounts[PROGRAM_ID].key,
               SIZE_PUBKEY);

        const SolInstruction instruction = {
            accounts[SYSTEM_ID].key, arguments, SOL_ARRAY_SIZE(arguments),
            creation_ix_data, SOL_ARRAY_SIZE(creation_ix_data)};

        const SolSignerSeeds signers_seeds[] = {{seeds, SOL_ARRAY_SIZE(seeds)}};

        if (sol_invoke_signed(&instruction, accounts, NUM_ACCOUNTS,
                              signers_seeds,
                              SOL_ARRAY_SIZE(signers_seeds)) != SUCCESS) {
            return ERROR_BLAZ;
        }
    }

    {
        uint8_t config_seed[] = {'C', 'O', 'N', 'F', 'I', 'G'};

        uint8_t user_bump = data[1];
        const SolSignerSeed seeds[] = {
            {config_seed, SOL_ARRAY_SIZE(config_seed)}, {&user_bump, 1}};
        SolAccountMeta arguments[] = {
            {accounts[CALLER].key, true, true},
            {accounts[CONFIG_ACCOUNT].key, true, true}};

        uint8_t creation_ix_data[4 + 8 + 8 + SIZE_PUBKEY];
        *(uint64_t *)(creation_ix_data + 4) = 1000000000;  // 1 SOL
        *(uint64_t *)(creation_ix_data + 4 + 8) = MAX_PERMITTED_DATA_INCREASE;
        memcpy(creation_ix_data + 4 + 8 + 8, accounts[PROGRAM_ID].key,
               SIZE_PUBKEY);

        const SolInstruction instruction = {
            accounts[SYSTEM_ID].key, arguments, SOL_ARRAY_SIZE(arguments),
            creation_ix_data, SOL_ARRAY_SIZE(creation_ix_data)};

        const SolSignerSeeds signers_seeds[] = {{seeds, SOL_ARRAY_SIZE(seeds)}};

        if (sol_invoke_signed(&instruction, accounts, NUM_ACCOUNTS,
                              signers_seeds,
                              SOL_ARRAY_SIZE(signers_seeds)) != SUCCESS) {
            return ERROR_BLAZ;
        }

        ConfigAccount *config = (ConfigAccount *)accounts[CONFIG_ACCOUNT].data;
        memcpy(config->owner, accounts[CALLER].key, SIZE_PUBKEY);
        config->locked = true;
    }

    return SUCCESS;
}

uint64_t register_user(uint8_t *data, SolAccountInfo *accounts) {
    uint8_t balance_seed[] = {'B', 'A', 'L', 'A', 'N', 'C', 'E'};

    // do the register
    {
        uint8_t bump = data[0];
        uint8_t user_key[SIZE_PUBKEY];
        memcpy(user_key, accounts[CALLER].key, SIZE_PUBKEY);

        const SolSignerSeed seeds[] = {
            {balance_seed, SOL_ARRAY_SIZE(balance_seed)},
            {user_key, SIZE_PUBKEY},
            {&bump, 1}};

        SolAccountMeta arguments[] = {
            {accounts[CALLER].key, true, true},
            {accounts[BALANCE_ACCOUNT].key, true, true}};

        uint8_t creation_ix_data[4 + 8 + 8 + SIZE_PUBKEY];
        *(uint64_t *)(creation_ix_data + 4) = 0;
        *(uint64_t *)(creation_ix_data + 4 + 8) = MAX_PERMITTED_DATA_INCREASE;
        memcpy(creation_ix_data + 4 + 8 + 8, accounts[PROGRAM_ID].key,
               SIZE_PUBKEY);

        const SolInstruction instruction = {
            accounts[SYSTEM_ID].key, arguments, SOL_ARRAY_SIZE(arguments),
            creation_ix_data, SOL_ARRAY_SIZE(creation_ix_data)};
        const SolSignerSeeds signers_seeds[] = {{seeds, SOL_ARRAY_SIZE(seeds)}};

        if (sol_invoke_signed(&instruction, accounts, NUM_ACCOUNTS,
                              signers_seeds,
                              SOL_ARRAY_SIZE(signers_seeds)) != SUCCESS) {
            return ERROR_BLAZ;
        }
        return SUCCESS;
    }
}

uint64_t deposit(uint8_t *data, SolAccountInfo *accounts) {
    // deposit
    uint64_t amount = *(uint64_t *)(data);
    if (amount == 0) {
        return ERROR_BLAZ;
    }

    // transfer from caller to vault
    {
        uint64_t lamports_before = *accounts[VAULT_ACCOUNT].lamports;
        SolAccountMeta arguments[] = {
            {accounts[CALLER].key, true, true},
            {accounts[VAULT_ACCOUNT].key, true, false}};

        uint8_t transfer_ix_data[] = {2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        *(uint64_t *)(transfer_ix_data + 4) = amount;

        const SolInstruction instruction = {
            accounts[SYSTEM_ID].key, arguments, SOL_ARRAY_SIZE(arguments),
            transfer_ix_data, SOL_ARRAY_SIZE(transfer_ix_data)};

        if (sol_invoke(&instruction, accounts, NUM_ACCOUNTS) != SUCCESS) {
            return ERROR_BLAZ;
        }

        if (*accounts[VAULT_ACCOUNT].lamports != lamports_before + amount) {
            return ERROR_BLAZ;
        }
    }

    // update balance
    {
        uint64_t *balance = (uint64_t *)accounts[BALANCE_ACCOUNT].data;
        *balance += amount;
    }

    return SUCCESS;
}

uint64_t withdraw(uint8_t *data, SolAccountInfo *accounts) {
    ConfigAccount *config = (ConfigAccount *)accounts[CONFIG_ACCOUNT].data;
    if (config->locked) {
        return ERROR_BLAZ;
    }

    uint64_t amount = *(uint64_t *)(data);

    *accounts[VAULT_ACCOUNT].lamports -= amount;
    *accounts[CALLER].lamports += amount;

    uint64_t *balance = (uint64_t *)accounts[BALANCE_ACCOUNT].data;
    *balance -= amount;

    return SUCCESS;
}

uint64_t toggle(uint8_t *data, SolAccountInfo *accounts) {
    ConfigAccount *config = (ConfigAccount *)accounts[CONFIG_ACCOUNT].data;
    config->locked = !config->locked;

    if (memcmp(accounts[CALLER].key, config->owner, SIZE_PUBKEY) != 0) {
        return ERROR_BLAZ;
    }

    return SUCCESS;
}