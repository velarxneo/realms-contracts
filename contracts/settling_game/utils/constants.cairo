# -----------------------------------
# Constants utility contract
#   A set of constants that are used throughout the project
#   and/or not provided by cairo (e.g. TRUE / FALSE).
#
# MIT License
# -----------------------------------

%lang starknet

# BIT SHIFTS
const SHIFT_8_1 = 2 ** 0
const SHIFT_8_2 = 2 ** 8
const SHIFT_8_3 = 2 ** 16
const SHIFT_8_4 = 2 ** 24
const SHIFT_8_5 = 2 ** 32
const SHIFT_8_6 = 2 ** 40
const SHIFT_8_7 = 2 ** 48
const SHIFT_8_8 = 2 ** 56
const SHIFT_8_9 = 2 ** 64
const SHIFT_8_10 = 2 ** 72
const SHIFT_8_11 = 2 ** 80
const SHIFT_8_12 = 2 ** 88
const SHIFT_8_13 = 2 ** 96
const SHIFT_8_14 = 2 ** 104
const SHIFT_8_15 = 2 ** 112
const SHIFT_8_16 = 2 ** 120
const SHIFT_8_17 = 2 ** 128
const SHIFT_8_18 = 2 ** 136
const SHIFT_8_19 = 2 ** 144
const SHIFT_8_20 = 2 ** 152

const SHIFT_6_1 = 2 ** 0
const SHIFT_6_2 = 2 ** 6
const SHIFT_6_3 = 2 ** 12
const SHIFT_6_4 = 2 ** 18
const SHIFT_6_5 = 2 ** 24
const SHIFT_6_6 = 2 ** 30
const SHIFT_6_7 = 2 ** 36
const SHIFT_6_8 = 2 ** 42
const SHIFT_6_9 = 2 ** 48
const SHIFT_6_10 = 2 ** 54
const SHIFT_6_11 = 2 ** 60
const SHIFT_6_12 = 2 ** 66
const SHIFT_6_13 = 2 ** 72
const SHIFT_6_14 = 2 ** 78
const SHIFT_6_15 = 2 ** 84
const SHIFT_6_16 = 2 ** 90
const SHIFT_6_17 = 2 ** 96
const SHIFT_6_18 = 2 ** 102
const SHIFT_6_19 = 2 ** 108
const SHIFT_6_20 = 2 ** 114

const SHIFT_NFT_1 = 2 ** 0
const SHIFT_NFT_2 = 2 ** 7
const SHIFT_NFT_3 = 2 ** 27
const SHIFT_NFT_4 = 2 ** 52
const SHIFT_NFT_5 = 2 ** 54

const TRUE = 1
const FALSE = 0

# SETTLING
const VAULT_LENGTH = 7  # days
const DAY = 1800  # day cycle length
const VAULT_LENGTH_SECONDS = VAULT_LENGTH * DAY  # vault is always 7 * day cycle

# CRYPTS
const RESOURCES_PER_CRYPT = 1  # We only generate one resource per crypt (vs up to 7 per realm)
const LEGENDARY_MULTIPLIER = 10  # Legendary maps generate 10x resources as non-egendat

# PRODUCTION
const BASE_RESOURCES_PER_DAY = 100
const BASE_LORDS_PER_DAY = 25

# COMBAT
const GENESIS_TIMESTAMP = 1645743897

# COMBAT
const PILLAGE_AMOUNT = 25

#-----------------------------------
# Namespaces (alphabetical)
#-----------------------------------

namespace ArmyCap:
    const Fairgrounds = 0
    const RoyalReserve = 5
    const GrandMarket = 0
    const Castle = 5
    const Guild = 5
    const OfficerAcademy = 5
    const Granary = 0
    const Housing = 0
    const Amphitheater = 2
    const ArcherTower = 0
    const School = 3
    const MageTower = 0
    const TradeOffice = 0
    const Architect = 1
    const ParadeGrounds = 2
    const Barracks = 1
    const Dock = 0
    const Fishmonger = 0
    const Farms = 0
    const Hamlet = 0
end

namespace BuildingCultureEffect:
    const Fairgrounds = 5
    const RoyalReserve = 5
    const GrandMarket = 0
    const Castle = 5
    const Guild = 5
    const OfficerAcademy = 0
    const Granary = 0
    const Housing = 0
    const Amphitheater = 2
    const ArcherTower = 0
    const School = 3
    const MageTower = 0
    const TradeOffice = 1
    const Architect = 1
    const ParadeGrounds = 1
    const Barracks = 0
    const Dock = 0
    const Fishmonger = 0
    const Farms = 0
    const Hamlet = 0
end

namespace BuildingFoodEffect:
    const Fairgrounds = 5
    const RoyalReserve = 5
    const GrandMarket = 5
    const Castle = -1
    const Guild = -1
    const OfficerAcademy = -1
    const Granary = 3
    const Housing = -1
    const Amphitheater = -1
    const ArcherTower = -1
    const School = -1
    const MageTower = -1
    const TradeOffice = -1
    const Architect = -1
    const ParadeGrounds = -1
    const Barracks = -1
    const Dock = -1
    const Fishmonger = 2
    const Farms = 1
    const Hamlet = 1
end

namespace BuildingPopulationEffect:
    const Fairgrounds = -10
    const RoyalReserve = -10
    const GrandMarket = -10
    const Castle = -10
    const Guild = -10
    const OfficerAcademy = -10
    const Granary = -10
    const Housing = 75
    const Amphitheater = -10
    const ArcherTower = -10
    const School = -10
    const MageTower = -10
    const TradeOffice = -10
    const Architect = -10
    const ParadeGrounds = -10
    const Barracks = -10
    const Dock = -10
    const Fishmonger = -10
    const Farms = 10
    const Hamlet = 35
end

# struct holding the different environments for Crypts and Caverns dungeons
# we'll use this to determine how many resources to grant during staking
namespace EnvironmentIds:
    const DesertOasis = 1
    const StoneTemple = 2
    const ForestRuins = 3
    const MountainDeep = 4
    const UnderwaterKeep = 5
    const EmbersGlow = 6
end

namespace EnvironmentProduction:
    const DesertOasis = 170
    const StoneTemple = 90
    const ForestRuins = 80
    const MountainDeep = 60
    const UnderwaterKeep = 25
    const EmbersGlow = 10
end

namespace ExternalContractIds:
    const Lords = 1
    const Realms = 2
    const StakedRealms = 3
    const Resources = 4
    const Treasury = 5
    const Storage = 6
    const Crypts = 7
    const StakedCrypts = 8
end

namespace ModuleIds:
    const L01Settling = 1
    const L02Resources = 2
    const L03Buildings = 3
    const L04Calculator = 4
    const L05Wonders = 5
    const L06Combat = 11  # TODO: Refactor Combat code so this can be 6 to fit in sequence with other contracts
    const L07Crypts = 7
    const L08CryptsResources = 8
end

namespace RealmBuildingIds:
    const Fairgrounds = 1
    const RoyalReserve = 2
    const GrandMarket = 3
    const Castle = 4
    const Guild = 5
    const OfficerAcademy = 6
    const Granary = 7
    const Housing = 8
    const Amphitheater = 9
    const ArcherTower = 10
    const School = 11
    const MageTower = 12
    const TradeOffice = 13
    const Architect = 14
    const ParadeGrounds = 15
    const Barracks = 16
    const Dock = 17
    const Fishmonger = 18
    const Farms = 19
    const Hamlet = 20
end

namespace TraitIds:
    const Region = 1
    const City = 2
    const Harbour = 3
    const River = 4
end

namespace RealmBuildingLimitTraitIds:
    const Fairgrounds = TraitIds.Region
    const RoyalReserve = TraitIds.Region
    const GrandMarket = TraitIds.Region
    const Castle = TraitIds.Region
    const Guild = TraitIds.Region
    const OfficerAcademy = TraitIds.Region
    const Granary = TraitIds.City
    const Housing = TraitIds.City
    const Amphitheater = TraitIds.City
    const ArcherTower = TraitIds.City
    const School = TraitIds.City
    const MageTower = TraitIds.City
    const TradeOffice = TraitIds.City
    const Architect = TraitIds.City
    const ParadeGrounds = TraitIds.City
    const Barracks = TraitIds.City
    const Dock = TraitIds.Harbour
    const Fishmonger = TraitIds.Harbour
    const Farms = TraitIds.River
    const Hamlet = TraitIds.River
end

namespace ResourceIds:
    # Realms Resources
    const Wood = 1
    const Stone = 2
    const Coal = 3
    const Copper = 4
    const Obsidian = 5
    const Silver = 6
    const Ironwood = 7
    const ColdIron = 8
    const Gold = 9
    const Hartwood = 10
    const Diamonds = 11
    const Sapphire = 12
    const Ruby = 13
    const DeepCrystal = 14
    const Ignium = 15
    const EtherealSilica = 16
    const TrueIce = 17
    const TwilightQuartz = 18
    const AlchemicalSilver = 19
    const Adamantine = 20
    const Mithral = 21
    const Dragonhide = 22
    # Crypts and Caverns Resources
    const DesertGlass = 23
    const DivineCloth = 24
    const CuriousSpore = 25
    const UnrefinedOre = 26
    const SunkenShekel = 27
    const Demonhide = 28
    # IMPORTANT: if you're adding to this enum
    # make sure the SIZE is one greater than the
    # maximal value; certain algorithms depend on that
    const SIZE = 29
end

namespace TroopId:
    const Watchman = 1
    const Guard = 2
    const GuardCaptain = 3
    const Squire = 4
    const Knight = 5
    const KnightCommander = 6
    const Scout = 7
    const Archer = 8
    const Sniper = 9
    const Scorpio = 10
    const Ballista = 11
    const Catapult = 12
    const Apprentice = 13
    const Mage = 14
    const Arcanist = 15
    const GrandMarshal = 16
    # IMPORTANT: if you're adding to this enum
    # make sure the SIZE is one greater than the
    # maximal value; certain algorithms depend on that
    const SIZE = 17
end

namespace TroopType:
    const Melee = 1
    const Ranged = 2
    const Siege = 3
end
