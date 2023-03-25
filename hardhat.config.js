require("@nomicfoundation/hardhat-toolbox");

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0083490dee5291a22645800449e18accda14210b3bdfd35fdde2d1698825b1db";
const INFURA_API_KEY = process.env.INFURA_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.7",
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
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
    zkEVM: {
      url: `https://rpc.public.zkevm-test.net`,
      accounts: [PRIVATE_KEY],
    },
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
