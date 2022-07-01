# Crafting Library
#   Helper functions for staking.
#
#
# MIT License

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.uint256 import Uint256, uint256_eq
from contracts.settling_game.utils.constants import TRUE

namespace Crafting:
    # @notice gets current relic holder
    # @implicit syscall_ptr
    # @implicit range_check_ptr
    # @param relic_id: id of relic, pass in realm id
    # @return token_id: returns realm id of owning relic

    func craft_item{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        item_id : felt, crafter : felt
    ) -> (created_id : felt):
        alloc_locals

        # get item_id to mint

        # get recipe

        # # done in contract
        # burning inputs
        # minting output

        return (1)
    end
end
