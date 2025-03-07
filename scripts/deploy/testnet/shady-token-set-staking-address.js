const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const shady_token = addresses.TESTNET_SHADY_TOKEN;
    const staking = addresses.TESTNET_NFT_STAKING;

    const signer = (await hre.ethers.getSigners())[0]
    const contract = await hre.ethers.getContractAt('Shady_token', shady_token, signer)
    let succ = await contract.setStakingAddress(staking);

    console.log("Result: %s", succ);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
