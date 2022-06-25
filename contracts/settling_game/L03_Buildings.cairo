# -----------------------------------
# ____MODULE_L03___BUILDING_LOGIC
#   Manages all buildings in game. Responsible for construction of buildings.
#
# MIT License
# -----------------------------------

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from openzeppelin.upgrades.library import (
    Proxy_initializer,
    Proxy_only_admin,
    Proxy_set_implementation,
)

from contracts.settling_game.utils.general import unpack_data, transform_costs_to_token_ids_values
from contracts.settling_game.utils.game_structs import (
    RealmData,
    RealmBuildings,
    Cost,
)
from contracts.settling_game.utils.constants import (
    SHIFT_6_1,
    SHIFT_6_2,
    SHIFT_6_3,
    SHIFT_6_4,
    SHIFT_6_5,
    SHIFT_6_6,
    SHIFT_6_7,
    SHIFT_6_8,
    SHIFT_6_9,
    SHIFT_6_10,
    SHIFT_6_11,
    SHIFT_6_12,
    SHIFT_6_13,
    SHIFT_6_14,
    SHIFT_6_15,
    SHIFT_6_16,
    SHIFT_6_17,
    SHIFT_6_18,
    SHIFT_6_19,
    SHIFT_6_20,
    ExternalContractIds,
    ModuleIds,
    RealmBuildingIds,
)
from contracts.settling_game.interfaces.IERC1155 import IERC1155
from contracts.settling_game.interfaces.IRealmsERC721 import IRealmsERC721
from contracts.settling_game.interfaces.IStakedRealmsERC721 import IStakedRealmsERC721
from contracts.settling_game.interfaces.IModules import IModuleController
from contracts.settling_game.library.library_module import Module

# -----------------------------------
# EVENTS
# -----------------------------------

@event
func BuildingBuilt(token_id : Uint256, building_id : felt):
end

# -----------------------------------
# STORAGE
# -----------------------------------

@storage_var
func realm_buildings(token_id : Uint256) -> (buildings : felt):
end

@storage_var
func building_cost(building_id : felt) -> (cost : Cost):
end

@storage_var
func building_lords_cost(building_id : felt) -> (lords : Uint256):
end

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
# EXTERNAL
# -----------------------------------

#@notice Build building on a realm
#@param token_id: Staked realm token id
#@param building_id: Building id
#@return success: Returns 1 when successfull
@external
func build{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token_id : Uint256, building_id : felt) -> (success : felt):
    alloc_locals

    let (caller) = get_caller_address()
    let (controller) = Module.get_controller_address()

    # AUTH
    Module.erc721_owner_check(token_id, ExternalContractIds.StakedRealms)

    # EXTERNAL ADDRESSES
    let (realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Realms
    )
    let (lords_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Lords
    )
    let (treasury_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Treasury
    )
    let (resource_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Resources
    )

    # REALMS DATA
    let (realms_data : RealmData) = IRealmsERC721.fetch_realm_data(
        contract_address=realms_address, token_id=token_id
    )

    # BUILD
    build_buildings(token_id, building_id)

    # GET BUILDING COSTS
    let (building_cost : Cost, lords : Uint256) = get_building_cost(building_id)

    let (costs : Cost*) = alloc()
    assert [costs] = building_cost
    let (token_ids : Uint256*) = alloc()
    let (token_values : Uint256*) = alloc()
    let (token_len : felt) = transform_costs_to_token_ids_values(1, costs, token_ids, token_values)

    # BURN RESOURCES
    IERC1155.burnBatch(resource_address, caller, token_len, token_ids, token_len, token_values)

    # TRANSFER LORDS
    # IERC20.transfer(lords_address, treasury_address, lords)

    # EMIT
    BuildingBuilt.emit(token_id, building_id)

    return (TRUE)
end

# -----------------------------------
# INTERNAL
# -----------------------------------

#@notice Build buildings
#@param token_id: Staked realm token id
#@param building_id: Building id
func build_buildings{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token_id : Uint256, building_id : felt):
    alloc_locals

    let (controller) = Module.get_controller_address()

    # REALMS ADDRESS
    let (realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Realms
    )

    # REALMS DATA
    let (realms_data : RealmData) = IRealmsERC721.fetch_realm_data(
        contract_address=realms_address, token_id=token_id
    )

    # GET CURRENT BUILDINGS
    let (current_buildings : RealmBuildings) = get_buildings_unpacked(token_id)

    let (buildings : felt*) = alloc()

    if building_id == RealmBuildingIds.Fairgrounds:
        # CHECK SPACE
        if current_buildings.fairgrounds == realms_data.regions:
            assert_not_zero(0)
        end
        local id_1 = (current_buildings.fairgrounds + 1) * SHIFT_6_1
        buildings[0] = id_1
    else:
        buildings[0] = current_buildings.fairgrounds * SHIFT_6_1
    end

    if building_id == RealmBuildingIds.RoyalReserve:
        if current_buildings.royal_reserve == realms_data.regions:
            assert_not_zero(0)
        end
        local id_2 = (current_buildings.royal_reserve + 1) * SHIFT_6_2
        buildings[1] = id_2
    else:
        local id_2 = current_buildings.royal_reserve * SHIFT_6_2
        buildings[1] = id_2
    end

    if building_id == RealmBuildingIds.GrandMarket:
        if current_buildings.grand_market == realms_data.regions:
            assert_not_zero(0)
        end
        local id_3 = (current_buildings.grand_market + 1) * SHIFT_6_3
        buildings[2] = id_3
    else:
        local id_3 = current_buildings.grand_market * SHIFT_6_3
        buildings[2] = id_3
    end

    if building_id == RealmBuildingIds.Castle:
        if current_buildings.castle == realms_data.regions:
            assert_not_zero(0)
        end
        local id_4 = (current_buildings.castle + 1) * SHIFT_6_4
        buildings[3] = id_4
    else:
        local id_4 = current_buildings.castle * SHIFT_6_4
        buildings[3] = id_4
    end

    if building_id == RealmBuildingIds.Guild:
        if current_buildings.guild == realms_data.regions:
            assert_not_zero(0)
        end
        local id_5 = (current_buildings.guild + 1) * SHIFT_6_5
        buildings[4] = id_5
    else:
        local id_5 = current_buildings.guild * SHIFT_6_5
        buildings[4] = id_5
    end

    if building_id == RealmBuildingIds.OfficerAcademy:
        if current_buildings.officer_academy == realms_data.regions:
            assert_not_zero(0)
        end
        local id_6 = (current_buildings.officer_academy + 1) * SHIFT_6_6
        buildings[5] = id_6
    else:
        local id_6 = current_buildings.officer_academy * SHIFT_6_6
        buildings[5] = id_6
    end

    if building_id == RealmBuildingIds.Granary:
        if current_buildings.granary == realms_data.cities:
            assert_not_zero(0)
        end
        local id_7 = (current_buildings.granary + 1) * SHIFT_6_7
        buildings[6] = id_7
    else:
        local id_7 = current_buildings.granary * SHIFT_6_7
        buildings[6] = id_7
    end

    if building_id == RealmBuildingIds.Housing:
        if current_buildings.housing == realms_data.cities:
            assert_not_zero(0)
        end
        local id_8 = (current_buildings.housing + 1) * SHIFT_6_8
        buildings[7] = id_8
    else:
        local id_8 = current_buildings.housing * SHIFT_6_8
        buildings[7] = id_8
    end

    if building_id == RealmBuildingIds.Amphitheater:
        if current_buildings.amphitheater == realms_data.cities:
            assert_not_zero(0)
        end
        local id_9 = (current_buildings.amphitheater + 1) * SHIFT_6_9
        buildings[8] = id_9
    else:
        local id_9 = current_buildings.amphitheater * SHIFT_6_9
        buildings[8] = id_9
    end

    if building_id == RealmBuildingIds.ArcherTower:
        if current_buildings.archer_tower == realms_data.cities:
            assert_not_zero(0)
        end
        local id_10 = (current_buildings.archer_tower + 1) * SHIFT_6_10
        buildings[9] = id_10
    else:
        local id_10 = current_buildings.archer_tower * SHIFT_6_10
        buildings[9] = id_10
    end

    if building_id == RealmBuildingIds.School:
        if current_buildings.school == realms_data.cities:
            assert_not_zero(0)
        end
        local id_11 = (current_buildings.school + 1) * SHIFT_6_11
        buildings[10] = id_11
    else:
        local id_11 = current_buildings.school * SHIFT_6_11
        buildings[10] = id_11
    end

    if building_id == RealmBuildingIds.MageTower:
        if current_buildings.mage_tower == realms_data.cities:
            assert_not_zero(0)
        end
        local id_12 = (current_buildings.mage_tower + 1) * SHIFT_6_12
        buildings[11] = id_12
    else:
        local id_12 = current_buildings.mage_tower * SHIFT_6_12
        buildings[11] = id_12
    end

    if building_id == RealmBuildingIds.TradeOffice:
        if current_buildings.trade_office == realms_data.cities:
            assert_not_zero(0)
        end
        local id_13 = (current_buildings.trade_office + 1) * SHIFT_6_13
        buildings[12] = id_13
    else:
        local id_13 = current_buildings.trade_office * SHIFT_6_13
        buildings[12] = id_13
    end

    if building_id == RealmBuildingIds.Architect:
        if current_buildings.architect == realms_data.cities:
            assert_not_zero(0)
        end
        local id_14 = (current_buildings.architect + 1) * SHIFT_6_14
        buildings[13] = id_14
    else:
        local id_14 = current_buildings.architect * SHIFT_6_14
        buildings[13] = id_14
    end

    if building_id == RealmBuildingIds.ParadeGrounds:
        if current_buildings.parade_grounds == realms_data.cities:
            assert_not_zero(0)
        end
        local id_15 = (current_buildings.parade_grounds + 1) * SHIFT_6_15
        buildings[14] = id_15
    else:
        local id_15 = current_buildings.parade_grounds * SHIFT_6_15
        buildings[14] = id_15
    end

    if building_id == RealmBuildingIds.Barracks:
        if current_buildings.barracks == realms_data.cities:
            assert_not_zero(0)
        end
        local id_16 = (current_buildings.barracks + 1) * SHIFT_6_16
        buildings[15] = id_16
    else:
        local id_16 = current_buildings.barracks * SHIFT_6_16
        buildings[15] = id_16
    end

    if building_id == RealmBuildingIds.Dock:
        if current_buildings.dock == realms_data.harbours:
            assert_not_zero(0)
        end
        local id_17 = (current_buildings.dock + 1) * SHIFT_6_17
        buildings[16] = id_17
    else:
        local id_17 = current_buildings.dock * SHIFT_6_17
        buildings[16] = id_17
    end

    if building_id == RealmBuildingIds.Fishmonger:
        if current_buildings.fishmonger == realms_data.harbours:
            assert_not_zero(0)
        end
        local id_18 = (current_buildings.fishmonger + 1) * SHIFT_6_18
        buildings[17] = id_18
    else:
        local id_18 = current_buildings.fishmonger * SHIFT_6_18
        buildings[17] = id_18
    end

    if building_id == RealmBuildingIds.Farms:
        if current_buildings.farms == realms_data.rivers:
            assert_not_zero(0)
        end
        local id_19 = (current_buildings.farms + 1) * SHIFT_6_19
        buildings[18] = id_19
    else:
        local id_19 = current_buildings.farms * SHIFT_6_19
        buildings[18] = id_19
    end

    if building_id == RealmBuildingIds.Hamlet:
        if current_buildings.hamlet == realms_data.rivers:
            assert_not_zero(0)
        end
        local id_20 = (current_buildings.hamlet + 1) * SHIFT_6_20
        buildings[19] = id_20
    else:
        local id_20 = current_buildings.hamlet * SHIFT_6_20
        buildings[19] = id_20
    end

    tempvar value = buildings[19] + buildings[18] + buildings[17] + buildings[16] + buildings[15] + buildings[14] + buildings[13] + buildings[12] + buildings[11] + buildings[10] + buildings[9] + buildings[8] + buildings[7] + buildings[6] + buildings[5] + buildings[4] + buildings[3] + buildings[2] + buildings[1] + buildings[0]

    realm_buildings.write(token_id, value)
    return ()
end

# -----------------------------------
# GETTERS
# -----------------------------------

#@notice Get the unpacked struct
#@param token_id: Staked realm token id
#@return realm_buildings: Realm buildings
@view
func get_buildings_unpacked{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token_id : Uint256) -> (realm_buildings : RealmBuildings):
    alloc_locals

    let (data) = get_realm_buildings(token_id)

    let (fairgrounds) = unpack_data(data, 0, 63)
    let (royal_reserve) = unpack_data(data, 6, 63)
    let (grand_market) = unpack_data(data, 12, 63)
    let (castle) = unpack_data(data, 18, 63)
    let (guild) = unpack_data(data, 24, 63)
    let (officer_academy) = unpack_data(data, 30, 63)
    let (granary) = unpack_data(data, 36, 63)
    let (housing) = unpack_data(data, 42, 63)
    let (amphitheater) = unpack_data(data, 48, 63)
    let (archer_tower) = unpack_data(data, 54, 63)
    let (school) = unpack_data(data, 60, 63)
    let (mage_tower) = unpack_data(data, 66, 63)
    let (trade_office) = unpack_data(data, 72, 63)
    let (architect) = unpack_data(data, 78, 63)
    let (parade_grounds) = unpack_data(data, 84, 63)
    let (barracks) = unpack_data(data, 90, 63)
    let (dock) = unpack_data(data, 96, 63)
    let (fishmonger) = unpack_data(data, 102, 63)
    let (farms) = unpack_data(data, 108, 63)
    let (hamlet) = unpack_data(data, 114, 63)

    return (
        realm_buildings=RealmBuildings(
        fairgrounds=fairgrounds,
        royal_reserve=royal_reserve,
        grand_market=grand_market,
        castle=castle,
        guild=guild,
        officer_academy=officer_academy,
        granary=granary,
        housing=housing,
        amphitheater=amphitheater,
        archer_tower=archer_tower,
        school=school,
        mage_tower=mage_tower,
        trade_office=trade_office,
        architect=architect,
        parade_grounds=parade_grounds,
        barracks=barracks,
        dock=dock,
        fishmonger=fishmonger,
        farms=farms,
        hamlet=hamlet
        ),
    )
end

#@notice Get encoded realm buildings
#@param token_id: Staked realm token id
#@return buildings: Encoded buildings felt
@view
func get_realm_buildings{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (buildings : felt):
    let (buildings) = realm_buildings.read(token_id)

    return (buildings)
end

#@notice Get building upgrade cost
#@param building_id: Building id
#@return cost: Resource costs
#@lords: Lords cost
@view
func get_building_cost{range_check_ptr, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*}(
    building_id : felt
) -> (cost : Cost, lords : Uint256):
    let (cost) = building_cost.read(building_id)
    let (lords) = building_lords_cost.read(building_id)
    return (cost, lords)
end

# -----------------------------------
# ADMIN
# -----------------------------------

#@notice Set building cost
#@param building_id: Building id
#@param cost: Cost of the building
#@param lords: Lord cost
@external
func set_building_cost{range_check_ptr, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*}(
    building_id : felt, cost : Cost, lords : Uint256
):
    # TODO: range checks on the cost struct
    Proxy_only_admin()
    building_cost.write(building_id, cost)
    building_lords_cost.write(building_id, lords)
    return ()
end
