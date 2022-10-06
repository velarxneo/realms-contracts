%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import unsigned_div_rem, assert_lt, sqrt, assert_le
//from contracts.settling_game.interfaces.ixoroshiro import IXoroshiro
from starkware.cairo.common.bool import TRUE, FALSE

// from contracts.settling_game.modules.monsterrampage.constants import (
//     HP_REDUCTION,
//     ATTACK_LUCK_RANGE_MULTIPLIER,
//     DEFENCE_LUCK_HP_REDUCTION_MODIFIER,
// )

const XOROSHIRO_ADDR = 0x06c4cab9afab0ce564c45e85fe9a7aa7e655a7e0fd53b7aea732814f3a64fbee;

// @contract_interface
// namespace IXoroshiro {
//     func next() -> (rnd: felt) {
//     }
// }

namespace HP_REDUCTION {
    const BY_RARITY_LOSE = 60;
    const BY_DEFENCE_LOSE = 60;

    const BY_RARITY_WIN = 30;
    const BY_DEFENCE_WIN = 30;
}

// Attack is multiplied with a range from 450% to 550%
namespace ATTACK_LUCK_RANGE_MULTIPLIER {
    const FROM = 450;
    const TO = 550;
}

// HP is reduced with a range from 0 to 10
namespace DEFENCE_LUCK_HP_REDUCTION_MODIFIER {
     const FROM = 0;
    const TO = 10;
}


@external
func test_monster_hp_xp_and_emit{
    range_check_ptr, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*}(
    //monster_id : Uint256, monster_hp : felt, monster_xp :felt
) -> () {
    alloc_locals;

    //let (monsters_address) = Module.get_external_contract_address(ExternalContractIds.Monsters);
    //let monsters_address : felt = 1509297045747217933698049681079831571229035408084787121289867782562748537895;
    // let monsters_address : felt = 287363966152814976336240115418148318683481225000872875085812130458106439625;
    
    // IMonsters.set_monster_hp_xp_and_emit(
    //     monsters_address, monster_id, monster_hp, monster_xp
    // );
    assert 1=0;
    return ();
}


func test_remaining_hp{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    } () -> (remaining_hp : felt) {

         alloc_locals;
        let base_hp = 400;
        let rarity = 20;
        let defence = 40;
        let outcome = TRUE;

        //passed: debugger(outcome);

        let defence_luck=5;

        if (outcome == TRUE){
            let (hp_reduction) = hp_reduction_helper(HP_REDUCTION.BY_RARITY_WIN,base_hp,rarity) ;
            let (hp_further_reduction) = hp_reduction_helper(HP_REDUCTION.BY_DEFENCE_WIN,base_hp,defence) ;
            debugger(base_hp - hp_reduction - hp_further_reduction - defence_luck);
            return (base_hp - hp_reduction - hp_further_reduction - defence_luck,);

        } else {
            let (hp_reduction) = hp_reduction_helper(HP_REDUCTION.BY_RARITY_LOSE,base_hp,rarity) ;
            let (hp_further_reduction) = hp_reduction_helper(HP_REDUCTION.BY_DEFENCE_LOSE,base_hp,defence) ;
             
            return (base_hp - hp_reduction - hp_further_reduction - defence_luck,);
        }
        
    }

func hp_reduction_helper{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(reduce_percent: felt, base_hp : felt, factor : felt)->(hp_reduction: felt){
    alloc_locals;

    let (_, percent) = unsigned_div_rem(reduce_percent, 100);
    let (reduce_based_on_factor, _) = unsigned_div_rem(reduce_percent, sqrt(factor));
    let (hp_to_reduce, _) = unsigned_div_rem(base_hp*reduce_based_on_factor, 100);

    return (hp_to_reduce,);
}

func debugger{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(hp: felt){
    alloc_locals;

    with_attr error_message("tester = {hp}" ) {
        //assert_le(hp, 0);
        assert 1 = 0;
    }
    return ();
}

// func roll_dice{
//         syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
//     }(dice_roll_from : felt, dice_roll_to : felt) -> (result : felt) {
//         alloc_locals;
//         let xoroshiro_address_ = XOROSHIRO_ADDR;
//         let (rnd) = IXoroshiro.next(xoroshiro_address_);
    
//         let (_, r) = unsigned_div_rem(rnd, dice_roll_to-dice_roll_from);
//         return (r + dice_roll_from,);  // values from 1 to 12 inclusive
//     }