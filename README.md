# Install needed stuf
npm install --save-dev hardhat
npm install --save-dev @nomiclabs/hardhat-waffle ethereum-waffle chai @nomiclabs/hardhat-ethers ethers @openzeppelin/hardhat-upgrades @openzeppelin/contracts hardhat-abi-exporter hardhat-abi-exporter

# Ustvari projekt
npx hardhat

# Compile contracts
npx hardhat compile

# Run contract test
npx hardhat test

# Run script
npx hardhat run scripts/sample-script.js

# Run script with local node
npx hardhat run scripts/sample-script.js --network localhost

# Run script with test bscnode
npx hardhat run --network bsctestnet scripts/sample-script.js

# Slime Shadies Contracts
# Slime Shadies Contracts
# Slime Shadies Contracts

Flatten contract
- npx hardhat flatten contracts/NFT_Minter.sol > NFT_Minter_Flatten.sol

TESTNET: 
- npx hardhat run --network avaxtestnet scripts/create-account.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/deploy-nft-collection.js
---- SET TESTNET_NFT_COLLECTION -----
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/deploy-main-minter.js
---- SET TESTNET_MAIN_MINTER ------
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/set-main-minter.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/deploy-shady-token.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/deploy-nft-staking.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/shady-token-set-staking-address.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/collection-set-staking-address.js
  
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/booster1-deploy-minter.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/booster1-set-authorized-address.js
  
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/booster2-deploy-minter.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/booster2-set-authorized-address.js
  
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/booster3-deploy-minter.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/booster3-set-authorized-address.js

- npx hardhat run --network avaxtestnet scripts/deploy/testnet/booster4-deploy-minter.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/booster4-set-authorized-address.js

- npx hardhat run --network avaxtestnet scripts/deploy/testnet/deploy-racing-game.js
- npx hardhat run --network avaxtestnet scripts/deploy/testnet/deploy-lottery.js

MAINNET:
- npx hardhat run --network avaxmainnet scripts/create-account.js
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/deploy-nft-collection.js
---- SET MAINNET_NFT_COLLECTION -----
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/deploy-main-minter.js
---- SET MAINNET_MAIN_MINTER ------
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/set-main-minter.js
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/deploy-shady-token.js
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/deploy-nft-staking.js
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/shady-token-set-staking-address.js
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/collection-set-staking-address.js
# BOOSTER 1
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/booster_1_xsalad/booster1-deploy-minter.js
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/booster_1_xsalad/booster1-set-authorized-address.js
# BOOSTER 2
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/booster_2_mushroom_11001_11300/booster2-deploy-minter.js
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/booster_2_mushroom_11001_11300/booster2-set-authorized-address.js
# BOOSTER 3
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/booster_3_magnet_11301_11301/booster3-deploy-minter.js
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/booster_3_magnet_11301_11301/booster3-set-authorized-address.js

# RACING GAME
- npx hardhat run --network avaxmainnet scripts/deploy/mainnet/deploy-racing-game.js
