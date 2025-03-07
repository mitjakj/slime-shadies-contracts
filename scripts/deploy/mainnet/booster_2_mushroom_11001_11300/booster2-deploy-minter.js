const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const collection = addresses.MAINNET_NFT_COLLECTION;
    const shady_token = addresses.MAINNET_SHADY_TOKEN;
    const dev_address = addresses.ADDRESS_DEAD; // SET IT TO BURN address
    const minter_address = addresses.MAINNET_MAIN_MINTER;
    const from_id = 11001;
    const to_id = 11300;
    const reserve = 0; // premint
    const booster_weight = 5000;
    const max_per_address = 1;
    const price = ethers.BigNumber.from("1500000000000000000000"); // 1500 Shady tokens

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

    console.log("Booster minter OM Claim deployed to: %saddress/%s", hre.network.config.explorer, minter.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
