%lang starknet
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.math_cmp import is_nn, is_le
from starkware.cairo.common.math import unsigned_div_rem, signed_div_rem

from contracts.settling_game.crafting.library_crafting import Crafting

@external
func test_craft_item{syscall_ptr : felt*, range_check_ptr}():
    # state called
    let id = 2
    let crafter = 2

    let (id) = Crafting.craft_item(id, crafter)
    return ()
end
