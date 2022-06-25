# -----------------------------------
# ____MODULE_L04___CONTRACT_LOGIC
#   This modules focus is to calculate the values of the internal
#   multipliers so other modules can use them. The aim is to have this
#   as the core calculator controller that contains no state.
#   It is pure math.
#
# MIT License
# -----------------------------------

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_nn_le, is_nn, is_le
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.upgrades.library import (
    Proxy_initializer,
    Proxy_only_admin,
    Proxy_set_implementation,
)

from contracts.settling_game.utils.game_structs import (
    RealmBuildings,
    RealmCombatData,
)
from contracts.settling_game.utils.constants import (
    BASE_LORDS_PER_DAY,
    VAULT_LENGTH_SECONDS,
    ModuleIds,
    BuildingFoodEffect,
    BuildingPopulationEffect,
    BuildingCultureEffect,
)
from contracts.settling_game.interfaces.IModules import (
    IModuleController,
    IL01Settling,
    IL03Buildings,
    IL06Combat,
)
from contracts.settling_game.library.library_module import Module
from contracts.settling_game.library.library_calculator import Calculator
from contracts.settling_game.library.library_combat import Combat

# -----------------------------------
# CONSTRUCTOR
# -----------------------------------

#@notice Module initializer
#@param address_of_controller: Controller/arbiter address
#@proxy_admin: Proxy admin address
@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address_of_controller : felt, proxy_admin : felt
):
    Module.initializer(address_of_controller)
    Proxy_initializer(proxy_admin)
    return ()
end

#@notice Set new proxy implementation
#@dev Can only be set by the arbiter
#@param new_implementation: New implementation contract address
@external
func upgrade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_implementation : felt
):
    Proxy_only_admin()
    Proxy_set_implementation(new_implementation)
    return ()
end

# -----------------------------------
# CALCULATORS #
# -----------------------------------

#@notice Calculate epoch
#@return Epoch
@view
func calculate_epoch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    epoch : felt
):
    # CALCULATE EPOCH
    let (controller) = Module.get_controller_address()
    let (genesis_time_stamp) = IModuleController.get_genesis(controller)
    let (block_timestamp) = get_block_timestamp()

    let (epoch, _) = unsigned_div_rem(block_timestamp - genesis_time_stamp, VAULT_LENGTH_SECONDS)
    return (epoch=epoch)
end

#@notice Calculate happiness
#@param token_id: Staked realm token id
#@return happiness: Happiness stat
@view
func calculate_happiness{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (happiness : felt):
    alloc_locals

    # FETCH VALUES
    let (culture) = calculate_culture(token_id)
    let (population) = calculate_population(token_id)
    let (food) = calculate_food(token_id)

    # GET HAPPINESS
    let (happiness) = Calculator.get_happiness(culture, population, food)

    return (happiness)
end

#@notice Calculate troop population
#@param token_id: Staked realm token id
#@return troop_population: Troop population
@view
func calculate_troop_population{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (troop_population : felt):
    alloc_locals

    # SUM TOTAL TROOP POPULATION
    # let (controller) = Module.get_controller_address()
    # let (combat_logic) = IModuleController.get_module_address(controller, ModuleIds.L06_Combat)
    # let (realm_combat_data : RealmCombatData) = IL06Combat.get_realm_combat_data(
    #     combat_logic, token_id
    # )

    # let (attacking_population) = COMBAT.get_troop_population(realm_combat_data.attacking_squad)
    # let (defending_population) = COMBAT.get_troop_population(realm_combat_data.defending_squad)

    return (0)
end

#@notice Calculate culture
#@param token_id: Staked realm token id
#@return culture: Culture stat
@view
func calculate_culture{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (culture : felt):
    # SUM TOTAL CULTURE
    let (controller) = Module.get_controller_address()
    let (buildings_logic_address) = IModuleController.get_module_address(
        contract_address=controller, module_id=ModuleIds.L03Buildings
    )
    let (current_buildings : RealmBuildings) = IL03Buildings.get_buildings_unpacked(
        buildings_logic_address, token_id
    )

    let CastleCulture = BuildingCultureEffect.Castle * current_buildings.castle
    let FairgroundsCulture = BuildingCultureEffect.Fairgrounds * current_buildings.fairgrounds
    let RoyalReserveCulture = BuildingCultureEffect.RoyalReserve * current_buildings.royal_reserve
    let GrandMarketCulture = BuildingCultureEffect.GrandMarket * current_buildings.grand_market
    let GuildCulture = BuildingCultureEffect.Guild * current_buildings.guild
    let OfficerAcademyCulture = BuildingCultureEffect.OfficerAcademy * current_buildings.officer_academy
    let GranaryCulture = BuildingCultureEffect.Granary * current_buildings.granary
    let HousingCulture = BuildingCultureEffect.Housing * current_buildings.housing
    let AmphitheaterCulture = BuildingCultureEffect.Amphitheater * current_buildings.amphitheater
    let ArcherTowerCulture = BuildingCultureEffect.ArcherTower * current_buildings.archer_tower
    let SchoolCulture = BuildingCultureEffect.School * current_buildings.school
    let MageTowerCulture = BuildingCultureEffect.MageTower * current_buildings.mage_tower
    let TradeOfficeCulture = BuildingCultureEffect.TradeOffice * current_buildings.trade_office
    let ArchitectCulture = BuildingCultureEffect.Architect * current_buildings.architect
    let ParadeGroundsCulture = BuildingCultureEffect.ParadeGrounds * current_buildings.parade_grounds
    let BarracksCulture = BuildingCultureEffect.Barracks * current_buildings.barracks
    let DockCulture = BuildingCultureEffect.Dock * current_buildings.dock
    let FishmongerCulture = BuildingCultureEffect.Fishmonger * current_buildings.fishmonger
    let FarmsCulture = BuildingCultureEffect.Farms * current_buildings.farms
    let HamletCulture = BuildingCultureEffect.Hamlet * current_buildings.hamlet

    let culture = 10 + CastleCulture + FairgroundsCulture + RoyalReserveCulture + GrandMarketCulture + GuildCulture + OfficerAcademyCulture + GranaryCulture + HousingCulture + AmphitheaterCulture + ArcherTowerCulture + SchoolCulture + MageTowerCulture + TradeOfficeCulture + ArchitectCulture + ParadeGroundsCulture + BarracksCulture + DockCulture + FishmongerCulture + FarmsCulture + HamletCulture

    return (culture)
end

#@notice Calculate population
#@param token_id: Staked realm token id
#@return population: Population stat
@view
func calculate_population{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (population : felt):
    alloc_locals

    # SUM TOTAL POPULATION
    let (controller) = Module.get_controller_address()
    let (buildings_logic_address) = IModuleController.get_module_address(
        contract_address=controller, module_id=ModuleIds.L03Buildings
    )
    let (current_buildings : RealmBuildings) = IL03Buildings.get_buildings_unpacked(
        buildings_logic_address, token_id
    )

    let CastlePop = BuildingPopulationEffect.Castle * current_buildings.castle
    let FairgroundsPop = BuildingPopulationEffect.Fairgrounds * current_buildings.fairgrounds
    let RoyalReservePop = BuildingPopulationEffect.RoyalReserve * current_buildings.royal_reserve
    let GrandMarketPop = BuildingPopulationEffect.GrandMarket * current_buildings.grand_market
    let GuildPop = BuildingPopulationEffect.Guild * current_buildings.guild
    let OfficerAcademyPop = BuildingPopulationEffect.OfficerAcademy * current_buildings.officer_academy
    let GranaryPop = BuildingPopulationEffect.Granary * current_buildings.granary
    let HousingPop = BuildingPopulationEffect.Housing * current_buildings.housing
    let AmphitheaterPop = BuildingPopulationEffect.Amphitheater * current_buildings.amphitheater
    let ArcherTowerPop = BuildingPopulationEffect.ArcherTower * current_buildings.archer_tower
    let SchoolPop = BuildingPopulationEffect.School * current_buildings.school
    let MageTowerPop = BuildingPopulationEffect.MageTower * current_buildings.mage_tower
    let TradeOfficePop = BuildingPopulationEffect.TradeOffice * current_buildings.trade_office
    let ArchitectPop = BuildingPopulationEffect.Architect * current_buildings.architect
    let ParadeGroundsPop = BuildingPopulationEffect.ParadeGrounds * current_buildings.parade_grounds
    let BarracksPop = BuildingPopulationEffect.Barracks * current_buildings.barracks
    let DockPop = BuildingPopulationEffect.Dock * current_buildings.dock
    let FishmongerPop = BuildingPopulationEffect.Fishmonger * current_buildings.fishmonger
    let FarmsPop = BuildingPopulationEffect.Farms * current_buildings.farms
    let HamletPop = BuildingPopulationEffect.Hamlet * current_buildings.hamlet

    let population = 100 + CastlePop + FairgroundsPop + RoyalReservePop + GrandMarketPop + GuildPop + OfficerAcademyPop + GranaryPop + HousingPop + AmphitheaterPop + ArcherTowerPop + SchoolPop + MageTowerPop + TradeOfficePop + ArchitectPop + ParadeGroundsPop + BarracksPop + DockPop + FishmongerPop + FarmsPop + HamletPop

    # TROOP POPULATION
    let (troop_population) = calculate_troop_population(token_id)

    return (population - troop_population)
end

#@notice Calculate food
#@param token_id: Staked realm token id
#@return food: Food stat
@view
func calculate_food{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (food : felt):
    alloc_locals

    # CALCULATE FOOD
    let (controller) = Module.get_controller_address()
    let (buildings_logic_address) = IModuleController.get_module_address(
        contract_address=controller, module_id=ModuleIds.L03Buildings
    )
    let (current_buildings : RealmBuildings) = IL03Buildings.get_buildings_unpacked(
        buildings_logic_address, token_id
    )

    let CastleFood = BuildingFoodEffect.Castle * current_buildings.castle
    let FairgroundsFood = BuildingFoodEffect.Fairgrounds * current_buildings.fairgrounds
    let RoyalReserveFood = BuildingFoodEffect.RoyalReserve * current_buildings.royal_reserve
    let GrandMarketFood = BuildingFoodEffect.GrandMarket * current_buildings.grand_market
    let GuildFood = BuildingFoodEffect.Guild * current_buildings.guild
    let OfficerAcademyFood = BuildingFoodEffect.OfficerAcademy * current_buildings.officer_academy
    let GranaryFood = BuildingFoodEffect.Granary * current_buildings.granary
    let HousingFood = BuildingFoodEffect.Housing * current_buildings.housing
    let AmphitheaterFood = BuildingFoodEffect.Amphitheater * current_buildings.amphitheater
    let ArcherTowerFood = BuildingFoodEffect.ArcherTower * current_buildings.archer_tower
    let SchoolFood = BuildingFoodEffect.School * current_buildings.school
    let MageTowerFood = BuildingFoodEffect.MageTower * current_buildings.mage_tower
    let TradeOfficeFood = BuildingFoodEffect.TradeOffice * current_buildings.trade_office
    let ArchitectFood = BuildingFoodEffect.Architect * current_buildings.architect
    let ParadeGroundsFood = BuildingFoodEffect.ParadeGrounds * current_buildings.parade_grounds
    let BarracksFood = BuildingFoodEffect.Barracks * current_buildings.barracks
    let DockFood = BuildingFoodEffect.Dock * current_buildings.dock
    let FishmongerFood = BuildingFoodEffect.Fishmonger * current_buildings.fishmonger
    let FarmsFood = BuildingFoodEffect.Farms * current_buildings.farms
    let HamletFood = BuildingFoodEffect.Hamlet * current_buildings.hamlet

    let food = 10 + CastleFood + FairgroundsFood + RoyalReserveFood + GrandMarketFood + GuildFood + OfficerAcademyFood + GranaryFood + HousingFood + AmphitheaterFood + ArcherTowerFood + SchoolFood + MageTowerFood + TradeOfficeFood + ArchitectFood + ParadeGroundsFood + BarracksFood + DockFood + FishmongerFood + FarmsFood + HamletFood

    let (troop_population) = calculate_troop_population(token_id)

    return (food - troop_population)
end

#@notice Calculate tribute
#@return tribute: Tributee
# TODO: Make LORDS decrease over time...
@view
func calculate_tribute{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    tribute : felt
):
    # TOD0: Decreasing supply curve of Lords
    # calculate number of buildings realm has

    return (tribute=BASE_LORDS_PER_DAY)
end

#@notice Calculate wonder tax
#@return tax_percentage: Wonder tax percentage
@view
func calculate_wonder_tax{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    tax_percentage : felt
):
    alloc_locals

    # CALCULATE WONDER TAX
    let (controller) = Module.get_controller_address()
    let (settle_state_address) = IModuleController.get_module_address(
        controller, ModuleIds.L01Settling
    )

    let (realms_settled) = IL01Settling.get_total_realms_settled(settle_state_address)

    let (less_than_tenth_settled) = is_nn_le(realms_settled, 1600)

    if less_than_tenth_settled == 1:
        return (tax_percentage=25)
    else:
        # TODO:
        # hardcode a max %
        # use basis points
        let (tax, _) = unsigned_div_rem(8000 * 5, realms_settled)
        return (tax_percentage=tax)
    end
end
