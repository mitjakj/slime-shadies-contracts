require("@nomiclabs/hardhat-waffle");
require('hardhat-abi-exporter');
require('hardhat-contract-sizer');

const { privateKeyMainnet, privateKeyTestnet } = require('./secrets.json');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.0",
    networks: {
        avaxmainnet: {
            url: "https://api.avax.network/ext/bc/C/rpc",
            chainId: 43114,
            // 225 gwei - Avalanche used a fixed 225 gwei price now switched to dynamic between 75 and 225 gwei.
            // I would still use 225 as default if it is not too expensive.
            // https://docs.avax.network/learn/platform-overview/transaction-fees#c-chain-fees
            gasPrice: 26000000000,
            // Can only go up to 8000000 since that is avalanche max block limit
            gas: 6000000,
            accounts: [privateKeyMainnet],
            explorer: 'https://cchain.explorer.avax.network/',
        },
        avaxtestnet: {
            url: "https://api.avax-test.network/ext/bc/C/rpc", 
            chainId: 43113,
            // 225 gwei - Avalanche used a fixed 225 gwei price now switched to dynamic between 75 and 225 gwei.
            // I would still use 225 as default if it is not too expensive.
            // https://docs.avax.network/learn/platform-overview/transaction-fees#c-chain-fees
            gasPrice: 75000000000, 
            gas: 8000000,
            accounts: [privateKeyTestnet],
            explorer: 'https://cchain.explorer.avax-test.network/',
        },
    },
    abiExporter: {
        path: './data/abi',
        clear: true,
        flat: true,
        only: [
            'NFT_Minter'
        ],
    },
    projectAddresses: {
        'MAINNET_DEPLOYER': '0x12562fA3c4F5161D51E5D2E54E4e05aa75eac6DB',
        'MAINNET_ROYALTIES': '0x0ABE85619bb4748F24b7Dd717Ea17a4185ee08A7',
        'MAINNET_NFT_COLLECTION': '0x7728a5B1620d0a9C39e8B6043841F59A0a31e378',
        'MAINNET_MAIN_MINTER': '0x41AadE565Ef3466c515F1215DE7cA39247F6Aa88',

        // --------------------------------------------------------------

        'TESTNET_DEPLOYER': '0xd68cF79770774bDb01f892c279B6FC3C86A76310',
        'TESTNET_ROYALTIES': '0x3D8B5CD30eDf24711bF7A2C448EFF3710a64eE39',
        'TESTNET_NFT_COLLECTION': '0x5659E871044Dd03263036dF9176c58E4Ca0490Cf',
        'TESTNET_MAIN_MINTER': '0x9E344514deB3d8384cC69B3058F89946Cfc534Cd',
        'TESTNET_SHADY_TOKEN': '0x81caa0f48A7187BF6248D121cBb6cb43a21077ec',
        'TESTNET_NFT_STAKING': '0x12E660671A365aD7d232cE6e20B139a7aeB9DA85',
        'TESTNET_BOOSTER_MINTER_1': '0x54Ba3fCB699fD69a9D255DfB55F777b5228B2e6a',
        'TESTNET_BOOSTER_MINTER_2': '0x4Be7511C30753C5906efEADe89999DD4a8EAaDF2',
    },
};
