%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.math_cmp import is_nn, is_le
from starkware.cairo.common.math import unsigned_div_rem, signed_div_rem

from contracts.settling_game.crafting.library_crafting import Crafting

from contracts.settling_game.utils.game_structs import (
    RealmBuildings,
    RealmBuildingsSize,
    BuildingsIntegrityLength,
    BuildingsDecaySlope,
    PackedBuildings,
    RealmBuildingsIds,
    Cost,
)

namespace ItemCost:
    const ResourceCount = 6
    const Bits = 8
    const PackedIds = 24279735796225
    const PackedValues = 1103977649202
end

@external
func test_craft_item{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}():
    # state called
    let test_item_cost = Cost(
        ItemCost.ResourceCount, ItemCost.Bits, ItemCost.PackedIds, ItemCost.PackedValues
    )

    let (
        token_len : felt, token_ids : Uint256*, token_values : Uint256*
    ) = Crafting.calculate_crafting_cost(test_item_cost)
    
    assert token_ids[0].low = 1

    assert token_values[0].low = 50 * 10 ** 18

    # %{ print('Id: ', ids.token_ids[0].low) %}

    return ()
end
