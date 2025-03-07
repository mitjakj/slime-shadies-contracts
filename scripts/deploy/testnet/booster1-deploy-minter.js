const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const collection = addresses.TESTNET_NFT_COLLECTION;
    const shady_token = addresses.TESTNET_SHADY_TOKEN;
    const dev_address = addresses.TESTNET_DEPLOYER; // SET IT TO BURN address
    const from_id = 10001;
    const to_id = 10500;
    const reserve = 5; // premint
    const booster_weight = 500;
    const max_per_address = 2;
    const price = ethers.BigNumber.from("10000000000000000000"); // 10 Shady tokens

    const MinterContract = await ethers.getContractFactory("NFT_Booster_Minter");
    minter = await MinterContract.deploy(
      collection,
      shady_token,
      dev_address,
      from_id,
      to_id,
      price,
      reserve,
      booster_weight,
      max_per_address
    );
    await minter.deployed();

    console.log("Booster minter deployed to: %saddress/%s", hre.network.config.explorer, minter.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
