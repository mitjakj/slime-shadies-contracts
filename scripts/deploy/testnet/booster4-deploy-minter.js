const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const collection = addresses.TESTNET_NFT_COLLECTION;
    const shady_token = addresses.TESTNET_SHADY_TOKEN;
    const dev_address = addresses.ADDRESS_DEAD; // SET IT TO BURN address
    const minter_address = addresses.TESTNET_MAIN_MINTER;
    const from_id = 11001;
    const to_id = 11200;
    const reserve = 10; // premint
    const booster_weight = 700;
    const max_per_address = 6;
    const price = ethers.BigNumber.from("55000000000000000000"); // 55 Shady tokens

    const MinterContract = await ethers.getContractFactory("NFT_Booster_Minter_OM_Claim");
    minter = await MinterContract.deploy(
      collection,
      shady_token,
      dev_address,
      from_id,
      to_id,
      price,
      reserve,
      booster_weight,
      max_per_address,
      minter_address
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
