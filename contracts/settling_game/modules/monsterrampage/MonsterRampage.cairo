// -----------------------------------
//   Module.MonsterRampage
//   Logic around Monster Rampage system

// ELI5:
//   Monster Rampage revolves around Monster fighting Defending Army in a Realm.
//   Monsters roam around Eternum randomly by travelling to realms which is 1 hour away from their current position (Create Move button for hackathon, can create batch eventually to simulate Move once rampage completes)
//   A Realm can have many Armies, but Monster only rampage the Realm which it is currently situated (Create Rampage button, can create batch eventually to simulate Rampage once Mint/Move completes)
//   Army ID 0 is reserved for your defending Army, and it cannot move.
//   Monsters gain XP and reduce Realm's resources if rampaged successfully. Monster dies and loses the battle if HP drops to 0.
//   Monsters HP regenerate over time when not in battle
//   Both Monster and Defending Army must exist at the same coordinates in order to battle.
//
//   If monster lose the battle, reduce (60% divide by squareroot(rarity)) of base HP, if win, reduce (30% divide by squareroot(rarity)) of base HP
//   During battle, (monster attack power * 5 + luck) vs (defending army (armyID=0) defence power + luck), this will determine outcome
//

// MIT License
// -----------------------------------

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, assert_lt, sqrt, assert_lt_felt, assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256, uint256_eq
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address

from openzeppelin.upgrades.library import Proxy
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.token.erc721.IERC721 import IERC721

from contracts.settling_game.interfaces.IERC1155 import IERC1155

from contracts.settling_game.library.library_module import Module
from contracts.settling_game.modules.combat.library import Combat
from contracts.settling_game.modules.monsterrampage.library import MonsterRampage
from contracts.settling_game.interfaces.imodules import IModuleController

from contracts.settling_game.utils.general import transform_costs_to_tokens

// from contracts.settling_game.modules.goblintown.interface import IGoblinTown
from contracts.settling_game.modules.food.interface import IFood
// from contracts.settling_game.modules.relics.interface import IRelics
from contracts.settling_game.modules.travel.interface import ITravel
from contracts.settling_game.modules.resources.interface import IResources
from contracts.settling_game.modules.Combat.interface import ICombat
// from contracts.settling_game.modules.buildings.interface import IBuildings
from contracts.settling_game.interfaces.ixoroshiro import IXoroshiro
from contracts.settling_game.interfaces.IMonsters import IMonsters

from contracts.settling_game.modules.monsterrampage.constants import (
    HP_REDUCTION,
    ATTACK_LUCK_RANGE_MULTIPLIER,
    DEFENCE_LUCK_HP_REDUCTION_MODIFIER,
    MONSTER_XP,
)

from contracts.settling_game.utils.constants import (
    ATTACK_COOLDOWN_PERIOD,
    COMBAT_OUTCOME_ATTACKER_WINS,
    COMBAT_OUTCOME_DEFENDER_WINS,
    GOBLINDOWN_REWARD,
    DEFENDING_ARMY_XP,
    ATTACKING_ARMY_XP,
    TOTAL_BATTALIONS,
)
from contracts.settling_game.utils.game_structs import (
    MonsterData,
    ModuleIds,
    RealmData,
    RealmBuildings,
    Cost,
    ExternalContractIds,
    Battalion,
    Army,
    ArmyData,
)

const monsters_address = 2508856039100541254009953359129988050649979317977035860356928697654489929628;
const combat_address = 2118877636712268396913981595473669875214988212675356303776187676728991725018;
const resources_address = 2404238135091974935271797017420481573833122634562961073751070621061294700469;

// -----------------------------------
// Events
// -----------------------------------

@event
func RampageStart(
    attacking_monster_id: Uint256,
    defending_army_id: felt,
    defending_realm_id: Uint256,
    defending_army: Army,
) {
}

@event
func RampageEnd(
    combat_outcome: felt,
    attacking_monster_id: Uint256,
    defending_army_id: felt,
    defending_realm_id: Uint256,
    defending_army: Army,
) {
}

@event
func Move(monster_id: Uint256, realmId : felt) {
}


// -----------------------------------
// Storage
// -----------------------------------


@storage_var
func xoroshiro_address() -> (address: felt) {
}


@storage_var
func ending_monster_data() -> (monsterData: MonsterData) {
}




// -----------------------------------
// Initialize & upgrade
// -----------------------------------

// @notice Module initializer
// @param address_of_controller: Controller/arbiter address
// @proxy_admin: Proxy admin address
@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address_of_controller: felt, proxy_admin: felt
) {
    Module.initializer(address_of_controller);
    Proxy.initializer(proxy_admin);
    return ();
}

// Testing purpose

    // @external
    // func initialize_monster_module_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    // ) {
    //     Module.initialize_monster_module_address();
    //     return ();
    // }

    // @view   
    // func monster_module_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    // ) -> (address: felt) {
    //     alloc_locals;
    //     let (address) = Module.monster_module_address();
    //     return (address=address);
    // }

    // @view
    // func get_controller_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    // ) -> (address: felt) {
    //     alloc_locals;
    //     let (address) = Module.controller_address();
    //     return (address=address);
    // }

// Testing purpose End





// @notice Set new proxy implementation
// @dev Can only be set by the arbiter
// @param new_implementation: New implementation contract address
@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}


// -----------------------------------
// External
// -----------------------------------

func debugger{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tester: felt) -> (
) {
    with_attr error_message("tester att= {tester}") {
        assert 1=0;
    }
    return ();
}

// @notice Commence the attack
// @param attacking_realm_id: Staked Realm id (S_Realm)
// @param defending_realm_id: Staked Realm id (S_Realm)
// @return: combat_outcome: Which side won - either the attacker (COMBAT_OUTCOME_ATTACKER_WINS)
//                          or the defender (COMBAT_OUTCOME_DEFENDER_WINS)
@external
func initiate_rampage{
    range_check_ptr, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*
}(
    attacking_monster_id: Uint256,
    attacking_monster_realm_id: Uint256,
    defending_army_id: felt,
    defending_realm_id: Uint256,
) -> (combat_outcome: felt) {
    alloc_locals;
    
    // Check monster and army in same realm
    with_attr error_message("Rampage: Monster and Army not in same Realm") {
        let (is_equal) = uint256_eq(attacking_monster_realm_id, defending_realm_id);
        assert is_equal = TRUE;
    }

    // TODO: Check if monster have reach the destination
    // let (travel_module) = Module.get_module_address(ModuleIds.Travel);
    // ITravel.assert_traveller_is_at_location(
    //     travel_module,
    //     ExternalContractIds.S_Realms,
    //     attacking_realm_id,
    //     attacking_army_id,
    //     ExternalContractIds.S_Realms,
    //     defending_realm_id,
    //     defending_army_id,
    // );

    // TODO: Food penalty for defending army
    // check if the fighting realms have enough food, otherwise
    // decrease whole squad vitality by 50%

    //Fetch monster and army data
    //let (monsters_address) = Module.get_external_contract_address(ExternalContractIds.Monsters);    
    let (starting_monster_data: MonsterData) = IMonsters.fetch_monster_data(
        contract_address=monsters_address, token_id=attacking_monster_id);

    // Check monster is alive (HP more than 0)
    with_attr error_message("Rampage: Monster is dead") {
        assert_nn(starting_monster_data.hp - 1);
    }

    //let (combat_address) = Module.get_module_address(ModuleIds.L06_Combat);
    let (defending_realm_data: ArmyData) = ICombat.get_realm_army_combat_data(
        contract_address=combat_address, army_id=defending_army_id, realm_id=defending_realm_id
    );

    // unpack defending army
    let (starting_defending_army: Army) = Combat.unpack_army(defending_realm_data.ArmyPacked);

    // emit Rampage Start event
    RampageStart.emit(
        attacking_monster_id,
        defending_army_id,
        defending_realm_id,
        starting_defending_army,
    );

    let (
        combat_outcome, ending_defending_army_packed
    ) = MonsterRampage.calculate_winner(
        starting_monster_data, defending_realm_data.ArmyPacked
    );

    let (ending_defending_army: Army) = Combat.unpack_army(ending_defending_army_packed);

    let (now) = get_block_timestamp();
    
    // rampage only if monster wins
    if (combat_outcome == COMBAT_OUTCOME_ATTACKER_WINS) {
        
        // Monster Win - Reduce defending realm resource
        // let (controller) = Module.controller_address();
        // let (resources_address) = IModuleController.get_module_address(
        //     controller, ModuleIds.Resources);
        
        IResources.rampage_resources(resources_address, defending_realm_id);

        //Monster Win - calculate monster remaining hp         
        let (base_hp) = IMonsters.get_base_hp(monsters_address, starting_monster_data.monster_class);                
        let (remaining_hp) = MonsterRampage.calculate_remaining_hp(base_hp, 
                                                                starting_monster_data, 
                                                                TRUE);
      
        let ending_monster_data = MonsterData(
            realmId=starting_monster_data.realmId,
            name=starting_monster_data.name,
            monster_class=starting_monster_data.monster_class,
            rarity=starting_monster_data.rarity,
            level=starting_monster_data.level,
            xp=starting_monster_data.xp + MONSTER_XP.ATTACKING_MONSTER_WIN_XP,
            hp=remaining_hp,
            attack_power=starting_monster_data.attack_power,
            defence_power=starting_monster_data.defence_power,
        );

        //update monster with reduced HP and added XP       
        set_monster_data_and_emit(attacking_monster_id, ending_monster_data);
    
        //  TO DO:
        //  Further reduce monster HP based on defending army attack power.

        //store new army values with added XP
        let new_defending_army_xp = defending_realm_data.XP + DEFENDING_ARMY_XP;   //30
        
        set_army_data_and_emit(
            defending_army_id,
            defending_realm_id,
            ArmyData(ending_defending_army_packed, 
                    now, 
                    new_defending_army_xp, 
                    defending_realm_data.Level, 
                    defending_realm_data.CallSign),
        );

        //emit Rampage End event
        RampageEnd.emit(
            combat_outcome,
            attacking_monster_id,
            defending_army_id,
            defending_realm_id,
            ending_defending_army,
        );

        return (combat_outcome,);

    } else {
        //Monster Lost - calculate monster remaining hp
        let (base_hp) = IMonsters.get_base_hp(monsters_address, starting_monster_data.monster_class);
        let (remaining_hp) = MonsterRampage.calculate_remaining_hp(base_hp, 
                                                                starting_monster_data, 
                                                                FALSE);
                                                                
        let ending_monster_data = MonsterData(
            realmId=starting_monster_data.realmId,
            name=starting_monster_data.name,
            monster_class=starting_monster_data.monster_class,
            rarity=starting_monster_data.rarity,
            level=starting_monster_data.level,
            xp=starting_monster_data.xp + MONSTER_XP.ATTACKING_MONSTER_LOSE_XP,
            hp=remaining_hp,
            attack_power=starting_monster_data.attack_power,
            defence_power=starting_monster_data.defence_power,
        );

        //update monster with reduced HP and added XP       
        set_monster_data_and_emit(attacking_monster_id, ending_monster_data);
    
        //  TO DO:
        //  Further reduce monster HP based on defending army attack power.

        //store new army values with added XP
        let new_defending_army_xp = defending_realm_data.XP + ATTACKING_ARMY_XP;   //100
        
        set_army_data_and_emit(
            defending_army_id,
            defending_realm_id,
            ArmyData(ending_defending_army_packed, 
                    now, 
                    new_defending_army_xp, 
                    defending_realm_data.Level, 
                    defending_realm_data.CallSign),
        );

        //emit Rampage End event
        RampageEnd.emit(
            combat_outcome,
            attacking_monster_id,
            defending_army_id,
            defending_realm_id,
            ending_defending_army,
        );

        return (combat_outcome,);
    }
    //TODO: If Monster HP is less than or equal to zero, we need to burn the token
}

// -----------------------------------
// Internal
// -----------------------------------


// @notice saves data and emits the changed metadata for cache
// @param army_id: Army ID
// @param realm_id: Realm ID
// @param army_data: Army metadata
func set_army_data_and_emit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    army_id: felt, realm_id: Uint256, army_data: ArmyData
) -> () {
    alloc_locals;

    //let (controller) = Module.controller_address();
    //let (combat_address) = IModuleController.get_module_address(controller, ModuleIds.Combat);
    
    ICombat.set_army_data_and_emit(
        combat_address, army_id, realm_id, army_data
    );
    return ();
}

func set_monster_data_and_emit{
    range_check_ptr, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*}(
    monster_id: Uint256, monster_data: MonsterData
) -> () {
    alloc_locals;

    //let (monsters_address) = Module.get_external_contract_address(ExternalContractIds.Monsters);
    
    IMonsters.set_monster_data_and_emit(
        monsters_address, monster_id, monster_data
    );

    return ();
}


// -----------------------------------
// Getters
// -----------------------------------



//########
// ADMIN #
//########

@external
func set_xoroshiro{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    xoroshiro: felt
) {
    Proxy.assert_only_admin();
    xoroshiro_address.write(xoroshiro);
    return ();
}

