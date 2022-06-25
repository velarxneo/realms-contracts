
import { deployContract, getDeployedAddressInt, getOwnerAccountInt } from '../../helpers'

async function main() {
  const contractName = 'ModuleController'

  const ownerAccount = getOwnerAccountInt()
  // Collect params
  const arbiter = getDeployedAddressInt("Arbiter");
  const realms = getDeployedAddressInt("realms_erc721_mintable");
  const s_realms = getDeployedAddressInt("realms_erc721_stakeable");
  const lords = getDeployedAddressInt("lords_erc20_mintable");
  const resources = getDeployedAddressInt("resources_erc1155_mintable_burnable");
  const storage = getDeployedAddressInt("Storage");
  console.log(arbiter)
  console.log(lords)
  console.log(resources)
  console.log(realms)
  console.log(ownerAccount)
  console.log(s_realms)
  console.log(storage)
  // Magically deploy + write all files and stuff 
  await deployContract(contractName, contractName, [arbiter, lords, resources, realms, ownerAccount, s_realms, storage])
}

main().then(e => console.error(e))