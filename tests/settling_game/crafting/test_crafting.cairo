%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.math_cmp import is_nn, is_le
from starkware.cairo.common.math import unsigned_div_rem, signed_div_rem

from contracts.settling_game.crafting.library_crafting import Crafting

@external
func test_craft_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    # state called
    let _id = 2
    let crafter = 2

    let (id) = Crafting.craft_item(_id, crafter)

    %{ print('Id: ', ids.id) %}

    return ()
end
