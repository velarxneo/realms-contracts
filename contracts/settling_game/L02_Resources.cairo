# -----------------------------------
# ____Module.L02___RESOURCES_LOGIC
#   Logic to create and issue resources for a given Realm
#
# MIT License
# -----------------------------------

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem, assert_not_zero, assert_le, assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from openzeppelin.token.erc721.interfaces.IERC721 import IERC721
from openzeppelin.upgrades.library import (
    Proxy_initializer,
    Proxy_only_admin,
    Proxy_set_implementation,
)

from contracts.settling_game.utils.game_structs import (
    Cost,
    RealmData,
)
from contracts.settling_game.utils.general import transform_costs_to_token_ids_values
from contracts.settling_game.utils.constants import (
    TRUE,
    FALSE,
    VAULT_LENGTH,
    DAY,
    BASE_RESOURCES_PER_DAY,
    BASE_LORDS_PER_DAY,
    PILLAGE_AMOUNT,
    ModuleIds,
    ExternalContractIds,
)
from contracts.settling_game.library.library_module import Module
from contracts.settling_game.interfaces.IERC1155 import IERC1155
from contracts.settling_game.interfaces.IRealmsERC721 import IRealmsERC721
from contracts.settling_game.interfaces.IModules import (
    IModuleController,
    IL01Settling,
    IL04Calculator,
    IL05Wonders,
)

# -----------------------------------
# EVENTS
# -----------------------------------

@event
func ResourceUpgraded(token_id : Uint256, building_id : felt, level : felt):
end

# -----------------------------------
# STORAGE
# -----------------------------------

@storage_var
func resource_levels(token_id : Uint256, resource_id : felt) -> (level : felt):
end

@storage_var
func resource_upgrade_cost(resource_id : felt) -> (cost : Cost):
end

# -----------------------------------
# INITIALIZER & UPGRADE
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

#@notice Claim available resources
#@token_id: Staked realm token id
@external
func claim_resources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
):
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller_address()

    # CONTRACT ADDRESSES
    let (lords_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Lords
    )
    let (realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Realms
    )
    let (s_realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.StakedRealms
    )
    let (resources_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Resources
    )
    let (settling_logic_address) = IModuleController.get_module_address(
        controller, ModuleIds.L01Settling
    )
    let (calculator_address) = IModuleController.get_module_address(
        controller, ModuleIds.L04Calculator
    )
    let (treasury_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Treasury
    )
    let (wonders_logic_address) = IModuleController.get_module_address(
        controller, ModuleIds.L05Wonders
    )

    # FETCH OWNER
    let (owner) = IERC721.ownerOf(s_realms_address, token_id)

    # ALLOW RESOURCE LOGIC ADDRESS TO CLAIM, BUT STILL RESTRICT
    if caller != settling_logic_address:
        Module.erc721_owner_check(token_id, ExternalContractIds.StakedRealms)
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    let (local resource_ids : Uint256*) = alloc()

    # FETCH REALM DATA
    let (realms_data : RealmData) = IRealmsERC721.fetch_realm_data(realms_address, token_id)

    # CALC DAYS
    let (total_days, remainder) = days_accrued(token_id)

    # CALC VAULT DAYS
    let (total_vault_days, vault_remainder) = get_available_vault_days(token_id)

    # CHECK DAYS + VAULT > 1
    let days = total_days + total_vault_days

    with_attr error_message("L02Resources: Nothing Claimable."):
        assert_not_zero(days)
    end

    # SET VAULT TIME = REMAINDER - CURRENT_TIME
    IL01Settling.set_time_staked(settling_logic_address, token_id, remainder)
    IL01Settling.set_time_vault_staked(settling_logic_address, token_id, vault_remainder)

    # GET WONDER TAX
    let (wonder_tax) = IL04Calculator.calculate_wonder_tax(calculator_address)

    # SET MINT
    let treasury_mint_perc = wonder_tax
    with_attr error_message("L02Resources: resource id underflowed a felt."):
        # Make sure wonder_tax doesn't divide by zero
        assert_le(wonder_tax, 100)
        let user_resources_value_rel_perc = 100 - wonder_tax
    end

    # GET OUTPUT FOR EACH RESOURCE
    let (r_1_output, r_2_output, r_3_output, r_4_output, r_5_output, r_6_output,
        r_7_output) = get_all_resource_output(
        token_id,
        realms_data.resource_1,
        realms_data.resource_2,
        realms_data.resource_3,
        realms_data.resource_4,
        realms_data.resource_5,
        realms_data.resource_6,
        realms_data.resource_7,
    )

    # USER CLAIM
    let (r_1_user) = calculate_total_claimable(days, user_resources_value_rel_perc, r_1_output)
    let (r_2_user) = calculate_total_claimable(days, user_resources_value_rel_perc, r_2_output)
    let (r_3_user) = calculate_total_claimable(days, user_resources_value_rel_perc, r_3_output)
    let (r_4_user) = calculate_total_claimable(days, user_resources_value_rel_perc, r_4_output)
    let (r_5_user) = calculate_total_claimable(days, user_resources_value_rel_perc, r_5_output)
    let (r_6_user) = calculate_total_claimable(days, user_resources_value_rel_perc, r_6_output)
    let (r_7_user) = calculate_total_claimable(days, user_resources_value_rel_perc, r_7_output)

    # WONDER TAX
    let (r_1_wonder) = calculate_total_claimable(days, treasury_mint_perc, r_1_output)
    let (r_2_wonder) = calculate_total_claimable(days, treasury_mint_perc, r_2_output)
    let (r_3_wonder) = calculate_total_claimable(days, treasury_mint_perc, r_3_output)
    let (r_4_wonder) = calculate_total_claimable(days, treasury_mint_perc, r_4_output)
    let (r_5_wonder) = calculate_total_claimable(days, treasury_mint_perc, r_5_output)
    let (r_6_wonder) = calculate_total_claimable(days, treasury_mint_perc, r_6_output)
    let (r_7_wonder) = calculate_total_claimable(days, treasury_mint_perc, r_7_output)

    # ADD VALUES TO TEMP ARRAY FOR EACH AVAILABLE RESOURCE
    let (resource_len : felt, resource_ids : Uint256*) = get_resource_ids(token_id)

    let (resource_mint_len : felt, resource_mint : Uint256*) = get_mintable_resources(
        realms_data, r_1_user, r_2_user, r_3_user, r_4_user, r_5_user, r_6_user, r_7_user
    )

    let (resource_mint_len : felt, resource_wonder_mint : Uint256*) = get_mintable_resources(
        realms_data,
        r_1_wonder,
        r_2_wonder,
        r_3_wonder,
        r_4_wonder,
        r_5_wonder,
        r_6_wonder,
        r_7_wonder,
    )

    # LORDS MINT
    let (tribute) = IL04Calculator.calculate_tribute(calculator_address)

    let lords_bn = total_days * tribute * 10 ** 18

    with_attr error_message("L02Resources: lords value needs to be greater than 0"):
        assert_nn(lords_bn)
    end

    let lords_available = Uint256(lords_bn, 0)

    # FETCH OWNER
    let (owner) = IRealmsERC721.ownerOf(s_realms_address, token_id)

    # MINT LORDS
    IERC20.transferFrom(lords_address, treasury_address, owner, lords_available)

    # MINT USERS RESOURCES
    IERC1155.mintBatch(
        resources_address,
        owner,
        realms_data.resource_number,
        resource_ids,
        realms_data.resource_number,
        resource_mint,
    )

    # GET EPOCH
    let (current_epoch) = IL04Calculator.calculate_epoch(calculator_address)

    # SET WONDER TAX IN POOL
    IL05Wonders.batch_set_tax_pool(
        wonders_logic_address,
        current_epoch,
        realms_data.resource_number,
        resource_ids,
        realms_data.resource_number,
        resource_wonder_mint,
    )

    return ()
end

#@notice Pillage resources after a succesful raid
#@param token_id: Staked realm id
#@param claimer: Resource receiver address
@external
func pillage_resources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256, claimer : felt
):
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller_address()

    # ONLY COMBAT CAN CALL
    let (combat_address) = IModuleController.get_module_address(
        controller, ModuleIds.L06Combat
    )
    with_attr error_message("L02Resources: Only the combat module can call pillage_resources"):
        assert caller = combat_address
    end

    # EXTERNAL CONTRACTS
    let (realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Realms
    )
    let (s_realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.StakedRealms
    )
    let (resources_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Resources
    )
    let (settling_logic_address) = IModuleController.get_module_address(
        controller, ModuleIds.L01Settling
    )
    let (calculator_address) = IModuleController.get_module_address(
        controller, ModuleIds.L04Calculator
    )

    # FETCH REALM DATA
    let (realms_data : RealmData) = IRealmsERC721.fetch_realm_data(realms_address, token_id)

    # CALC PILLAGABLE DAYS
    let (total_pillagable_days, pillagable_remainder) = vault_days_accrued(token_id)

    # CHECK IS RAIDABLE
    with_attr error_message("L02Resources: Nothing to pillage!"):
        assert_not_zero(total_pillagable_days)
    end

    # SET VAULT TIME = REMAINDER - CURRENT_TIME
    IL01Settling.set_time_vault_staked(settling_logic_address, token_id, pillagable_remainder)

    # GET OUTPUT FOR EACH RESOURCE
    let (r_1_output, r_2_output, r_3_output, r_4_output, r_5_output, r_6_output,
        r_7_output) = get_all_resource_output(
        token_id,
        realms_data.resource_1,
        realms_data.resource_2,
        realms_data.resource_3,
        realms_data.resource_4,
        realms_data.resource_5,
        realms_data.resource_6,
        realms_data.resource_7,
    )

    # GET CLAIMABLE
    let (r_1_user) = calculate_total_claimable(total_pillagable_days, PILLAGE_AMOUNT, r_1_output)
    let (r_2_user) = calculate_total_claimable(total_pillagable_days, PILLAGE_AMOUNT, r_2_output)
    let (r_3_user) = calculate_total_claimable(total_pillagable_days, PILLAGE_AMOUNT, r_3_output)
    let (r_4_user) = calculate_total_claimable(total_pillagable_days, PILLAGE_AMOUNT, r_4_output)
    let (r_5_user) = calculate_total_claimable(total_pillagable_days, PILLAGE_AMOUNT, r_5_output)
    let (r_6_user) = calculate_total_claimable(total_pillagable_days, PILLAGE_AMOUNT, r_6_output)
    let (r_7_user) = calculate_total_claimable(total_pillagable_days, PILLAGE_AMOUNT, r_7_output)

    # ADD VALUES TO TEMP ARRAY FOR EACH AVAILABLE RESOURCE
    let (resource_len : felt, resource_ids : Uint256*) = get_resource_ids(token_id)

    let (resource_mint_len : felt, resource_mint : Uint256*) = get_mintable_resources(
        realms_data, r_1_user, r_2_user, r_3_user, r_4_user, r_5_user, r_6_user, r_7_user
    )

    # MINT PILLAGED RESOURCES TO VICTOR
    IERC1155.mintBatch(
        resources_address,
        claimer,
        realms_data.resource_number,
        resource_ids,
        realms_data.resource_number,
        resource_mint,
    )

    return ()
end

#@notice Upgrade resource production
#@token_id: Staked realm token id
#@resource_id: Resource id of resource production to upgrade
@external
func upgrade_resource{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*, range_check_ptr
}(token_id : Uint256, resource_id : felt) -> ():
    alloc_locals

    let (can_claim) = check_if_claimable(token_id)

    if can_claim == TRUE:
        claim_resources(token_id)
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    let (caller) = get_caller_address()
    let (controller) = Module.get_controller_address()

    # CONTRACT ADDRESSES
    let (resource_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Resources
    )

    # AUTH
    Module.erc721_owner_check(token_id, ExternalContractIds.StakedRealms)

    # GET RESOURCE LEVEL
    let (level) = get_resource_level(token_id, resource_id)

    # GET UPGRADE VALUE
    let (upgrade_cost : Cost) = get_resource_upgrade_cost(resource_id)
    let (costs : Cost*) = alloc()
    assert [costs] = upgrade_cost
    let (token_ids : Uint256*) = alloc()
    let (token_values : Uint256*) = alloc()
    let (token_len : felt) = transform_costs_to_token_ids_values(1, costs, token_ids, token_values)

    # BURN RESOURCES
    IERC1155.burnBatch(resource_address, caller, token_len, token_ids, token_len, token_values)

    # INCREASE LEVEL
    set_resource_level(token_id, resource_id, level + 1)

    # EMIT
    ResourceUpgraded.emit(token_id, resource_id, level + 1)
    return ()
end

# -----------------------------------
# GETTERS
# -----------------------------------

#@notice Gets the number of accrued days
#@param token_id: Staked realm token id
#@return days_accrued: Number of days accrued
#@return remainder: Time remainder after division in seconds
@view
func days_accrued{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (days_accrued : felt, remainder : felt):
    let (controller) = Module.get_controller_address()
    let (block_timestamp) = get_block_timestamp()
    let (settling_logic_address) = IModuleController.get_module_address(
        controller, ModuleIds.L01Settling
    )

    # GET DAYS ACCRUED
    let (last_update) = IL01Settling.get_time_staked(settling_logic_address, token_id)
    let (days_accrued, seconds_left_over) = unsigned_div_rem(block_timestamp - last_update, DAY)

    return (days_accrued, seconds_left_over)
end

#@notice Gets the number of accrued days for the vault
#@param token_id: Staked realm token id
#@return days_accrued: Number of days accrued for the vault
#@return remainder: Time remainder after division in seconds
@view
func vault_days_accrued{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (days_accrued : felt, remainder : felt):
    alloc_locals
    let (controller) = Module.get_controller_address()
    let (block_timestamp) = get_block_timestamp()
    let (settling_logic_address) = IModuleController.get_module_address(
        controller, ModuleIds.L01Settling
    )

    # GET DAYS ACCRUED
    let (last_update) = IL01Settling.get_time_vault_staked(settling_logic_address, token_id)
    let (days_accrued, seconds_left_over) = unsigned_div_rem(block_timestamp - last_update, DAY)

    return (days_accrued, seconds_left_over)
end

#@notice Fetches vault days available for realm owner only
#@dev Only returns value if days are over epoch length - set to 7 day cycles
#@param token_id: Staked realm token id
#@return days_accrued: Number of days accrued
#@return remainder: Remaining seconds
@view
func get_available_vault_days{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (days_accrued : felt, remainder : felt):
    alloc_locals

    # CALC REMAINING DAYS
    let (days_accrued, seconds_left_over) = vault_days_accrued(token_id)

    # returns true if days <= vault_length -1 (we minus 1 so the user can claim when they have 7 days)
    let (less_than) = is_le(days_accrued, VAULT_LENGTH - 1)

    # return no days and no remainder
    if less_than == TRUE:
        return (0, 0)
    end

    # else return days and remainder
    return (days_accrued, seconds_left_over)
end

#@notice check if resources are claimable
#@param token_id: Staked realm token id
#@return can_claim: Return if resources can be claimed
@view
func check_if_claimable{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (can_claim : felt):
    alloc_locals

    # FETCH AVAILABLE
    let (days, _) = days_accrued(token_id)
    let (epochs, _) = get_available_vault_days(token_id)

    # ADD 1 TO ALLOW USERS TO CLAIM FULL EPOCH
    let (less_than) = is_le(days + epochs + 1, 1)

    if less_than == TRUE:
        return (FALSE)
    end

    return (TRUE)
end

#@notice Calculate resource outputs for all resources in a realm
#@param token_id: Staked realm token id
#@params resource_: Resource ids
#@return resource_: Resource outputs
@view
func get_all_resource_output{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256,
    resource_1 : felt,
    resource_2 : felt,
    resource_3 : felt,
    resource_4 : felt,
    resource_5 : felt,
    resource_6 : felt,
    resource_7 : felt,
) -> (
    resource_1 : felt,
    resource_2 : felt,
    resource_3 : felt,
    resource_4 : felt,
    resource_5 : felt,
    resource_6 : felt,
    resource_7 : felt,
):
    alloc_locals

    # GET HAPPINESS
    let (controller) = Module.get_controller_address()
    let (calculator_address) = IModuleController.get_module_address(
        controller, ModuleIds.L04Calculator
    )
    let (happiness) = IL04Calculator.calculate_happiness(calculator_address, token_id)

    let (r_1_output) = calculate_resource_output(token_id, resource_1, happiness)
    let (r_2_output) = calculate_resource_output(token_id, resource_2, happiness)
    let (r_3_output) = calculate_resource_output(token_id, resource_3, happiness)
    let (r_4_output) = calculate_resource_output(token_id, resource_4, happiness)
    let (r_5_output) = calculate_resource_output(token_id, resource_5, happiness)
    let (r_6_output) = calculate_resource_output(token_id, resource_6, happiness)
    let (r_7_output) = calculate_resource_output(token_id, resource_7, happiness)

    return (r_1_output, r_2_output, r_3_output, r_4_output, r_5_output, r_6_output, r_7_output)
end

#@notice Calculate all claimable resources
#@param token_id: Staked realms token id
#@return user_mint_len: Lenght of user_mint 
#@return user_mint: List of users to mint to
#@return lords_available: Available lord tokens
@view
func get_all_resource_claimable{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (user_mint_len : felt, user_mint : Uint256*, lords_available : Uint256):
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller_address()

    # CONTRACT ADDRESSES
    let (realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Realms
    )
    let (calculator_address) = IModuleController.get_module_address(
        controller, ModuleIds.L04Calculator
    )
    let (wonders_logic_address) = IModuleController.get_module_address(
        controller, ModuleIds.L05Wonders
    )

    # FETCH REALM DATA
    let (realms_data : RealmData) = IRealmsERC721.fetch_realm_data(realms_address, token_id)

    # CALC DAYS
    let (total_days, remainder) = days_accrued(token_id)

    # CALC VAULT DAYS
    let (total_vault_days, vault_remainder) = get_available_vault_days(token_id)

    # CHECK DAYS + VAULT > 1
    let days = total_days + total_vault_days

    # GET WONDER TAX
    let (wonder_tax) = IL04Calculator.calculate_wonder_tax(calculator_address)

    # SET MINT
    let user_mint_rel_perc = 100 - wonder_tax

    # GET OUTPUT FOR EACH RESOURCE
    let (r_1_output, r_2_output, r_3_output, r_4_output, r_5_output, r_6_output,
        r_7_output) = get_all_resource_output(
        token_id,
        realms_data.resource_1,
        realms_data.resource_2,
        realms_data.resource_3,
        realms_data.resource_4,
        realms_data.resource_5,
        realms_data.resource_6,
        realms_data.resource_7,
    )

    # USER CLAIM
    let (r_1_user) = calculate_total_claimable(days, user_mint_rel_perc, r_1_output)
    let (r_2_user) = calculate_total_claimable(days, user_mint_rel_perc, r_2_output)
    let (r_3_user) = calculate_total_claimable(days, user_mint_rel_perc, r_3_output)
    let (r_4_user) = calculate_total_claimable(days, user_mint_rel_perc, r_4_output)
    let (r_5_user) = calculate_total_claimable(days, user_mint_rel_perc, r_5_output)
    let (r_6_user) = calculate_total_claimable(days, user_mint_rel_perc, r_6_output)
    let (r_7_user) = calculate_total_claimable(days, user_mint_rel_perc, r_7_output)

    let (_, resource_mint : Uint256*) = get_mintable_resources(
        realms_data, r_1_user, r_2_user, r_3_user, r_4_user, r_5_user, r_6_user, r_7_user
    )

    # LORDS MINT
    let (tribute) = IL04Calculator.calculate_tribute(calculator_address)

    let lords_bn = total_days * tribute * 10 ** 18

    with_attr error_message("L2Resources: lords value greater than 0"):
        assert_nn(lords_bn)
    end

    let lords_available = Uint256(lords_bn, 0)

    return (realms_data.resource_number, resource_mint, lords_available)
end

#@notice Get resource level
#@param token_id: Staked realm token id
#@param resource_id: Resource id
#@return level: Resource level
@view
func get_resource_level{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256, resource_id : felt
) -> (level : felt):
    let (level) = resource_levels.read(token_id, resource_id)
    return (level=level)
end

#@notice Get resource upgrade cost
#@param resource_id: Resource id
#@return cost: Upgrade cost
@view
func get_resource_upgrade_cost{range_check_ptr, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*}(
    resource_id : felt
) -> (cost : Cost):
    let (cost) = resource_upgrade_cost.read(resource_id)
    return (cost)
end

#@notice Calculate all raidable resources from the vault
#@param token_id: Staked realm token id
#@return user_mint_len: Length of user_mint
#@return user_mint: List of users to mint to
@view
func get_all_vault_raidable{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (user_mint_len : felt, user_mint : Uint256*):
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller_address()

    # CONTRACT ADDRESSES
    let (realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Realms
    )

    # FETCH REALM DATA
    let (realms_data : RealmData) = IRealmsERC721.fetch_realm_data(realms_address, token_id)

    # CALC VAULT DAYS
    let (total_vault_days, vault_remainder) = vault_days_accrued(token_id)

    # GET OUTPUT FOR EACH RESOURCE
    let (r_1_output, r_2_output, r_3_output, r_4_output, r_5_output, r_6_output,
        r_7_output) = get_all_resource_output(
        token_id,
        realms_data.resource_1,
        realms_data.resource_2,
        realms_data.resource_3,
        realms_data.resource_4,
        realms_data.resource_5,
        realms_data.resource_6,
        realms_data.resource_7,
    )

    # USER CLAIM
    let (r_1_user) = calculate_total_claimable(total_vault_days, PILLAGE_AMOUNT, r_1_output)
    let (r_2_user) = calculate_total_claimable(total_vault_days, PILLAGE_AMOUNT, r_2_output)
    let (r_3_user) = calculate_total_claimable(total_vault_days, PILLAGE_AMOUNT, r_3_output)
    let (r_4_user) = calculate_total_claimable(total_vault_days, PILLAGE_AMOUNT, r_4_output)
    let (r_5_user) = calculate_total_claimable(total_vault_days, PILLAGE_AMOUNT, r_5_output)
    let (r_6_user) = calculate_total_claimable(total_vault_days, PILLAGE_AMOUNT, r_6_output)
    let (r_7_user) = calculate_total_claimable(total_vault_days, PILLAGE_AMOUNT, r_7_output)

    let (_, resource_mint : Uint256*) = get_mintable_resources(
        realms_data, r_1_user, r_2_user, r_3_user, r_4_user, r_5_user, r_6_user, r_7_user
    )

    return (realms_data.resource_number, resource_mint)
end

# -----------------------------------
# INTERNAL
# -----------------------------------

#@notice Calculate resource output
#@param token_id: Staked realm token id
#@param resource_id: Resource id
#@param happiness: Realm happiness stat
#@return value: Resource output
func calculate_resource_output{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256, resource_id : felt, happiness : felt
) -> (value : felt):
    alloc_locals

    # GET RESOURCE LEVEL
    let (level) = get_resource_level(token_id, resource_id)

    # HAPPINESS CHECK
    let (production_output, _) = unsigned_div_rem(BASE_RESOURCES_PER_DAY * happiness, 100)

    # IF LEVEL 0 RETURN NO INCREASE
    if level == 0:
        return (production_output)
    end
    return ((level + 1) * production_output)
end

#@notice Calculate total claimable
#@param days: Number of days
#@param tax: Tax rate
#@param output: Output of a resource
#@return value: Total claimable
func calculate_total_claimable{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    days : felt, tax : felt, output : felt
) -> (value : Uint256):
    alloc_locals
    # days * current tax * output
    # we multiply by tax before dividing by 100

    let (total_work_generated, _) = unsigned_div_rem(days * tax * output, 100)

    let work_bn = total_work_generated * 10 ** 18

    with_attr error_message("L2Resources: work bn greater than"):
        assert_nn(work_bn)
    end

    return (Uint256(work_bn, 0))
end

# -----------------------------------
# SETTERS
# -----------------------------------

#@notice Set resource level
#@param token_id: Staked realm token id
#@param resource_id: Resource id
#@param level: New level value
func set_resource_level{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token_id : Uint256, resource_id : felt, level : felt) -> ():
    resource_levels.write(token_id, resource_id, level)
    return ()
end

# -----------------------------------
# ADMIN
# -----------------------------------

#@notice Set resource upgrade cost
#@param resource_id: Resource id
#@param cost: New cost value
@external
func set_resource_upgrade_cost{range_check_ptr, syscall_ptr : felt*, pedersen_ptr : HashBuiltin*}(
    resource_id : felt, cost : Cost
):
    Proxy_only_admin()
    resource_upgrade_cost.write(resource_id, cost)
    return ()
end

#@notice Get the different resources of a realm
#@param token_id: Staked realm token id
#@return resource_ids_len: Length of resource_ids
#@return resource_ids: List of resource ids
@view
func get_resource_ids{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_id : Uint256
) -> (resource_ids_len : felt, resource_ids : Uint256*):
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller_address()

    # CONTRACT ADDRESSES

    let (realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Realms
    )

    let (local resource_ids : Uint256*) = alloc()

    # FETCH REALM DATA
    let (realms_data : RealmData) = IRealmsERC721.fetch_realm_data(realms_address, token_id)

    # ADD VALUES TO TEMP ARRAY FOR EACH AVAILABLE RESOURCE
    assert resource_ids[0] = Uint256(realms_data.resource_1, 0)

    if realms_data.resource_2 != 0:
        assert resource_ids[1] = Uint256(realms_data.resource_2, 0)
    end

    if realms_data.resource_3 != 0:
        assert resource_ids[2] = Uint256(realms_data.resource_3, 0)
    end

    if realms_data.resource_4 != 0:
        assert resource_ids[3] = Uint256(realms_data.resource_4, 0)
    end

    if realms_data.resource_5 != 0:
        assert resource_ids[4] = Uint256(realms_data.resource_5, 0)
    end

    if realms_data.resource_6 != 0:
        assert resource_ids[5] = Uint256(realms_data.resource_6, 0)
    end

    if realms_data.resource_7 != 0:
        assert resource_ids[6] = Uint256(realms_data.resource_7, 0)
    end

    return (realms_data.resource_number, resource_ids)
end

#@notice Put all mintable resources in a list
#@param realms_data: Realm metadata
#@params resource_mint_: Resources to mint
#@return resource_mint_len: Length of resource_mint
#@return resource_mint: List of resources to mint
@view
func get_mintable_resources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    realms_data : RealmData,
    resource_mint_1 : Uint256,
    resource_mint_2 : Uint256,
    resource_mint_3 : Uint256,
    resource_mint_4 : Uint256,
    resource_mint_5 : Uint256,
    resource_mint_6 : Uint256,
    resource_mint_7 : Uint256,
) -> (resource_mint_len : felt, resource_mint : Uint256*):
    alloc_locals

    let (local resource_mint : Uint256*) = alloc()

    # ADD VALUES TO TEMP ARRAY FOR EACH AVAILABLE RESOURCE
    assert resource_mint[0] = resource_mint_1

    if realms_data.resource_2 != 0:
        assert resource_mint[1] = resource_mint_2
    end

    if realms_data.resource_3 != 0:
        assert resource_mint[2] = resource_mint_3
    end

    if realms_data.resource_4 != 0:
        assert resource_mint[3] = resource_mint_4
    end

    if realms_data.resource_5 != 0:
        assert resource_mint[4] = resource_mint_5
    end

    if realms_data.resource_6 != 0:
        assert resource_mint[5] = resource_mint_6
    end

    if realms_data.resource_7 != 0:
        assert resource_mint[6] = resource_mint_7
    end

    return (realms_data.resource_number, resource_mint)
end
