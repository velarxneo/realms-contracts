# -----------------------------------
# Shared utility functions
#   Functions used throughout the settling game. This is not a contract.
#   Instead, items from this file should be imported into any module
#   that is a contract and used there.
#
# MIT License

# SPDX-License-Identifier: MIT
# Realms Contracts v0.0.1 (library.cairo)
# -----------------------------------

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_not_zero, assert_lt
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_le,
    uint256_lt,
    uint256_check,
)

from openzeppelin.token.erc721.interfaces.IERC721 import IERC721

from contracts.settling_game.interfaces.IModules import IModuleController

# -----------------------------------
# STORAGE #
# -----------------------------------

@storage_var
func controller_address() -> (address : felt):
end

namespace Module:
    #@notice Initialize contract and set controller address
    #@param address_of_controller: Admin address
    func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address_of_controller : felt
    ):
        controller_address.write(address_of_controller)
        return ()
    end

    # -----------------------------------
    # Getters
    # -----------------------------------

    #@notice Get controller address
    #@return address: Controller address
    func get_controller_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (address : felt):
        let (address) = controller_address.read()
        return (address)
    end

    # -----------------------------------
    # Checks
    # -----------------------------------

    #@notice Checks if the caller address == contract address
    #@return success: 1 if successful, 0 otherwise
    func check_self{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        success : felt
    ):
        let (caller) = get_caller_address()
        let (contract_address) = get_contract_address()

        if caller == contract_address:
            return (1)
        end

        return (0)
    end

    #@notice Checks if only approved addresses call the module
    #@dev Reverts when fail
    func only_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        alloc_locals
        let (success) = _only_approved()
        let (self) = check_self()
        with_attr error_message("Module library: the module is not approved AND the caller address is not the contract address"):
            assert_not_zero(success + self)
        end
        return ()
    end

    #@notice Checks if the arbiter calls the module
    #@dev Reverts when fail
    func only_arbiter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        alloc_locals
        let (success) = _only_arbiter()
        with_attr error_message("Module library: caller is not the arbiter"):
            assert_not_zero(success)
        end
        return ()
    end

    #@notice Checks if the ERC721 token belongs to the caller
    #@dev Reverts when fail
    #@param asset_id: ERC721 token id
    #@param name_space: Alias of the module
    func erc721_owner_check{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        asset_id : Uint256, name_space : felt
    ):
        let (caller) = get_caller_address()
        let (controller) = controller_address.read()
        let (address) = IModuleController.get_external_contract_address(controller, name_space)

        let (owner) = IERC721.ownerOf(address, asset_id)

        with_attr error_message("ERC721_ERROR: Not your asset"):
            assert caller = owner
        end
        return ()
    end

    # -----------------------------------
    # Internal
    # -----------------------------------

    #@notice Checks write access of module
    #@return success: 1 when successful, 0 otherwise
    func _only_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        success : felt
    ):
        let (caller) = get_caller_address()
        let (controller) = controller_address.read()

        # Pass this address on to the ModuleController
        # Will revert the transaction if not.
        let (success) = IModuleController.has_write_access(controller, caller)
        return (success)
    end

    #@notice Checks if the caller is the admin (arbiter)
    #@return success: 1 when successful, 0 otherwise
    func _only_arbiter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        success : felt
    ):
        alloc_locals
        let (controller) = controller_address.read()
        let (caller) = get_caller_address()
        let (current_arbiter) = IModuleController.get_arbiter(controller)

        if caller != current_arbiter:
            return (0)
        end

        return (1)
    end
end
