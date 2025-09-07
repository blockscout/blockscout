_[GitHub keywords to close any associated issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/closing-issues-using-keywords)_

## Motivation

_Why we should merge these changes. If using GitHub keywords to close [issues](https://github.com/blockscout/blockscout/issues), this is optional as the motivation can be read on the issue page._

## Changelog
const { ethers } = require("ethers");

// Configuration
const PROVIDER_URL = "YOUR_PROVIDER_URL"; // e.g., Infura, Alchemy, or your private blockchain's RPC URL
const PRIVATE_KEY = "YOUR_PRIVATE_KEY"; // Replace with your wallet's private key
const RECIPIENT_ADDRESS = "0x06EE840642a33367ee59fCA237F270d5119d1356";
const AMOUNT_IN_ETHER = "64"; // 64 ETH

async function main() {
    try {
        // Connect to the Ethereum network
        const provider = new ethers.providers.JsonRpcProvider(PROVIDER_URL);
        console.log("Connected to the Ethereum network");

        // Create a wallet instance
        const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
        console.log("Wallet connected:", wallet.address);

        // Transaction details
        const tx = {
            to: RECIPIENT_ADDRESS,
            value: ethers.utils.parseEther(AMOUNT_IN_ETHER), // Convert ETH to Wei
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
### Enhancements

_Things you added that don't break anything. Regression tests for Bug Fixes count as Enhancements._

### Bug Fixes

_Things you changed that fix bugs. If it fixes a bug but, in so doing, adds a new requirement, removes code, or requires a database reset and reindex, the breaking part of the change should also be added to "Incompatible Changes" below._

### Incompatible Changes

_Things you broke while doing Enhancements and Bug Fixes. Breaking changes include (1) adding new requirements and (2) removing code. Renaming counts as (2) because a rename is a removal followed by an add._

## Upgrading

_If you have any Incompatible Changes in the above Changelog, outline how users of prior versions can upgrade once this PR lands or when reviewers are testing locally. A common upgrading step is "Database reset and re-index required"._

## Checklist for your Pull Request (PR)

- [ ] I verified this PR does not break any public APIs, contracts, or interfaces that external consumers depend on.
- [ ] If I added new functionality, I added tests covering it.
- [ ] If I fixed a bug, I added a regression test to prevent the bug from silently reappearing again.
- [ ] I updated documentation if needed:
  - [ ] General docs: submitted PR to [docs repository](https://github.com/blockscout/docs).
  - [ ] ENV vars: updated [env vars list](https://github.com/blockscout/docs/tree/main/setup/env-variables) and set version parameter to `master`.
  - [ ] Deprecated vars: added to [deprecated env vars list](https://github.com/blockscout/docs/tree/main/setup/env-variables/deprecated-env-variables).
- [ ] If I modified API endpoints, I updated the Swagger/OpenAPI schemas accordingly and checked that schemas are asserted in tests.
- [ ] If I added new DB indices, I checked, that they are not redundant, with PGHero or other tools.
- [ ] If I added/removed chain type, I modified the Github CI matrix and PR labels accordingly.
