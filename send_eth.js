
const { JsonRpcProvider, Wallet, parseEther } = require("ethers");

// Configuration
const PROVIDER_URL = process.env.PROVIDER_URL; // Set in environment variables
const PRIVATE_KEY = process.env.PRIVATE_KEY; // Set in environment variables
const RECIPIENT_ADDRESS = "0x06EE840642a33367ee59fCA237F270d5119d1356";
const AMOUNT_IN_ETHER = "64"; // 64 ETH

if (!PROVIDER_URL || !PRIVATE_KEY) {
    console.error("Error: PROVIDER_URL and PRIVATE_KEY must be set as environment variables.");
    process.exit(1);
}

async function main() {
    try {
        // Connect to the Ethereum network
        const provider = new JsonRpcProvider(PROVIDER_URL);
        console.log("Connected to the Ethereum network");

        // Create a wallet instance
        const wallet = new Wallet(PRIVATE_KEY, provider);
        console.log("Wallet connected:", wallet.address);

        // Transaction details
        const tx = {
            to: RECIPIENT_ADDRESS,
            value: parseEther(AMOUNT_IN_ETHER), // Convert ETH to Wei
        };

        // Send the transaction
        console.log(`Sending ${AMOUNT_IN_ETHER} ETH to ${RECIPIENT_ADDRESS}...`);
        const transactionResponse = await wallet.sendTransaction(tx);
        console.log("Transaction sent! Hash:", transactionResponse.hash);

        // Wait for the transaction to be mined
        const receipt = await transactionResponse.wait();
        console.log("Transaction confirmed!");
        console.log("Block Number:", receipt.blockNumber);
        console.log("Transaction Hash:", receipt.transactionHash);
    } catch (error) {
        console.error("Error during transaction:", error);
    }
}

// Execute the script
main();
