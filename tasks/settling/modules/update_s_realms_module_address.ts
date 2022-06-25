import { deployContract, getDeployedAddressInt, getOwnerAccountInt, getSigner } from '../../helpers'

async function main() {
    const contractName = 'realms_erc721_stakeable'

    const S_Realms_ERC721_Mintable = getDeployedAddressInt('realms_erc721_stakeable');
    // Collect params
    const L01_Settling = getDeployedAddressInt("L01_Settling"); // module id 1

    const res = await getSigner().execute(
        {
            contractAddress: S_Realms_ERC721_Mintable,
            entrypoint: "Set_module_access",
            calldata: [L01_Settling]
        }
    )

    console.log("Set_module_access", res)
}

main().then(e => console.error(e))