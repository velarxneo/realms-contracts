# -----------------------------------
# Proxy logic for modules
#   This allows for module upgrades.
#
# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (upgrades/Proxy.cairo)
# -----------------------------------

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import delegate_l1_handler, delegate_call
from openzeppelin.upgrades.library import (
    Proxy_implementation_address,
    Proxy_set_implementation,
    Proxy_only_admin,
    Proxy_set_admin,
)

# -----------------------------------
# Constructor
# -----------------------------------

#@notice Constructor for proxy contract
#@param implementation_address: Address of target contract
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    implementation_address : felt
):
    Proxy_set_implementation(implementation_address)
    return ()
end

# -----------------------------------
# Fallback functions
# -----------------------------------

#@notice Fallback function for routing txs to the target contract
#@param selector: Function in the target contract
#@param calldata_size: Number of calldata elements
#@param calldata: Call data
#@return retdata_size: Number of returndata elements
#@return redata: Return data
@external
@raw_input
@raw_output
func __default__{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    selector : felt, calldata_size : felt, calldata : felt*
) -> (retdata_size : felt, retdata : felt*):
    let (address) = Proxy_implementation_address.read()

    let (retdata_size : felt, retdata : felt*) = delegate_call(
        contract_address=address,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    )

    return (retdata_size=retdata_size, retdata=retdata)
end
