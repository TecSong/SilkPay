require("@nomicfoundation/hardhat-toolbox");

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const INFURA_API_KEY = process.env.INFURA_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.7",
  networks: {
    sepolia: {
      url: "https://rpc.sepolia.org",
      accounts: [PRIVATE_KEY],
      gas: 2100000,
      gasPrice: 8000000000,
    },
    scrollAlpha: {
      url: "https://alpha-rpc.scroll.io/l2" || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined
          ? [process.env.PRIVATE_KEY]
          : [PRIVATE_KEY],
      gas: 2100000,
      gasPrice: 8000000000,
    },
    gnosis: {
      url: "https://rpc.gnosischain.com",
      accounts: [PRIVATE_KEY],
    },
    chiado: {
      url: "https://rpc.chiadochain.net",
      gasPrice: 1000000000,
      accounts: [PRIVATE_KEY],
    },
    optestnet: {
      url: "https://goerli.optimism.io",
      gasPrice: 1000000000,
      accounts: [PRIVATE_KEY],
    },
    zkEVM: {
      url: "https://rpc.public.zkevm-test.net",
      gasPrice: 1000000000,
      accounts: [PRIVATE_KEY],
    },
    mantle: {
      url: "https://rpc.testnet.mantle.xyz/",
      accounts: [PRIVATE_KEY] // Uses the private key from the .env file
    }
  },
  etherscan: {
    customChains: [
      {
        network: "chiado",
        chainId: 10200,
        urls: {
          //Blockscout
          apiURL: "https://blockscout.com/gnosis/chiado/api",
          browserURL: "https://blockscout.com/gnosis/chiado",
        },
      },
      {
        network: "gnosis",
        chainId: 100,
        urls: {
          // 3) Select to what explorer verify the contracts
          // Gnosisscan
          apiURL: "https://api.gnosisscan.io/api",
          browserURL: "https://gnosisscan.io/",
          // Blockscout
          //apiURL: "https://blockscout.com/xdai/mainnet/api",
          //browserURL: "https://blockscout.com/xdai/mainnet",
        },
      },
    ],
    apiKey: {
      //4) Insert your Gnosisscan API key
      //blockscout explorer verification does not require keys
      chiado: "your key",
      gnosis: "your key",
    },
  },
};
