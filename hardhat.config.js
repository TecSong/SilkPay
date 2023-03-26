require("@nomicfoundation/hardhat-toolbox");
const dotenv = require("dotenv");
dotenv.config()

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
      accounts: [PRIVATE_KEY],
      //   process.env.PRIVATE_KEY !== undefined
      //     ? [process.env.PRIVATE_KEY]
      //     : [PRIVATE_KEY],
      // gas: 2100000,
      // gasPrice: 8000000000,
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
    Bedrock: {
      // url: "https://goerli.optimism.io",
      url: `https://opt-goerli.g.alchemy.com/v2/${INFURA_API_KEY}`,
      // gasPrice: 1000000000,
      accounts: [PRIVATE_KEY],
    },
    zkEVM: {
      url: `https://rpc.public.zkevm-test.net`,
      // url: `https://polygon-zkevm-testnet.rpc.thirdweb.com`,
      // gasPrice: 10000000000,
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
      {
        network: "Bedrock",
        urls: {
          apiURL: "",
          browserURL: "https://goerli-optimism.etherscan.io/",
        }
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
