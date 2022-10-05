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
from starkware.cairo.common.math import unsigned_div_rem, assert_lt, sqrt
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
func TestEvent(
    Testing: Uint256,
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
func Rampage(monster_id: Uint256, xp : felt, hp : felt) {
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

    @external
    func initialize_monster_module_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
        Module.initialize_monster_module_address();
        return ();
    }

    @view   
    func monster_module_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (address: felt) {
        alloc_locals;
        let (address) = Module.monster_module_address();
        return (address=address);
    }

    @view
    func get_controller_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (address: felt) {
        alloc_locals;
        let (address) = Module.controller_address();
        return (address=address);
    }

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
    
    // Check moster and army in same realm
    with_attr error_message("Rampage: monster and army not in same realm") {
        let (is_equal) = uint256_eq(attacking_monster_realm_id, defending_realm_id);
        assert is_equal = TRUE;
    }
    // Check if monster have reach the destination

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

    // check if the fighting realms have enough food, otherwise
    // decrease whole squad vitality by 50%

    // TODO: Food penalty for defending army

    //Fetch monster and army data
    //let (monsters_address) = Module.get_external_contract_address(ExternalContractIds.Monsters);
    //local proxy_monsters_address : felt = 2534540160167813445908987233284672622400780377302960773553458893608298939858;
    local monsters_address : felt = 1851722307445274121426274037651646728075363432698945473665987984925398082145;
    //debugger(monsters_address);
    let (starting_monster_data: MonsterData) = IMonsters.fetch_monster_data(
        //contract_address=monsters_address, token_id=attacking_monster_id
        1851722307445274121426274037651646728075363432698945473665987984925398082145, Uint256(1, 0)
    );

    debugger(starting_monster_data.attack_power);

    let (combat_address) = Module.get_module_address(ModuleIds.Combat);
    debugger(combat_address);
    let (defending_realm_data: ArmyData) = ICombat.get_realm_army_combat_data(
        contract_address=combat_address, army_id=defending_army_id, realm_id=defending_realm_id
    );

    //debugger(starting_monster_data.attack_power);

    // unpack defending army
    let (starting_defending_army: Army) = Combat.unpack_army(defending_realm_data.ArmyPacked);

    // emit rampage start event
    RampageStart.emit(
        attacking_monster_id,
        defending_army_id,
        defending_realm_id,
        starting_defending_army,
    );

    let ending_monster_data = starting_monster_data;
    let (
        combat_outcome, ending_defending_army_packed
    ) = MonsterRampage.calculate_winner(
        starting_monster_data, defending_realm_data.ArmyPacked
    );

    let (ending_defending_army: Army) = Combat.unpack_army(ending_defending_army_packed);

    // rampage only if monster wins
    let (now) = get_block_timestamp();
    tempvar monster_xp = 0;
    tempvar defending_xp = 0;
    let monster_hp = 0;
    
    
    if (combat_outcome == COMBAT_OUTCOME_ATTACKER_WINS) {
        
        // Reduce defending realm resource
        let (controller) = Module.controller_address();
        let (resources_logic_address) = IModuleController.get_module_address(
            controller, ModuleIds.Resources
        );       
        let (caller) = get_caller_address();
        IResources.rampage_resources(resources_logic_address, defending_realm_id);

        //Monster Win - calculate monster remaining hp 
        
        let (base_hp) = IMonsters.get_base_hp(monsters_address, starting_monster_data.monster_class);
        let (remaining_hp) = MonsterRampage.calculate_remaining_hp(base_hp, starting_monster_data.rarity, starting_monster_data.defence_power, TRUE);
        monster_hp = remaining_hp;
        monster_xp = MONSTER_XP.ATTACKING_MONSTER_WIN_XP;
        defending_xp = DEFENDING_ARMY_XP;

        //  TO DO:
        //  Further reduce monster HP based on defending army attack power.

    } else {
        //Monster Lost - calculate monster remaining hp
        let (base_hp) = IMonsters.get_base_hp(monsters_address, starting_monster_data.monster_class);
        let (remaining_hp) = MonsterRampage.calculate_remaining_hp(base_hp, starting_monster_data.rarity, starting_monster_data.defence_power, FALSE);
        monster_hp = remaining_hp;
        monster_xp = MONSTER_XP.ATTACKING_MONSTER_LOSE_XP;
        defending_xp = ATTACKING_ARMY_XP;
    }

    ending_monster_data.hp = monster_hp;
    ending_monster_data.xp = ending_monster_data.xp + monster_xp;
    defending_realm_data.XP = defending_realm_data.XP + defending_xp;

    // store new monster values with reduced HP and added XP
    set_monster_data_and_emit(
        attacking_monster_id,
        ending_monster_data,
    );

    // store new army values with added XP
    set_army_data_and_emit(
        defending_army_id,
        defending_realm_id,
        ArmyData(ending_defending_army_packed, now, defending_realm_data.XP, defending_realm_data.Level, defending_realm_data.CallSign),
    );

    // emit end
    

    RampageEnd.emit(
        combat_outcome,
        attacking_monster_id,
        defending_army_id,
        defending_realm_id,
        ending_defending_army,
    );

    return (combat_outcome,);
}

// -----------------------------------
// Internal
// -----------------------------------
func debugger{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tester: felt) -> (
    ) {
        with_attr error_message("tester att= {tester}" ) {
            assert 1=0;
        }
        return ();
    }

// @notice saves data and emits the changed metadata for cache
// @param army_id: Army ID
// @param realm_id: Realm ID
// @param army_data: Army metadata
func set_army_data_and_emit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    army_id: felt, realm_id: Uint256, army_data: ArmyData
) {
    alloc_locals;
    let (controller) = Module.controller_address();
    let (combat_module_address) = IModuleController.get_module_address(controller, ModuleIds.Combat);
    ICombat.set_army_data_and_emit(
        combat_module_address, army_id, realm_id, army_data
    );
    return ();
}

func set_monster_data_and_emit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    monster_id: Uint256, monster_data: MonsterData
) {
    alloc_locals;

    let packed_monster_stats=0;    
    let (monsters_address) = Module.get_external_contract_address(ExternalContractIds.Monsters);

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

