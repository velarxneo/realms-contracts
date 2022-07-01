# Crafting Library
#   Helper functions for staking.
#
#
# MIT License

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address
from starkware.cairo.common.uint256 import Uint256, uint256_eq
from starkware.cairo.common.alloc import alloc

from contracts.settling_game.utils.general import unpack_data, transform_costs_to_token_ids_values
from contracts.settling_game.utils.constants import TRUE
from contracts.settling_game.utils.game_structs import (
    RealmBuildings,
    RealmBuildingsSize,
    BuildingsIntegrityLength,
    BuildingsDecaySlope,
    PackedBuildings,
    RealmBuildingsIds,
    ExternalContractIds,
    Cost,
)
from contracts.settling_game.crafting.library_crafting import Crafting
from contracts.settling_game.interfaces.IERC1155 import IERC1155
from contracts.settling_game.interfaces.imodules import IModuleController

@storage_var
func item_cost(item_id : felt) -> (cost : Cost):
end

func craft_item{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(item_id : felt) -> (created_id : felt):
    alloc_locals

    # get item_id to mint
    let (caller) = get_caller_address()

    let (resource_address) = IModuleController.get_external_contract_address(
        222, ExternalContractIds.Resources
    )

    # get recipe
    let (cost) = item_cost.read(item_id)

    let (token_len, token_ids, token_values) = Crafting.calculate_crafting_cost(cost)

    # BURN RESOURCES
    IERC1155.burnBatch(resource_address, caller, token_len, token_ids, token_len, token_values)

    # minting output with item_id
    # item_IERC721.mint(12312, caller, item_id)

    return (1)
end
