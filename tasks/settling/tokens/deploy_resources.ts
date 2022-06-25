
import { deployContract, getDeployedAddressInt, getOwnerAccountInt } from '../../helpers'
import { toFelt } from 'starknet/dist/utils/number'

async function main() {
    const contractName = 'resources_erc1155_mintable_burnable'

    // Collect params
    const ownerAccount = getOwnerAccountInt()
    const uri: string = toFelt("1234")

    // Magically deploy + write all files and stuff 
    await deployContract(contractName, contractName, [uri, ownerAccount])
}

export default main().then(e => console.error(e))