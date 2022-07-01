# Crafting Library
#   Helper functions for staking.
#
#
# MIT License

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp
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
    Cost,
)

namespace Crafting:
    # @notice gets current relic holder
    # @implicit syscall_ptr
    # @implicit range_check_ptr
    # @param relic_id: id of relic, pass in realm id
    # @return token_id: returns realm id of owning relic

    func calculate_crafting_cost{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(item_cost : Cost) -> (token_len : felt, token_ids : Uint256*, token_values : Uint256*):
        alloc_locals

        let (costs : Cost*) = alloc()
        assert [costs] = item_cost
        let (token_ids : Uint256*) = alloc()
        let (token_values : Uint256*) = alloc()

        let (token_len) = transform_costs_to_token_ids_values(1, costs, token_ids, token_values)
        return (token_len, token_ids, token_values)
    end
end
