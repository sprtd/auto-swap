// *************************************************************************
//                              FIBROUS SWAP TEST
// *************************************************************************
use core::result::ResultTrait;
use starknet::{ContractAddress, contract_address_const};

use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, start_cheat_account_contract_address, stop_cheat_account_contract_address,
};

use auto_swappr::interfaces::iautoswappr::{IAutoSwapprDispatcher, IAutoSwapprDispatcherTrait};
use auto_swappr::base::types::{RouteParams, SwapParams, Route};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

const OWNER: felt252 = 'OWNER';
const FEE_COLLECTOR: felt252 = 0x0114B0b4A160bCC34320835aEFe7f01A2a3885e4340Be0Bc1A63194469984a06;

fn AVNU_EXCHANGE_ADDRESS() -> ContractAddress {
    contract_address_const::<0x04270219d365d6b017231b52e92b3fb5d7c8378b05e9abc97724537a80e93b0f>()
}
fn FIBROUS_EXCHANGE_ADDRESS() -> ContractAddress {
    contract_address_const::<0x00f6f4CF62E3C010E0aC2451cC7807b5eEc19a40b0FaaCd00CCA3914280FDf5a>()
}

fn STRK_TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d>()
}

fn ETH_TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7>()
}

fn USDC_TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<0x053C91253BC9682c04929cA02ED00b3E423f6710D2ee7e0D5EBB06F3eCF368A8>()
}

fn USDT_TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<0x068F5c6a61780768455de69077E07e89787839bf8166dEcfBf92B645209c0fB8>()
}


fn ADDRESS_WITH_FUNDS() -> ContractAddress {
    // 0.01 ETH - 8.4 STRK
    contract_address_const::<0x298a9d0d82aabfd7e2463bb5ec3590c4e86d03b2ece868d06bbe43475f2d3e6>()
}

fn JEDISWAP_POOL_ADDRESS() -> ContractAddress {
    contract_address_const::<0x5726725e9507c3586cc0516449e2c74d9b201ab2747752bb0251aaa263c9a26>()
}

fn JEDISWAP_ROUTER_V2() -> ContractAddress {
    contract_address_const::<0x359550b990167afd6635fa574f3bdadd83cb51850e1d00061fe693158c23f80>() // JediSwap: Swap Router V2
}

fn STRK_TOKEN() -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: STRK_TOKEN_ADDRESS() }
}

fn ETH_TOKEN() -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: ETH_TOKEN_ADDRESS() }
}

fn USDT_TOKEN() -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: USDT_TOKEN_ADDRESS() }
}

fn USDC_TOKEN() -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: USDC_TOKEN_ADDRESS() }
}

const AMOUNT_TO_SWAP_STRK: u256 = 1000000000000000000; // 1 STRK
const AMOUNT_TO_SWAP_ETH: u256 = 10000000000000000; // 0.01 ETH 


// UTILS
fn call_avnu_swap(
    autoSwappr_dispatcher: IAutoSwapprDispatcher,
    token_from_address: ContractAddress,
    token_from_amount: u256,
    token_to_address: ContractAddress,
    token_to_amount: u256,
    token_to_min_amount: u256,
    beneficiary: ContractAddress,
    integrator_fee_amount_bps: u128,
    integrator_fee_recipient: ContractAddress,
    routes: Array<Route>,
) {
    start_cheat_caller_address(autoSwappr_dispatcher.contract_address, ADDRESS_WITH_FUNDS());
    start_cheat_account_contract_address(AVNU_EXCHANGE_ADDRESS(), ADDRESS_WITH_FUNDS());
    autoSwappr_dispatcher.swap(
        token_from_address,
        token_from_amount,
        token_to_address,
        token_to_amount,
        token_to_min_amount,
        beneficiary,
        integrator_fee_amount_bps,
        integrator_fee_recipient,
        routes,
    );
    stop_cheat_caller_address(autoSwappr_dispatcher.contract_address);
    stop_cheat_account_contract_address(AVNU_EXCHANGE_ADDRESS());
}

fn get_wallet_amounts(wallet_address: ContractAddress) -> WalletAmounts {
    start_cheat_caller_address(STRK_TOKEN().contract_address, wallet_address);
    start_cheat_caller_address(ETH_TOKEN().contract_address, wallet_address);
    start_cheat_caller_address(USDT_TOKEN().contract_address, wallet_address);
    start_cheat_caller_address(USDC_TOKEN().contract_address, wallet_address);
    let strk = STRK_TOKEN().balance_of(wallet_address);
    let eth = ETH_TOKEN().balance_of(wallet_address);
    let usdt = USDT_TOKEN().balance_of(wallet_address);
    let usdc = USDC_TOKEN().balance_of(wallet_address);
    stop_cheat_caller_address(STRK_TOKEN().contract_address);
    stop_cheat_caller_address(ETH_TOKEN().contract_address);
    stop_cheat_caller_address(USDT_TOKEN().contract_address);
    stop_cheat_caller_address(USDC_TOKEN().contract_address);

    let amounts = WalletAmounts { strk, eth, usdt, usdc };
    amounts
}

fn approve_amount(
    token: ContractAddress, owner: ContractAddress, spender: ContractAddress, amount: u256
) {
    start_cheat_caller_address(token, owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: token };
    token_dispatcher.approve(spender, amount);
    stop_cheat_caller_address(token);
}

fn get_swap_parameters(swap_type: SwapType) -> AVNUParams {
    let mut params = AVNUParams {
        token_from_address: STRK_TOKEN_ADDRESS(),
        token_from_amount: AMOUNT_TO_SWAP_STRK,
        token_to_address: USDT_TOKEN_ADDRESS(), 
        token_to_amount: 510000,
        token_to_min_amount: 510000 - 1000, // subtract a bit to give a margin
        beneficiary: ADDRESS_WITH_FUNDS(),
        integrator_fee_amount_bps: 0,
        integrator_fee_recipient: contract_address_const::<0>(),
        routes: array![
            Route {
                token_from: STRK_TOKEN_ADDRESS(),
                token_to: USDT_TOKEN_ADDRESS(),
                exchange_address: JEDISWAP_ROUTER_V2(),
                percent: 1000000000000,
                additional_swap_params: array![
                    0xb74193526135104973a1e285bb0372adf41a5d7a8fc5e6f30ea535847613ce,
                    1018588075927140995502,
                    3000
                ],
            }
        ]
    };

    match swap_type {
        SwapType::strk_usdt => {
            params = AVNUParams {
                token_from_address: STRK_TOKEN_ADDRESS(),
                token_from_amount: AMOUNT_TO_SWAP_STRK,
                token_to_address: USDT_TOKEN_ADDRESS(), 
                token_to_amount: 510000,
                token_to_min_amount: 510000 - 1000, // subtract a bit to give a margin
                beneficiary: ADDRESS_WITH_FUNDS(),
                integrator_fee_amount_bps: 0,
                integrator_fee_recipient: contract_address_const::<0>(),
                routes: array![
                    Route {
                        token_from: STRK_TOKEN_ADDRESS(),
                        token_to: USDT_TOKEN_ADDRESS(),
                        exchange_address: JEDISWAP_ROUTER_V2(),
                        percent: 1000000000000,
                        additional_swap_params: array![
                            0xb74193526135104973a1e285bb0372adf41a5d7a8fc5e6f30ea535847613ce,
                            1018588075927140995502,
                            3000
                        ],
                    }
                ]
            };
        },
        SwapType::strk_usdc => {
            params = AVNUParams {
                token_from_address: STRK_TOKEN_ADDRESS(),
                token_from_amount: AMOUNT_TO_SWAP_STRK,
                token_to_address: USDC_TOKEN_ADDRESS(), 
                token_to_amount: 465080,
                token_to_min_amount: 465080 - 1000, // subtract a bit to give a margin
                beneficiary: ADDRESS_WITH_FUNDS(),
                integrator_fee_amount_bps: 0,
                integrator_fee_recipient: contract_address_const::<0>(),
                routes: array![
                    Route {
                        token_from: STRK_TOKEN_ADDRESS(),
                        token_to: USDC_TOKEN_ADDRESS(),
                        exchange_address: contract_address_const::<0x41fd22b238fa21cfcf5dd45a8548974d8263b3a531a60388411c5e230f97023>(), // JediSwap: AMM Swap
                        percent: 1000000000000,
                        additional_swap_params: array![
                            
                        ],
                    }
                ]
            };
        },
        SwapType::eth_usdt => {},
        SwapType::eth_usdc => {},
    };

    params
}


#[derive(Drop, Serde, Debug)]
struct AVNUParams {
    token_from_address: ContractAddress,
    token_from_amount: u256,
    token_to_address: ContractAddress,
    token_to_amount: u256,
    token_to_min_amount: u256,
    beneficiary: ContractAddress,
    integrator_fee_amount_bps: u128,
    integrator_fee_recipient: ContractAddress,
    routes: Array<Route>,
}

#[derive(Drop, Serde, Clone, Debug)]
struct WalletAmounts {
    strk: u256,
    eth: u256,
    usdt: u256,
    usdc: u256,
}

#[derive(Drop, Serde, Clone, Debug)]
enum SwapType {
    strk_usdt,
    strk_usdc,
    eth_usdt,
    eth_usdc
}

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> IAutoSwapprDispatcher {
    let auto_swappr_class_hash = declare("AutoSwappr").unwrap().contract_class();

    let mut auto_swappr_constructor_calldata: Array<felt252> = array![
        FEE_COLLECTOR,
        AVNU_EXCHANGE_ADDRESS().into(),
        FIBROUS_EXCHANGE_ADDRESS().into(),
        STRK_TOKEN_ADDRESS().into(),
        ETH_TOKEN_ADDRESS().into(),
        OWNER,
    ];

    let (auto_swappr_contract_address, _) = auto_swappr_class_hash
        .deploy(@auto_swappr_constructor_calldata)
        .unwrap();

    let autoSwappr_dispatcher = IAutoSwapprDispatcher {
        contract_address: auto_swappr_contract_address,
    };

    start_cheat_caller_address(auto_swappr_contract_address, OWNER.try_into().unwrap());
    autoSwappr_dispatcher.set_operator(ADDRESS_WITH_FUNDS());
    stop_cheat_caller_address(auto_swappr_contract_address);

    autoSwappr_dispatcher
}

// test based on this tx -> https://starkscan.co/tx/0x014ed3ebca0d2f1bc33b025da8fb4547f1d45e1b7d1681262e6756bbd698b03a
#[test]
#[fork(url: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7", block_number: 996491)]
fn test_avnu_swap_strk_to_usdt() {
    let autoSwappr_dispatcher = __setup__();

    let previous_amounts = get_wallet_amounts(ADDRESS_WITH_FUNDS());

    approve_amount(
        STRK_TOKEN().contract_address,
        ADDRESS_WITH_FUNDS(),
        autoSwappr_dispatcher.contract_address,
        AMOUNT_TO_SWAP_STRK
    );

    let params = get_swap_parameters(SwapType::strk_usdt);
    
    call_avnu_swap(
        autoSwappr_dispatcher,
        params.token_from_address,
        params.token_from_amount,
        params.token_to_address,
        params.token_to_amount,
        params.token_to_min_amount,
        params.beneficiary,
        params.integrator_fee_amount_bps,
        params.integrator_fee_recipient,
        params.routes
    );
    let new_amounts = get_wallet_amounts(ADDRESS_WITH_FUNDS());

    // asserts
    assert_eq!(
        new_amounts.strk,
        previous_amounts.strk - AMOUNT_TO_SWAP_STRK,
        "Balance of from token should decrease"
    );
    
    assert_ge!(
        new_amounts.usdt,
        previous_amounts.usdt + (params.token_to_min_amount - 1000),
        "Balance of to token should increase"
    );
}

#[test]
#[fork(url: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7", block_number: 996957)]
fn test_avnu_swap_strk_to_usdc() {
    let autoSwappr_dispatcher = __setup__();

    let previous_amounts = get_wallet_amounts(ADDRESS_WITH_FUNDS());

    approve_amount(
        STRK_TOKEN().contract_address,
        ADDRESS_WITH_FUNDS(),
        autoSwappr_dispatcher.contract_address,
        AMOUNT_TO_SWAP_STRK
    );

    let params = get_swap_parameters(SwapType::strk_usdc);
    
    call_avnu_swap(
        autoSwappr_dispatcher,
        params.token_from_address, 
        params.token_from_amount,
        params.token_to_address,
        params.token_to_amount,
        params.token_to_min_amount,
        params.beneficiary,
        params.integrator_fee_amount_bps,
        params.integrator_fee_recipient,
        params.routes
    );
    let new_amounts = get_wallet_amounts(ADDRESS_WITH_FUNDS());

    // asserts
    assert_eq!(
        new_amounts.strk,
        previous_amounts.strk - AMOUNT_TO_SWAP_STRK,
        "Balance of from token should decrease"
    );
    
    assert_ge!(
        new_amounts.usdc,
        previous_amounts.usdc + (params.token_to_min_amount - 1000),
        "Balance of to token should increase"
    );
}

