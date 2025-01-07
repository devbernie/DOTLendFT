import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers"; // Cần cài đặt: npm install @nomiclabs/hardhat-ethers ethers
import { Wallet } from "ethers";
import "@typechain/hardhat";

// Thay chuỗi 12 từ mnemonic phrase của bạn vào đây
const MNEMONIC = "black office spin radar harvest legend supply depend puppy suit six steel";

// Chuyển đổi mnemonic phrase thành Wallet, sau đó lấy private key
const wallet = Wallet.fromPhrase(MNEMONIC);
const PRIVATE_KEY = wallet.privateKey;

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.20", // Cập nhật phiên bản Solidity
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    defaultNetwork: "localhost",
    networks: {
        localhost: {
            url: "http://127.0.0.1:8545",
        },
        westend: {
            url: "https://westend-rpc.polkadot.io",
            accounts: [PRIVATE_KEY], // Sử dụng private key từ mnemonic phrase
        },
    },
};

export default config;