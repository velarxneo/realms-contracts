# -----------------------------------
# ____MODULE_L07___CRYPTS_LOGIC
#   Staking/Unstaking a crypt.
#
# MIT License
# -----------------------------------

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
)
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc721.interfaces.IERC721 import IERC721
from openzeppelin.upgrades.library import (
    Proxy_initializer,
    Proxy_only_admin,
    Proxy_set_implementation,
)

from contracts.settling_game.utils.game_structs import ModuleIds, ExternalContractIds
from contracts.settling_game.utils.constants import TRUE
from contracts.settling_game.library.library_module import Module
from contracts.settling_game.interfaces.IStakedCryptsERC721 import IStakedCryptsERC721
from contracts.settling_game.interfaces.imodules import IModuleController, IL08CryptsResources


# -----------------------------------
# EVENTS
# -----------------------------------

# Staked = 🗝️ unlocked
# Unstaked = 🔒 locked (because Lore ofc)

@event
func Settled(owner : felt, token_id : Uint256):
end

@event
func UnSettled(owner : felt, token_id : Uint256):
end

# -----------------------------------
# STORAGE
# -----------------------------------

#@notice STAKE TIME - This is used as the main identifier for staking time
#  It is updated on Resource Claim, Stake, Unstake
@storage_var
func time_staked(token_id : Uint256) -> (time : felt):
end

# -----------------------------------
# CONSTRUCTOR
# -----------------------------------

#@notice Module initializer
#@param address_of_controller: Controller/arbiter address
#@proxy_admin: Proxy admin address
@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address_of_controller : felt, proxy_admin : felt
):
    MODULE_initializer(address_of_controller)
    Proxy_initializer(proxy_admin)
    return ()
end

#@notice Set new proxy implementation
#@dev Can only be set by the arbiter
#@param new_implementation: New implementation contract address
@external
func upgrade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_implementation : felt
):
    Proxy_only_admin()
    Proxy_set_implementation(new_implementation)
    return ()
end

# -----------------------------------
# EXTERNAL
# -----------------------------------

#@notice Settles crypt
#@param token_id: Crypt token id
#@return success: 1 if successful, 0 otherwise
@external
func settle{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (success : felt):
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_contract_address()
    let (contract_address) = get_contract_address()

    let (crypts_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Crypts
    )
    let (s_crypts_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.StakedCrypts
    )

    # TRANSFER CRYPT
    IERC721.transferFrom(crypts_address, caller, contract_address, token_id)

    # MINT S_CRYPT
    IStakedCryptsERC721.mint(s_crypts_address, caller, token_id)

    # SETS TIME STAKED FOR FUTURE CLAIMS
    _set_time_staked(token_id, 0)

    # EMIT
    Settled.emit(caller, token_id)

    return (TRUE)
end

#@notice Unsettle crypt
#@param token_id: Staked crypt token id
#@return success: 1 if successful, 0 otherwise
@external
func unsettle{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (success : felt):
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_contract_address()
    let (contract_address) = get_contract_address()

    # FETCH ADDRESSES
    let (crypts_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Crypts
    )
    let (s_crypts_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.StakedCrypts
    )

    let (resource_logic_address) = IModuleController.get_module_address(
        controller, ModuleIds.L08CryptsResources
    )

    # CHECK NO PENDING RESOURCES
    let (can_claim) = IL08CryptRResources.check_if_claimable(resource_logic_address, token_id)

    if can_claim == TRUE:
        IL08CryptsResources.claim_resources(resource_logic_address, token_id)
        _set_time_staked(token_id, 0)
    else:
        _set_time_staked(token_id, 0)
    end

    # TRANSFER CRYPT BACK TO OWNER
    IERC721.transferFrom(crypts_address, contract_address, caller, token_id)

    # BURN S_CRYPT
    IStakedCryptsERC721.burn(s_crypts_address, token_id)

    # EMIT
    UnSettled.emit(caller, token_id)

    return (TRUE)
end

#@notice TIME_LEFT -> WHEN PLAYER CLAIMS, THIS IS THE REMAINDER TO BE PASSED BACK INTO STORAGE
#  THIS ALLOWS FULL DAYS TO BE CLAIMED ONLY AND ALLOWS LESS THAN FULL DAYS TO CONTINUE ACCRUREING
#@param token_id: Staked crypt token id
#@param time_left: Time less than 1 day
@external
func set_time_staked{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256, time_left : felt
):
    Module.only_approved()
    _set_time_staked(token_id, time_left)
    return ()
end

# -----------------------------------
# INTERNAL
# -----------------------------------

#@notice Internal set time staked
#@param token_id: Staked crypt token id
#@param time_left: Time less than 1 day
func _set_time_staked{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256, time_left : felt
):
    let (block_timestamp) = get_block_timestamp()
    time_staked.write(token_id, block_timestamp - time_left)
    return ()
end

# -----------------------------------
# GETTERS
# -----------------------------------

#@notice get_time_staked
#@param token_id: Staked crypt token id
#@return time: Staked time
@view
func get_time_staked{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (time : felt):
    let (time) = time_staked.read(token_id)

    return (time=time)
end
