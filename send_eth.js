const { ethers } = require("ethers");

// Read all parameters from environment variables
const PROVIDER_URL = process.env.PROVIDER_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RECIPIENT_ADDRESS = process.env.RECIPIENT_ADDRESS;
const AMOUNT_IN_ETHER = process.env.AMOUNT_IN_ETHER;

if (!PROVIDER_URL || !PRIVATE_KEY || !RECIPIENT_ADDRESS || !AMOUNT_IN_ETHER) {
    console.error("Set PROVIDER_URL, PRIVATE_KEY, RECIPIENT_ADDRESS, and AMOUNT_IN_ETHER as environment variables.");
    process.exit(1);
}

async function main() {
    try {
        const provider = new ethers.providers.JsonRpcProvider(PROVIDER_URL);
        const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

        // Optional: fetch gas price and set gas limit
        const gasPrice = await provider.getGasPrice();
        const gasLimit = ethers.utils.hexlify(21000); // Standard ETH transfer

        const tx = {
            to: RECIPIENT_ADDRESS,
            value: ethers.utils.parseEther(AMOUNT_IN_ETHER),
            gasLimit: gasLimit,
            gasPrice: gasPrice,
        };

        const sentTx = await wallet.sendTransaction(tx);
        console.log("Transaction sent! Hash:", sentTx.hash);

        const receipt = await sentTx.wait();
        console.log("Transaction confirmed in block:", receipt.blockNumber);
    } catch (err) {
        console.error("Error:", err);
    }
}

main();

