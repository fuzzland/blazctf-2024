use crate::interpreter::{
    analysis::to_analysed, gas, instruction_result::SuccessOrHalt, return_ok, return_revert,
    CallInputs, Contract, CreateInputs, CreateScheme, Gas, Host,
    InstructionResult, Interpreter, SelfDestructResult, Transfer, CALL_STACK_LIMIT,
};
use crate::primitives::{
    create2_address, create_address, keccak256, Account, AnalysisKind, Bytecode, Bytes, CallContext,
    CallScheme, EVMError, EVMResult, Env, ExecutionResult, HashMap, InvalidTransaction,
    Log, Output, ResultAndState, Spec,
    SpecId::{self, *},
    TransactTo, B160, B256, KECCAK_EMPTY, U256,
};
use crate::{db::Database, journaled_state::JournaledState, precompile, Inspector};
use alloc::vec::Vec;
use core::cmp::Ordering;
use core::{cmp::min, marker::PhantomData};
use revm_interpreter::{MAX_CODE_SIZE, MAX_INITCODE_SIZE};
use revm_precompile::{Precompile, Precompiles};

pub struct EVMData<'a, DB: Database> {
    pub env: &'a mut Env,
    pub journaled_state: JournaledState,
    pub db: &'a mut DB,
    pub error: Option<DB::Error>,
    pub precompiles: Precompiles,
}

pub struct EVMImpl<'a, GSPEC: Spec, DB: Database, const INSPECT: bool> {
    data: EVMData<'a, DB>,
    inspector: &'a mut dyn Inspector<DB>,
    _phantomdata: PhantomData<GSPEC>,
}

pub trait Transact<DBError> {
    /// Do transaction.
    /// InstructionResult InstructionResult, Output for call or Address if we are creating contract, gas spend, gas refunded, State that needs to be applied.
    fn transact(&mut self) -> EVMResult<DBError>;
}

impl<'a, GSPEC: Spec, DB: Database, const INSPECT: bool> Transact<DB::Error>
    for EVMImpl<'a, GSPEC, DB, INSPECT>
{
    fn transact(&mut self) -> EVMResult<DB::Error> {
        let caller = self.data.env.tx.caller;
        let value = self.data.env.tx.value;
        let data = self.data.env.tx.data.clone();
        let gas_limit = self.data.env.tx.gas_limit;
        let effective_gas_price = self.data.env.effective_gas_price();

        if GSPEC::enabled(MERGE) && self.data.env.block.prevrandao.is_none() {
            return Err(EVMError::PrevrandaoNotSet);
        }

        if GSPEC::enabled(LONDON) {
            if let Some(priority_fee) = self.data.env.tx.gas_priority_fee {
                if priority_fee > self.data.env.tx.gas_price {
                    // or gas_max_fee for eip1559
                    return Err(InvalidTransaction::GasMaxFeeGreaterThanPriorityFee.into());
                }
            }
            let basefee = self.data.env.block.basefee;

            #[cfg(feature = "optional_no_base_fee")]
            let disable_base_fee = self.env().cfg.disable_base_fee;
            #[cfg(not(feature = "optional_no_base_fee"))]
            let disable_base_fee = false;

            // check minimal cost against basefee
            // TODO maybe do this checks when creating evm. We already have all data there
            // or should be move effective_gas_price inside transact fn
            if !disable_base_fee && effective_gas_price < basefee {
                return Err(InvalidTransaction::GasPriceLessThanBasefee.into());
            }
            // check if priority fee is lower than max fee
        }

        #[cfg(feature = "optional_block_gas_limit")]
        let disable_block_gas_limit = self.env().cfg.disable_block_gas_limit;
        #[cfg(not(feature = "optional_block_gas_limit"))]
        let disable_block_gas_limit = false;

        // unusual to be found here, but check if gas_limit is more than block_gas_limit
        if !disable_block_gas_limit && U256::from(gas_limit) > self.data.env.block.gas_limit {
            return Err(InvalidTransaction::CallerGasLimitMoreThanBlock.into());
        }

        // load acc
        self.data
            .journaled_state
            .load_account(caller, self.data.db)
            .map_err(EVMError::Database)?;

        #[cfg(feature = "optional_eip3607")]
        let disable_eip3607 = self.env().cfg.disable_eip3607;
        #[cfg(not(feature = "optional_eip3607"))]
        let disable_eip3607 = false;

        // EIP-3607: Reject transactions from senders with deployed code
        // This EIP is introduced after london but there was no collision in past
        // so we can leave it enabled always
        if !disable_eip3607
            && self.data.journaled_state.account(caller).info.code_hash != KECCAK_EMPTY
        {
            return Err(InvalidTransaction::RejectCallerWithCode.into());
        }

        // Check if the transaction's chain id is correct
        if let Some(tx_chain_id) = self.data.env.tx.chain_id {
            if U256::from(tx_chain_id) != self.data.env.cfg.chain_id {
                return Err(InvalidTransaction::InvalidChainId.into());
            }
        }

        // Check that the transaction's nonce is correct
        if self.data.env.tx.nonce.is_some() {
            let state_nonce = self
                .data
                .journaled_state
                .state
                .get(&caller)
                .unwrap()
                .info
                .nonce;
            let tx_nonce = self.data.env.tx.nonce.unwrap();
            match tx_nonce.cmp(&state_nonce) {
                Ordering::Greater => {
                    return Err(InvalidTransaction::NonceTooHigh {
                        tx: tx_nonce,
                        state: state_nonce,
                    }
                    .into());
                }
                Ordering::Less => {
                    return Err(InvalidTransaction::NonceTooLow {
                        tx: tx_nonce,
                        state: state_nonce,
                    }
                    .into());
                }
                _ => {}
            }
        }

        #[cfg(feature = "optional_balance_check")]
        let disable_balance_check = self.env().cfg.disable_balance_check;
        #[cfg(not(feature = "optional_balance_check"))]
        let disable_balance_check = false;

        let caller_balance = &mut self
            .data
            .journaled_state
            .state
            .get_mut(&caller)
            .unwrap()
            .info
            .balance;

        let balance_check = U256::from(gas_limit)
            .checked_mul(self.data.env.tx.gas_price)
            .and_then(|gas_cost| gas_cost.checked_add(value))
            .ok_or(EVMError::Transaction(
                InvalidTransaction::OverflowPaymentInTransaction,
            ))?;

        // Check if account has enough balance for gas_limit*gas_price and value transfer.
        // Transfer will be done inside `*_inner` functions.
        if balance_check > *caller_balance && !disable_balance_check {
            return Err(InvalidTransaction::LackOfFundForGasLimit {
                gas_limit: balance_check,
                balance: *caller_balance,
            }
            .into());
        }

        // Reduce gas_limit*gas_price amount of caller account.
        // unwrap_or can only occur if disable_balance_check is enabled
        *caller_balance = caller_balance
            .checked_sub(U256::from(gas_limit) * effective_gas_price)
            .unwrap_or(U256::ZERO);

        let mut gas = Gas::new(gas_limit);
        // record initial gas cost. if not using gas metering init will return.
        if !gas.record_cost(self.initialization::<GSPEC>()?) {
            return Err(InvalidTransaction::CallGasCostMoreThanGasLimit.into());
        }

        // record all as cost. Gas limit here is reduced by init cost of bytes and access lists.
        let gas_limit = gas.remaining();
        if crate::USE_GAS {
            gas.record_cost(gas_limit);
        }

        // load coinbase
        // EIP-3651: Warm COINBASE. Starts the `COINBASE` address warm
        if GSPEC::enabled(SHANGHAI) {
            self.data
                .journaled_state
                .load_account(self.data.env.block.coinbase, self.data.db)
                .map_err(EVMError::Database)?;
        }

        // call inner handling of call/create
        // TODO can probably be refactored to look nicer.
        let (exit_reason, ret_gas, output) = match self.data.env.tx.transact_to {
            TransactTo::Call(address) => {
                if self.data.journaled_state.inc_nonce(caller).is_some() {
                    let context = CallContext {
                        caller,
                        address,
                        code_address: address,
                        apparent_value: value,
                        scheme: CallScheme::Call,
                    };
                    let mut call_input = CallInputs {
                        contract: address,
                        transfer: Transfer {
                            source: caller,
                            target: address,
                            value,
                        },
                        input: data,
                        gas_limit,
                        context,
                        is_static: false,
                    };
                    let (exit, gas, bytes) = self.call_inner(&mut call_input);
                    (exit, gas, Output::Call(bytes))
                } else {
                    (
                        InstructionResult::NonceOverflow,
                        gas,
                        Output::Call(Bytes::new()),
                    )
                }
            }
            TransactTo::Create(scheme) => {
                let mut create_input = CreateInputs {
                    caller,
                    scheme,
                    value,
                    init_code: data,
                    gas_limit,
                };
                let (exit, address, ret_gas, bytes) = self.create_inner(&mut create_input);
                (exit, ret_gas, Output::Create(bytes, address))
            }
        };

        if crate::USE_GAS {
            match exit_reason {
                return_ok!() => {
                    gas.erase_cost(ret_gas.remaining());
                    gas.record_refund(ret_gas.refunded());
                }
                return_revert!() => {
                    gas.erase_cost(ret_gas.remaining());
                }
                _ => {}
            }
        }

        let (state, logs, gas_used, gas_refunded) = self.finalize::<GSPEC>(caller, &gas);

        let result = match exit_reason.into() {
            SuccessOrHalt::Success(reason) => ExecutionResult::Success {
                reason,
                gas_used,
                gas_refunded,
                logs,
                output,
            },
            SuccessOrHalt::Revert => ExecutionResult::Revert {
                gas_used,
                output: match output {
                    Output::Call(return_value) => return_value,
                    Output::Create(return_value, _) => return_value,
                },
            },
            SuccessOrHalt::Halt(reason) => ExecutionResult::Halt { reason, gas_used },
            SuccessOrHalt::FatalExternalError => {
                return Err(EVMError::Database(self.data.error.take().unwrap()))
            }
            SuccessOrHalt::InternalContinue => {
                panic!("Internal return flags should remain internal {exit_reason:?}")
            }
        };

        Ok(ResultAndState { result, state })
    }
}

impl<'a, GSPEC: Spec, DB: Database, const INSPECT: bool> EVMImpl<'a, GSPEC, DB, INSPECT> {
    pub fn new(
        db: &'a mut DB,
        env: &'a mut Env,
        inspector: &'a mut dyn Inspector<DB>,
        precompiles: Precompiles,
    ) -> Self {
        let journaled_state = if GSPEC::enabled(SpecId::SPURIOUS_DRAGON) {
            JournaledState::new(precompiles.len())
        } else {
            JournaledState::new_legacy(precompiles.len())
        };
        Self {
            data: EVMData {
                env,
                journaled_state,
                db,
                error: None,
                precompiles,
            },
            inspector,
            _phantomdata: PhantomData {},
        }
    }

    fn finalize<SPEC: Spec>(
        &mut self,
        caller: B160,
        gas: &Gas,
    ) -> (HashMap<B160, Account>, Vec<Log>, u64, u64) {
        let coinbase = self.data.env.block.coinbase;
        let (gas_used, gas_refunded) = if crate::USE_GAS {
            let effective_gas_price = self.data.env.effective_gas_price();
            let basefee = self.data.env.block.basefee;

            #[cfg(feature = "optional_gas_refund")]
            let disable_gas_refund = self.env().cfg.disable_gas_refund;
            #[cfg(not(feature = "optional_gas_refund"))]
            let disable_gas_refund = false;

            let gas_refunded = if disable_gas_refund {
                0
            } else {
                // EIP-3529: Reduction in refunds
                let max_refund_quotient = if SPEC::enabled(LONDON) { 5 } else { 2 };
                min(gas.refunded() as u64, gas.spend() / max_refund_quotient)
            };
            let acc_caller = self.data.journaled_state.state().get_mut(&caller).unwrap();
            acc_caller.info.balance = acc_caller
                .info
                .balance
                .saturating_add(effective_gas_price * U256::from(gas.remaining() + gas_refunded));

            // EIP-1559
            let coinbase_gas_price = if SPEC::enabled(LONDON) {
                effective_gas_price.saturating_sub(basefee)
            } else {
                effective_gas_price
            };

            // TODO
            let _ = self
                .data
                .journaled_state
                .load_account(coinbase, self.data.db);
            self.data.journaled_state.touch(&coinbase);
            let acc_coinbase = self
                .data
                .journaled_state
                .state()
                .get_mut(&coinbase)
                .unwrap();
            acc_coinbase.info.balance = acc_coinbase
                .info
                .balance
                .saturating_add(coinbase_gas_price * U256::from(gas.spend() - gas_refunded));
            (gas.spend() - gas_refunded, gas_refunded)
        } else {
            // touch coinbase
            // TODO return
            let _ = self
                .data
                .journaled_state
                .load_account(coinbase, self.data.db);
            self.data.journaled_state.touch(&coinbase);
            (0, 0)
        };
        let (mut new_state, logs) = self.data.journaled_state.finalize();
        // precompiles are special case. If there is precompiles in finalized Map that means some balance is
        // added to it, we need now to load precompile address from db and add this amount to it so that we
        // will have sum.
        if self.data.env.cfg.perf_all_precompiles_have_balance {
            for address in self.data.precompiles.addresses() {
                let address = B160(*address);
                if let Some(precompile) = new_state.get_mut(&address) {
                    // we found it.
                    precompile.info.balance += self
                        .data
                        .db
                        .basic(address)
                        .ok()
                        .flatten()
                        .map(|acc| acc.balance)
                        .unwrap_or_default();
                }
            }
        }

        (new_state, logs, gas_used, gas_refunded)
    }

    fn initialization<SPEC: Spec>(&mut self) -> Result<u64, EVMError<DB::Error>> {
        let is_create = matches!(self.data.env.tx.transact_to, TransactTo::Create(_));
        let input = &self.data.env.tx.data;

        // EIP-3860: Limit and meter initcode
        let initcode_cost = if SPEC::enabled(SHANGHAI) && self.data.env.tx.transact_to.is_create() {
            let initcode_len = self.data.env.tx.data.len();
            // Limit is set as double of max contract bytecode size
            let max_initcode_size = self
                .data
                .env
                .cfg
                .limit_contract_code_size
                .map(|limit| limit.saturating_mul(2))
                .unwrap_or(MAX_INITCODE_SIZE);
            if initcode_len > max_initcode_size {
                return Err(InvalidTransaction::CreateInitcodeSizeLimit.into());
            }
            if crate::USE_GAS {
                gas::initcode_cost(initcode_len as u64)
            } else {
                0
            }
        } else {
            0
        };

        if crate::USE_GAS {
            let zero_data_len = input.iter().filter(|v| **v == 0).count() as u64;
            let non_zero_data_len = input.len() as u64 - zero_data_len;
            let (accessed_accounts, accessed_slots) = {
                if SPEC::enabled(BERLIN) {
                    let mut accessed_slots = 0_u64;

                    for (address, slots) in self.data.env.tx.access_list.iter() {
                        self.data
                            .journaled_state
                            .load_account(*address, self.data.db)
                            .map_err(EVMError::Database)?;
                        accessed_slots += slots.len() as u64;

                        for slot in slots {
                            self.data
                                .journaled_state
                                .sload(*address, *slot, self.data.db)
                                .map_err(EVMError::Database)?;
                        }
                    }
                    (self.data.env.tx.access_list.len() as u64, accessed_slots)
                } else {
                    (0, 0)
                }
            };

            let transact = if is_create {
                if SPEC::enabled(HOMESTEAD) {
                    // EIP-2: Homestead Hard-fork Changes
                    53000
                } else {
                    21000
                }
            } else {
                21000
            };

            // EIP-2028: Transaction data gas cost reduction
            let gas_transaction_non_zero_data = if SPEC::enabled(ISTANBUL) { 16 } else { 68 };

            Ok(transact
                + initcode_cost
                + zero_data_len * gas::TRANSACTION_ZERO_DATA
                + non_zero_data_len * gas_transaction_non_zero_data
                + accessed_accounts * gas::ACCESS_LIST_ADDRESS
                + accessed_slots * gas::ACCESS_LIST_STORAGE_KEY)
        } else {
            Ok(0)
        }
    }

    fn create_inner(
        &mut self,
        inputs: &mut CreateInputs,
    ) -> (InstructionResult, Option<B160>, Gas, Bytes) {
        // Call inspector
        if INSPECT {
            let (ret, address, gas, out) = self.inspector.create(&mut self.data, inputs);
            if ret != InstructionResult::Continue {
                return self
                    .inspector
                    .create_end(&mut self.data, inputs, ret, address, gas, out);
            }
        }

        let gas = Gas::new(inputs.gas_limit);
        self.load_account(inputs.caller);

        // Check depth of calls
        if self.data.journaled_state.depth() > CALL_STACK_LIMIT {
            return self.create_end(
                inputs,
                InstructionResult::CallTooDeep,
                None,
                gas,
                Bytes::new(),
            );
        }
        // Check balance of caller and value. Do this before increasing nonce
        match self.balance(inputs.caller) {
            Some(i) if i.0 < inputs.value => {
                return self.create_end(
                    inputs,
                    InstructionResult::OutOfFund,
                    None,
                    gas,
                    Bytes::new(),
                )
            }
            Some(_) => (),
            _ => {
                return self.create_end(
                    inputs,
                    InstructionResult::FatalExternalError,
                    None,
                    gas,
                    Bytes::new(),
                )
            }
        }

        // Increase nonce of caller and check if it overflows
        let old_nonce;
        if let Some(nonce) = self.data.journaled_state.inc_nonce(inputs.caller) {
            old_nonce = nonce - 1;
        } else {
            return self.create_end(inputs, InstructionResult::Return, None, gas, Bytes::new());
        }

        // Create address
        let code_hash = keccak256(&inputs.init_code);
        let created_address = match inputs.scheme {
            CreateScheme::Create => create_address(inputs.caller, old_nonce),
            CreateScheme::Create2 { salt } => create2_address(inputs.caller, code_hash, salt),
        };
        let ret = Some(created_address);

        // Load account so that it will be hot
        self.load_account(created_address);

        // Enter subroutine
        let checkpoint = self.data.journaled_state.checkpoint();

        // Create contract account and check for collision
        match self.data.journaled_state.create_account(
            created_address,
            self.data.precompiles.contains(&created_address),
            self.data.db,
        ) {
            Ok(false) => {
                self.data.journaled_state.checkpoint_revert(checkpoint);
                return self.create_end(
                    inputs,
                    InstructionResult::CreateCollision,
                    ret,
                    gas,
                    Bytes::new(),
                );
            }
            Err(err) => {
                self.data.error = Some(err);
                return self.create_end(
                    inputs,
                    InstructionResult::FatalExternalError,
                    ret,
                    gas,
                    Bytes::new(),
                );
            }
            Ok(true) => (),
        }

        // Transfer value to contract address
        if let Err(e) = self.data.journaled_state.transfer(
            &inputs.caller,
            &created_address,
            inputs.value,
            self.data.db,
        ) {
            self.data.journaled_state.checkpoint_revert(checkpoint);
            return self.create_end(inputs, e, ret, gas, Bytes::new());
        }

        // EIP-161: State trie clearing (invariant-preserving alternative)
        if GSPEC::enabled(SPURIOUS_DRAGON)
            && self
                .data
                .journaled_state
                .inc_nonce(created_address)
                .is_none()
        {
            // overflow
            self.data.journaled_state.checkpoint_revert(checkpoint);
            return self.create_end(inputs, InstructionResult::Return, None, gas, Bytes::new());
        }

        // Create new interpreter and execute initcode
        let contract = Contract::new(
            Bytes::new(),
            Bytecode::new_raw(inputs.init_code.clone()),
            created_address,
            inputs.caller,
            inputs.value,
        );

        #[cfg(feature = "memory_limit")]
        let mut interpreter = Interpreter::new_with_memory_limit(
            contract,
            gas.limit(),
            false,
            self.data.env.cfg.memory_limit,
        );

        #[cfg(not(feature = "memory_limit"))]
        let mut interpreter = Interpreter::new(contract, gas.limit(), false);

        if INSPECT {
            self.inspector
                .initialize_interp(&mut interpreter, &mut self.data, false);
        }
        let exit_reason = if INSPECT {
            interpreter.run_inspect::<Self, GSPEC>(self)
        } else {
            interpreter.run::<Self, GSPEC>(self)
        };
        // Host error if present on execution\
        let (ret, address, gas, out) = match exit_reason {
            return_ok!() => {
                // if ok, check contract creation limit and calculate gas deduction on output len.
                let mut bytes = interpreter.return_value();

                // EIP-3541: Reject new contract code starting with the 0xEF byte
                if GSPEC::enabled(LONDON) && !bytes.is_empty() && bytes.first() == Some(&0xEF) {
                    self.data.journaled_state.checkpoint_revert(checkpoint);
                    return self.create_end(
                        inputs,
                        InstructionResult::CreateContractStartingWithEF,
                        ret,
                        interpreter.gas,
                        bytes,
                    );
                }

                // EIP-170: Contract code size limit
                // By default limit is 0x6000 (~25kb)
                if GSPEC::enabled(SPURIOUS_DRAGON)
                    && bytes.len()
                        > self
                            .data
                            .env
                            .cfg
                            .limit_contract_code_size
                            .unwrap_or(MAX_CODE_SIZE)
                {
                    self.data.journaled_state.checkpoint_revert(checkpoint);
                    return self.create_end(
                        inputs,
                        InstructionResult::CreateContractSizeLimit,
                        ret,
                        interpreter.gas,
                        bytes,
                    );
                }
                if crate::USE_GAS {
                    let gas_for_code = bytes.len() as u64 * gas::CODEDEPOSIT;
                    if !interpreter.gas.record_cost(gas_for_code) {
                        // record code deposit gas cost and check if we are out of gas.
                        // EIP-2 point 3: If contract creation does not have enough gas to pay for the
                        // final gas fee for adding the contract code to the state, the contract
                        //  creation fails (i.e. goes out-of-gas) rather than leaving an empty contract.
                        if GSPEC::enabled(HOMESTEAD) {
                            self.data.journaled_state.checkpoint_revert(checkpoint);
                            return self.create_end(
                                inputs,
                                InstructionResult::OutOfGas,
                                ret,
                                interpreter.gas,
                                bytes,
                            );
                        } else {
                            bytes = Bytes::new();
                        }
                    }
                }
                // if we have enough gas
                self.data.journaled_state.checkpoint_commit();
                // Do analysis of bytecode straight away.
                let bytecode = match self.data.env.cfg.perf_analyse_created_bytecodes {
                    AnalysisKind::Raw => Bytecode::new_raw(bytes.clone()),
                    AnalysisKind::Check => Bytecode::new_raw(bytes.clone()).to_checked(),
                    AnalysisKind::Analyse => to_analysed(Bytecode::new_raw(bytes.clone())),
                };

                self.data
                    .journaled_state
                    .set_code(created_address, bytecode);
                (InstructionResult::Return, ret, interpreter.gas, bytes)
            }
            _ => {
                self.data.journaled_state.checkpoint_revert(checkpoint);
                (
                    exit_reason,
                    ret,
                    interpreter.gas,
                    interpreter.return_value(),
                )
            }
        };

        self.create_end(inputs, ret, address, gas, out)
    }

    fn create_end(
        &mut self,
        inputs: &CreateInputs,
        ret: InstructionResult,
        address: Option<B160>,
        gas: Gas,
        out: Bytes,
    ) -> (InstructionResult, Option<B160>, Gas, Bytes) {
        if INSPECT {
            self.inspector
                .create_end(&mut self.data, inputs, ret, address, gas, out)
        } else {
            (ret, address, gas, out)
        }
    }

    fn call_inner(&mut self, inputs: &mut CallInputs) -> (InstructionResult, Gas, Bytes) {
        // Call the inspector
        if INSPECT {
            let (ret, gas, out) = self
                .inspector
                .call(&mut self.data, inputs, inputs.is_static);
            if ret != InstructionResult::Continue {
                return self.inspector.call_end(
                    &mut self.data,
                    inputs,
                    gas,
                    ret,
                    out,
                    inputs.is_static,
                );
            }
        }

        let mut gas = Gas::new(inputs.gas_limit);
        // Load account and get code. Account is now hot.
        let bytecode = if let Some((bytecode, _)) = self.code(inputs.contract) {
            bytecode
        } else {
            return (InstructionResult::FatalExternalError, gas, Bytes::new());
        };

        // Check depth
        if self.data.journaled_state.depth() > CALL_STACK_LIMIT {
            let (ret, gas, out) = (InstructionResult::CallTooDeep, gas, Bytes::new());
            if INSPECT {
                return self.inspector.call_end(
                    &mut self.data,
                    inputs,
                    gas,
                    ret,
                    out,
                    inputs.is_static,
                );
            } else {
                return (ret, gas, out);
            }
        }

        // Create subroutine checkpoint
        let checkpoint = self.data.journaled_state.checkpoint();

        // Touch address. For "EIP-158 State Clear", this will erase empty accounts.
        if inputs.transfer.value == U256::ZERO {
            self.load_account(inputs.context.address);
            self.data.journaled_state.touch(&inputs.context.address);
        }

        // Transfer value from caller to called account
        if let Err(e) = self.data.journaled_state.transfer(
            &inputs.transfer.source,
            &inputs.transfer.target,
            inputs.transfer.value,
            self.data.db,
        ) {
            self.data.journaled_state.checkpoint_revert(checkpoint);
            let (ret, gas, out) = (e, gas, Bytes::new());
            if INSPECT {
                return self.inspector.call_end(
                    &mut self.data,
                    inputs,
                    gas,
                    ret,
                    out,
                    inputs.is_static,
                );
            } else {
                return (ret, gas, out);
            }
        }

        // Call precompiles
        let (ret, gas, out) = if let Some(precompile) = self.data.precompiles.get(&inputs.contract)
        {
            let out = match precompile {
                Precompile::Standard(fun) => fun(inputs.input.as_ref(), inputs.gas_limit),
                Precompile::Custom(fun) => fun(inputs.input.as_ref(), inputs.gas_limit),
                Precompile::CustomEnterprise(fun) => fun(inputs.input.as_ref(), inputs.gas_limit, &inputs.context),
            };
            match out {
                Ok((gas_used, data)) => {
                    if !crate::USE_GAS || gas.record_cost(gas_used) {
                        self.data.journaled_state.checkpoint_commit();
                        (InstructionResult::Return, gas, Bytes::from(data))
                    } else {
                        self.data.journaled_state.checkpoint_revert(checkpoint);
                        (InstructionResult::PrecompileOOG, gas, Bytes::new())
                    }
                }
                Err(e) => {
                    let ret = if let precompile::Error::OutOfGas = e {
                        InstructionResult::PrecompileOOG
                    } else {
                        InstructionResult::PrecompileError
                    };
                    self.data.journaled_state.checkpoint_revert(checkpoint);
                    (ret, gas, Bytes::new())
                }
            }
        } else {
            // Create interpreter and execute subcall
            let contract =
                Contract::new_with_context(inputs.input.clone(), bytecode, &inputs.context);

            #[cfg(feature = "memory_limit")]
            let mut interpreter = Interpreter::new_with_memory_limit(
                contract,
                gas.limit(),
                inputs.is_static,
                self.data.env.cfg.memory_limit,
            );

            #[cfg(not(feature = "memory_limit"))]
            let mut interpreter = Interpreter::new(contract, gas.limit(), inputs.is_static);

            if INSPECT {
                // create is always no static call.
                self.inspector
                    .initialize_interp(&mut interpreter, &mut self.data, false);
            }
            let exit_reason = if INSPECT {
                interpreter.run_inspect::<Self, GSPEC>(self)
            } else {
                interpreter.run::<Self, GSPEC>(self)
            };

            if matches!(exit_reason, return_ok!()) {
                self.data.journaled_state.checkpoint_commit();
            } else {
                self.data.journaled_state.checkpoint_revert(checkpoint);
            }

            (exit_reason, interpreter.gas, interpreter.return_value())
        };

        if INSPECT {
            self.inspector
                .call_end(&mut self.data, inputs, gas, ret, out, inputs.is_static)
        } else {
            (ret, gas, out)
        }
    }
}

impl<'a, GSPEC: Spec, DB: Database + 'a, const INSPECT: bool> Host
    for EVMImpl<'a, GSPEC, DB, INSPECT>
{
    fn step(&mut self, interp: &mut Interpreter, is_static: bool) -> InstructionResult {
        self.inspector.step(interp, &mut self.data, is_static)
    }

    fn step_end(
        &mut self,
        interp: &mut Interpreter,
        is_static: bool,
        ret: InstructionResult,
    ) -> InstructionResult {
        self.inspector
            .step_end(interp, &mut self.data, is_static, ret)
    }

    fn env(&mut self) -> &mut Env {
        self.data.env
    }

    fn block_hash(&mut self, number: U256) -> Option<B256> {
        self.data
            .db
            .block_hash(number)
            .map_err(|e| self.data.error = Some(e))
            .ok()
    }

    fn load_account(&mut self, address: B160) -> Option<(bool, bool)> {
        self.data
            .journaled_state
            .load_account_exist(address, self.data.db)
            .map_err(|e| self.data.error = Some(e))
            .ok()
    }

    fn balance(&mut self, address: B160) -> Option<(U256, bool)> {
        let db = &mut self.data.db;
        let journal = &mut self.data.journaled_state;
        let error = &mut self.data.error;
        journal
            .load_account(address, db)
            .map_err(|e| *error = Some(e))
            .ok()
            .map(|(acc, is_cold)| (acc.info.balance, is_cold))
    }

    fn code(&mut self, address: B160) -> Option<(Bytecode, bool)> {
        let journal = &mut self.data.journaled_state;
        let db = &mut self.data.db;
        let error = &mut self.data.error;

        let (acc, is_cold) = journal
            .load_code(address, db)
            .map_err(|e| *error = Some(e))
            .ok()?;
        Some((acc.info.code.clone().unwrap(), is_cold))
    }

    /// Get code hash of address.
    fn code_hash(&mut self, address: B160) -> Option<(B256, bool)> {
        let journal = &mut self.data.journaled_state;
        let db = &mut self.data.db;
        let error = &mut self.data.error;

        let (acc, is_cold) = journal
            .load_code(address, db)
            .map_err(|e| *error = Some(e))
            .ok()?;
        //asume that all precompiles have some balance
        let is_precompile = self.data.precompiles.contains(&address);
        if is_precompile && self.data.env.cfg.perf_all_precompiles_have_balance {
            return Some((KECCAK_EMPTY, is_cold));
        }
        if acc.is_empty() {
            // TODO check this for pre tangerine fork
            return Some((B256::zero(), is_cold));
        }

        Some((acc.info.code_hash, is_cold))
    }

    fn sload(&mut self, address: B160, index: U256) -> Option<(U256, bool)> {
        // account is always hot. reference on that statement https://eips.ethereum.org/EIPS/eip-2929 see `Note 2:`
        self.data
            .journaled_state
            .sload(address, index, self.data.db)
            .map_err(|e| self.data.error = Some(e))
            .ok()
    }

    fn sstore(
        &mut self,
        address: B160,
        index: U256,
        value: U256,
    ) -> Option<(U256, U256, U256, bool)> {
        self.data
            .journaled_state
            .sstore(address, index, value, self.data.db)
            .map_err(|e| self.data.error = Some(e))
            .ok()
    }

    fn log(&mut self, address: B160, topics: Vec<B256>, data: Bytes) {
        if INSPECT {
            self.inspector.log(&mut self.data, &address, &topics, &data);
        }
        let log = Log {
            address,
            topics,
            data,
        };
        self.data.journaled_state.log(log);
    }

    fn selfdestruct(&mut self, address: B160, target: B160) -> Option<SelfDestructResult> {
        if INSPECT {
            self.inspector.selfdestruct(address, target);
        }
        self.data
            .journaled_state
            .selfdestruct(address, target, self.data.db)
            .map_err(|e| self.data.error = Some(e))
            .ok()
    }

    fn create(
        &mut self,
        inputs: &mut CreateInputs,
    ) -> (InstructionResult, Option<B160>, Gas, Bytes) {
        self.create_inner(inputs)
    }

    fn call(&mut self, inputs: &mut CallInputs) -> (InstructionResult, Gas, Bytes) {
        self.call_inner(inputs)
    }
}
