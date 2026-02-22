<h1 align="center">Blockscout</h1>
<p align="center">Blockchain Explorer for inspecting and analyzing EVM Chains.</p>
<div align="center">

[![Blockscout](https://github.com/blockscout/blockscout/actions/workflows/config.yml/badge.svg)](https://github.com/blockscout/blockscout/actions)
[![Discord](https://img.shields.io/badge/chat-Blockscout-green.svg)](https://discord.gg/blockscout)

</div>


Blockscout provides a comprehensive, easy-to-use interface for users to view, confirm, and inspect transactions on EVM (Ethereum Virtual Machine) blockchains. This includes Ethereum Mainnet, Ethereum Classic, Optimism, Gnosis Chain and many other **Ethereum testnets, private networks, L2s and sidechains**.

See our [project documentation](https://docs.blockscout.com/) for detailed information and setup instructions.

For questions, comments and feature requests see the [discussions section](https://github.com/blockscout/blockscout/discussions) or via [Discord](https://discord.com/invite/blockscout).

## About Blockscout

Blockscout allows users to search transactions, view accounts and balances, verify and interact with smart contracts and view and interact with applications on the Ethereum network including many forks, sidechains, L2s and testnets.

Blockscout is an open-source alternative to centralized, closed source block explorers such as Etherscan, Etherchain and others.  As Ethereum sidechains and L2s continue to proliferate in both private and public settings, transparent, open-source tools are needed to analyze and validate all transactions.

## Supported Projects

Blockscout currently supports several hundred chains and rollups throughout the greater blockchain ecosystem. Ethereum, Cosmos, Polkadot, Avalanche, Near and many others include Blockscout integrations. A comprehensive list is available at [chains.blockscout.com](https://chains.blockscout.com). If your project is not listed, contact the team in [Discord](https://discord.com/invite/blockscout).

## Getting Started

See the [project documentation](https://docs.blockscout.com/) for instructions:

- [Manual deployment](https://docs.blockscout.com/for-developers/deployment/manual-deployment-guide)
- [Docker-compose deployment](https://docs.blockscout.com/for-developers/deployment/docker-compose-deployment)
- [Kubernetes deployment](https://docs.blockscout.com/for-developers/deployment/kubernetes-deployment)
- [Manual deployment (backend + old UI)](https://docs.blockscout.com/for-developers/deployment/manual-old-ui)
- [Ansible deployment](https://docs.blockscout.com/for-developers/ansible-deployment)
- [ENV variables](https://docs.blockscout.com/setup/env-variables)
- [Configuration options](https://docs.blockscout.com/for-developers/configuration-options)

## Acknowledgements

We would like to thank the EthPrize foundation for their funding support.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and pull request protocol. We expect contributors to follow our [code of conduct](CODE_OF_CONDUCT.md) when submitting code or comments.

## License

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
> ## Documentation Index
> Fetch the complete documentation index at: https://docs.blockscout.com/llms.txt
> Use this file to discover all available pages before exploring further.

# ETH RPC API

# Blockscout ETH RPC Methods Reference

Complete reference for all 16 Ethereum JSON-RPC methods supported by Blockscout.

## 📋 Quick Reference

Methods use POST requests to `/api/eth-rpc` with JSON-RPC 2.0 format. API keys are not required but will increase RPS for your calls.

<Tip>
  Try these methods in the ETH RPC Endpoint Testing section
</Tip>

### Base URL Pattern

```
https://{instance}.blockscout.com/api/eth-rpc
```

Examples:

* `https://eth.blockscout.com/api/eth-rpc`
* `https://base.blockscout.com/api/eth-rpc`
* `https://optimism.blockscout.com/api/eth-rpc`

## 🔢 Methods Overview

### Read Operations (State Queries)

| Method                     | Description             | Parameters               |
| -------------------------- | ----------------------- | ------------------------ |
| `eth_blockNumber`          | Get latest block number | None                     |
| `eth_getBalance`           | Get account balance     | address, block           |
| `eth_getTransactionCount`  | Get nonce               | address, block           |
| `eth_getCode`              | Get contract bytecode   | address, block           |
| `eth_getStorageAt`         | Get storage value       | address, position, block |
| `eth_gasPrice`             | Get current gas price   | None                     |
| `eth_maxPriorityFeePerGas` | Get max priority fee    | None                     |
| `eth_chainId`              | Get chain ID            | None                     |

### Transaction Operations

| Method                      | Description               | Parameters |
| --------------------------- | ------------------------- | ---------- |
| `eth_getTransactionByHash`  | Get transaction details   | hash       |
| `eth_getTransactionReceipt` | Get transaction receipt   | hash       |
| `eth_sendRawTransaction`    | Submit signed transaction | signedData |

### Block Operations

| Method                 | Description         | Parameters          |
| ---------------------- | ------------------- | ------------------- |
| `eth_getBlockByNumber` | Get block by number | blockNumber, fullTx |
| `eth_getBlockByHash`   | Get block by hash   | blockHash, fullTx   |

### Call Operations

| Method            | Description           | Parameters         |
| ----------------- | --------------------- | ------------------ |
| `eth_call`        | Execute contract call | transaction, block |
| `eth_estimateGas` | Estimate gas cost     | transaction, block |

### Log Operations

| Method        | Description    | Parameters |
| ------------- | -------------- | ---------- |
| `eth_getLogs` | Get event logs | filter     |

***

## 📚 Detailed Method Specifications

### 1. eth\_blockNumber

**Purpose:** Get the latest block number in the chain.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_blockNumber",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1234567",
  "id": 1
}
```

***

### 2. eth\_getBalance

**Purpose:** Get the balance of an account at a given address.

**Parameters:**

* `address` (string): 20-byte address to check
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBalance",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1d863bf76508104fb",
  "id": 1
}
```

**Note:** Result is in wei (hexadecimal).

***

### 3. eth\_getLogs

**Purpose:** Get event logs matching a filter.

**Parameters:**

* `filter` (object): Filter criteria
  * `fromBlock` (string): Starting block
  * `toBlock` (string): Ending block
  * `address` (string|array): Contract address(es)
  * `topics` (array): Topic filters

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "address": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "fromBlock": "0x1234567",
    "toBlock": "latest",
    "topics": ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
  }],
  "id": 1
}
```

**Limitations:** Maximum 1000 logs per request. Use pagination for more.

***

### 4. eth\_gasPrice

**Purpose:** Get current gas price.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_gasPrice",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x4a817c800",
  "id": 1
}
```

***

### 5. eth\_getTransactionByHash

**Purpose:** Get transaction details by hash.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionByHash",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "hash": "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b",
    "from": "0x...",
    "to": "0x...",
    "value": "0x...",
    "gas": "0x...",
    "gasPrice": "0x...",
    "input": "0x...",
    "nonce": "0x...",
    "blockNumber": "0x...",
    "blockHash": "0x...",
    "transactionIndex": "0x..."
  },
  "id": 1
}
```

***

### 6. eth\_getTransactionReceipt

**Purpose:** Get transaction receipt including logs and status.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionReceipt",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "transactionHash": "0x88df...",
    "transactionIndex": "0x1",
    "blockHash": "0x...",
    "blockNumber": "0x...",
    "from": "0x...",
    "to": "0x...",
    "cumulativeGasUsed": "0x...",
    "gasUsed": "0x5208",
    "contractAddress": null,
    "logs": [],
    "logsBloom": "0x...",
    "status": "0x1",
    "effectiveGasPrice": "0x..."
  },
  "id": 1
}
```

**Status values:**

* `0x1` = Success
* `0x0` = Failure

***

### 7. eth\_chainId

**Purpose:** Get the chain ID for signing replay-protected transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_chainId",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1",
  "id": 1
}
```

**Common Chain IDs:**

* `0x1` = Ethereum Mainnet
* `0x2105` = Base
* `0xa` = Optimism
* `0x64` = Gnosis Chain

***

### 8. eth\_maxPriorityFeePerGas

**Purpose:** Get max priority fee per gas for EIP-1559 transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_maxPriorityFeePerGas",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x59682f00",
  "id": 1
}
```

***

### 9. eth\_getTransactionCount

**Purpose:** Get the nonce (transaction count) for an address.

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionCount",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5",
  "id": 1
}
```

***

### 10. eth\_getCode

**Purpose:** Get the bytecode at a given address (smart contract code).

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getCode",
  "params": [
    "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x600160008035811a818181146012578301005b601b6001356025565b8060005260206000f25b600060078202905091905056",
  "id": 1
}
```

**Note:** Returns "0x" for EOAs (non-contract addresses).

***

### 11. eth\_getStorageAt

**Purpose:** Get value from a storage position at a given address.

**Parameters:**

* `address` (string): 20-byte address of the storage
* `position` (string): Position in hex
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getStorageAt",
  "params": [
    "0x295a70b2de5e3953354a6a8344e616ed314d7251",
    "0x0",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id": 1
}
```

***

### 12. eth\_estimateGas

**Purpose:** Estimate gas required to execute a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `from` (string, optional): Sender address
  * `to` (string): Recipient address
  * `value` (string, optional): Value in hex
  * `data` (string, optional): Call data
  * `gas` (string, optional): Gas limit in hex
  * `gasPrice` (string, optional): Gas price in hex
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_estimateGas",
  "params": [{
    "from": "0x8D97689C9818892B700e27F316cc3E41e17fBeb9",
    "to": "0xd3CdA913deB6f67967B99D67aCDFa1712C293601",
    "value": "0x186a0"
  }, "latest"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5208",
  "id": 1
}
```

***

### 13. eth\_getBlockByNumber

**Purpose:** Get block information by block number.

**Parameters:**

* `block` (string): Block number in hex, or "latest", "earliest", "pending"
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByNumber",
  "params": ["0x1234567", false],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "number": "0x1234567",
    "hash": "0x...",
    "parentHash": "0x...",
    "timestamp": "0x...",
    "transactions": ["0x...", "0x..."],
    "gasLimit": "0x...",
    "gasUsed": "0x...",
    "miner": "0x...",
    ...
  },
  "id": 1
}
```

***

### 14. eth\_getBlockByHash

**Purpose:** Get block information by block hash.

**Parameters:**

* `hash` (string): 32-byte block hash
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByHash",
  "params": [
    "0x9b83c12c69edb74f6c8dd5d052765c1adf940e320bd1291696e6fa07829eee71",
    false
  ],
  "id": 1
}
```

***

### 15. eth\_sendRawTransaction

**Purpose:** Submit a pre-signed transaction for broadcast.

**Parameters:**

* `data` (string): Signed transaction data in hex

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_sendRawTransaction",
  "params": ["0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331",
  "id": 1
}
```

**Note:** Result is the transaction hash.

***

### 16. eth\_call

**Purpose:** Execute a contract call immediately without creating a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `to` (string): Contract address
  * `from` (string, optional): Sender address
  * `data` (string): Encoded function call
  * `gas` (string, optional): Gas limit
  * `gasPrice` (string, optional): Gas price
  * `value` (string, optional): Value to send
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_call",
  "params": [{
    "to": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "data": "0x70a082310000000000000000000000006E0d01A76C3Cf4288372a29124A26D4353EE51BE"
  }, "latest"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id": 1
}
```

**Common Use Cases:**

* Reading contract state
* Simulating transactions
* Calling view/pure functions
* Checking balances of ERC-20 tokens

***

## 🔧 Usage Tips

### Batch Requests

You can send multiple requests in a single HTTP call:

```json  theme={null}
[
  {
    "jsonrpc": "2.0",
    "method": "eth_blockNumber",
    "params": [],
    "id": 1
  },
  {
    "jsonrpc": "2.0",
    "method": "eth_gasPrice",
    "params": [],
    "id": 2
  }
]
```

### Error Handling

JSON-RPC errors follow this format:

```json  theme={null}
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params"
  },
  "id": 1
}
```

Common error codes:

* `-32700` = Parse error
* `-32600` = Invalid request
* `-32601` = Method not found
* `-32602` = Invalid params
* `-32603` = Internal error
* > ## Documentation Index
> Fetch the complete documentation index at: https://docs.blockscout.com/llms.txt
> Use this file to discover all available pages before exploring further.

# ETH RPC API

# Blockscout ETH RPC Methods Reference

Complete reference for all 16 Ethereum JSON-RPC methods supported by Blockscout.

## 📋 Quick Reference

Methods use POST requests to `/api/eth-rpc` with JSON-RPC 2.0 format. API keys are not required but will increase RPS for your calls.

<Tip>
  Try these methods in the ETH RPC Endpoint Testing section
</Tip>

### Base URL Pattern

```
https://{instance}.blockscout.com/api/eth-rpc
```

Examples:

* `https://eth.blockscout.com/api/eth-rpc`
* `https://base.blockscout.com/api/eth-rpc`
* `https://optimism.blockscout.com/api/eth-rpc`

## 🔢 Methods Overview

### Read Operations (State Queries)

| Method                     | Description             | Parameters               |
| -------------------------- | ----------------------- | ------------------------ |
| `eth_blockNumber`          | Get latest block number | None                     |
| `eth_getBalance`           | Get account balance     | address, block           |
| `eth_getTransactionCount`  | Get nonce               | address, block           |
| `eth_getCode`              | Get contract bytecode   | address, block           |
| `eth_getStorageAt`         | Get storage value       | address, position, block |
| `eth_gasPrice`             | Get current gas price   | None                     |
| `eth_maxPriorityFeePerGas` | Get max priority fee    | None                     |
| `eth_chainId`              | Get chain ID            | None                     |

### Transaction Operations

| Method                      | Description               | Parameters |
| --------------------------- | ------------------------- | ---------- |
| `eth_getTransactionByHash`  | Get transaction details   | hash       |
| `eth_getTransactionReceipt` | Get transaction receipt   | hash       |
| `eth_sendRawTransaction`    | Submit signed transaction | signedData |

### Block Operations

| Method                 | Description         | Parameters          |
| ---------------------- | ------------------- | ------------------- |
| `eth_getBlockByNumber` | Get block by number | blockNumber, fullTx |
| `eth_getBlockByHash`   | Get block by hash   | blockHash, fullTx   |

### Call Operations

| Method            | Description           | Parameters         |
| ----------------- | --------------------- | ------------------ |
| `eth_call`        | Execute contract call | transaction, block |
| `eth_estimateGas` | Estimate gas cost     | transaction, block |

### Log Operations

| Method        | Description    | Parameters |
| ------------- | -------------- | ---------- |
| `eth_getLogs` | Get event logs | filter     |

***

## 📚 Detailed Method Specifications

### 1. eth\_blockNumber

**Purpose:** Get the latest block number in the chain.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_blockNumber",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1234567",
  "id": 1
}
```

***

### 2. eth\_getBalance

**Purpose:** Get the balance of an account at a given address.

**Parameters:**

* `address` (string): 20-byte address to check
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBalance",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1d863bf76508104fb",
  "id": 1
}
```

**Note:** Result is in wei (hexadecimal).

***

### 3. eth\_getLogs

**Purpose:** Get event logs matching a filter.

**Parameters:**

* `filter` (object): Filter criteria
  * `fromBlock` (string): Starting block
  * `toBlock` (string): Ending block
  * `address` (string|array): Contract address(es)
  * `topics` (array): Topic filters

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "address": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "fromBlock": "0x1234567",
    "toBlock": "latest",
    "topics": ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
  }],
  "id": 1
}
```

**Limitations:** Maximum 1000 logs per request. Use pagination for more.

***

### 4. eth\_gasPrice

**Purpose:** Get current gas price.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_gasPrice",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x4a817c800",
  "id": 1
}
```

***

### 5. eth\_getTransactionByHash

**Purpose:** Get transaction details by hash.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionByHash",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "hash": "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b",
    "from": "0x...",
    "to": "0x...",
    "value": "0x...",
    "gas": "0x...",
    "gasPrice": "0x...",
    "input": "0x...",
    "nonce": "0x...",
    "blockNumber": "0x...",
    "blockHash": "0x...",
    "transactionIndex": "0x..."
  },
  "id": 1
}
```

***

### 6. eth\_getTransactionReceipt

**Purpose:** Get transaction receipt including logs and status.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionReceipt",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "transactionHash": "0x88df...",
    "transactionIndex": "0x1",
    "blockHash": "0x...",
    "blockNumber": "0x...",
    "from": "0x...",
    "to": "0x...",
    "cumulativeGasUsed": "0x...",
    "gasUsed": "0x5208",
    "contractAddress": null,
    "logs": [],
    "logsBloom": "0x...",
    "status": "0x1",
    "effectiveGasPrice": "0x..."
  },
  "id": 1
}
```

**Status values:**

* `0x1` = Success
* `0x0` = Failure

***

### 7. eth\_chainId

**Purpose:** Get the chain ID for signing replay-protected transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_chainId",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1",
  "id": 1
}
```

**Common Chain IDs:**

* `0x1` = Ethereum Mainnet
* `0x2105` = Base
* `0xa` = Optimism
* `0x64` = Gnosis Chain

***

### 8. eth\_maxPriorityFeePerGas

**Purpose:** Get max priority fee per gas for EIP-1559 transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_maxPriorityFeePerGas",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x59682f00",
  "id": 1
}
```

***

### 9. eth\_getTransactionCount

**Purpose:** Get the nonce (transaction count) for an address.

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionCount",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5",
  "id": 1
}
```

***

### 10. eth\_getCode

**Purpose:** Get the bytecode at a given address (smart contract code).

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getCode",
  "params": [
    "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x600160008035811a818181146012578301005b601b6001356025565b8060005260206000f25b600060078202905091905056",
  "id": 1
}
```

**Note:** Returns "0x" for EOAs (non-contract addresses).

***

### 11. eth\_getStorageAt

**Purpose:** Get value from a storage position at a given address.

**Parameters:**

* `address` (string): 20-byte address of the storage
* `position` (string): Position in hex
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getStorageAt",
  "params": [
    "0x295a70b2de5e3953354a6a8344e616ed314d7251",
    "0x0",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id": 1
}
```

***

### 12. eth\_estimateGas

**Purpose:** Estimate gas required to execute a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `from` (string, optional): Sender address
  * `to` (string): Recipient address
  * `value` (string, optional): Value in hex
  * `data` (string, optional): Call data
  * `gas` (string, optional): Gas limit in hex
  * `gasPrice` (string, optional): Gas price in hex
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_estimateGas",
  "params": [{
    "from": "0x8D97689C9818892B700e27F316cc3E41e17fBeb9",
    "to": "0xd3CdA913deB6f67967B99D67aCDFa1712C293601",
    "value": "0x186a0"
  }, "latest"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5208",
  "id": 1
}
```

***

### 13. eth\_getBlockByNumber

**Purpose:** Get block information by block number.

**Parameters:**

* `block` (string): Block number in hex, or "latest", "earliest", "pending"
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByNumber",
  "params": ["0x1234567", false],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "number": "0x1234567",
    "hash": "0x...",
    "parentHash": "0x...",
    "timestamp": "0x...",
    "transactions": ["0x...", "0x..."],
    "gasLimit": "0x...",
    "gasUsed": "0x...",
    "miner": "0x...",
    ...
  },
  "id": 1
}
```

***

### 14. eth\_getBlockByHash

**Purpose:** Get block information by block hash.

**Parameters:**

* `hash` (string): 32-byte block hash
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByHash",
  "params": [
    "0x9b83c12c69edb74f6c8dd5d052765c1adf940e320bd1291696e6fa07829eee71",
    false
  ],
  "id": 1
}
```

***

### 15. eth\_sendRawTransaction

**Purpose:** Submit a pre-signed transaction for broadcast.

**Parameters:**

* `data` (string): Signed transaction data in hex

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_sendRawTransaction",
  "params": ["0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331",
  "id": 1
}
```

**Note:** Result is the transaction hash.

***

### 16. eth\_call

**Purpose:** Execute a contract call immediately without creating a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `to` (string): Contract address
  * `from` (string, optional): Sender address
  * `data` (string): Encoded function call
  * `gas` (string, optional): Gas limit
  * `gasPrice` (string, optional): Gas price
  * `value` (string, optional): Value to send
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_call",
  "params": [{
    "to": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "data": "0x70a082310000000000000000000000006E0d01A76C3Cf4288372a29124A26D4353EE51BE"
  }, "latest"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id": 1
}
```

**Common Use Cases:**

* Reading contract state
* Simulating transactions
* Calling view/pure functions
* Checking balances of ERC-20 tokens

***

## 🔧 Usage Tips

### Batch Requests

You can send multiple requests in a single HTTP call:

```json  theme={null}
[
  {
    "jsonrpc": "2.0",
    "method": "eth_blockNumber",
    "params": [],
    "id": 1
  },
  {
    "jsonrpc": "2.0",
    "method": "eth_gasPrice",
    "params": [],
    "id": 2
  }
]
```

### Error Handling

JSON-RPC errors follow this format:

```json  theme={null}
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params"
  },
  "id": 1
}
```

Common error codes:

* `-32700` = Parse error
* `-32600` = Invalid request
* `-32601` = Method not found
* `-32602` = Invalid params
* `-32603` = Internal error
* > ## Documentation Index
> Fetch the complete documentation index at: https://docs.blockscout.com/llms.txt
> Use this file to discover all available pages before exploring further.

# ETH RPC API

# Blockscout ETH RPC Methods Reference

Complete reference for all 16 Ethereum JSON-RPC methods supported by Blockscout.

## 📋 Quick Reference

Methods use POST requests to `/api/eth-rpc` with JSON-RPC 2.0 format. API keys are not required but will increase RPS for your calls.

<Tip>
  Try these methods in the ETH RPC Endpoint Testing section
</Tip>

### Base URL Pattern

```
https://{instance}.blockscout.com/api/eth-rpc
```

Examples:

* `https://eth.blockscout.com/api/eth-rpc`
* `https://base.blockscout.com/api/eth-rpc`
* `https://optimism.blockscout.com/api/eth-rpc`

## 🔢 Methods Overview

### Read Operations (State Queries)

| Method                     | Description             | Parameters               |
| -------------------------- | ----------------------- | ------------------------ |
| `eth_blockNumber`          | Get latest block number | None                     |
| `eth_getBalance`           | Get account balance     | address, block           |
| `eth_getTransactionCount`  | Get nonce               | address, block           |
| `eth_getCode`              | Get contract bytecode   | address, block           |
| `eth_getStorageAt`         | Get storage value       | address, position, block |
| `eth_gasPrice`             | Get current gas price   | None                     |
| `eth_maxPriorityFeePerGas` | Get max priority fee    | None                     |
| `eth_chainId`              | Get chain ID            | None                     |

### Transaction Operations

| Method                      | Description               | Parameters |
| --------------------------- | ------------------------- | ---------- |
| `eth_getTransactionByHash`  | Get transaction details   | hash       |
| `eth_getTransactionReceipt` | Get transaction receipt   | hash       |
| `eth_sendRawTransaction`    | Submit signed transaction | signedData |

### Block Operations

| Method                 | Description         | Parameters          |
| ---------------------- | ------------------- | ------------------- |
| `eth_getBlockByNumber` | Get block by number | blockNumber, fullTx |
| `eth_getBlockByHash`   | Get block by hash   | blockHash, fullTx   |

### Call Operations

| Method            | Description           | Parameters         |
| ----------------- | --------------------- | ------------------ |
| `eth_call`        | Execute contract call | transaction, block |
| `eth_estimateGas` | Estimate gas cost     | transaction, block |

### Log Operations

| Method        | Description    | Parameters |
| ------------- | -------------- | ---------- |
| `eth_getLogs` | Get event logs | filter     |

***

## 📚 Detailed Method Specifications

### 1. eth\_blockNumber

**Purpose:** Get the latest block number in the chain.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_blockNumber",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1234567",
  "id": 1
}
```

***

### 2. eth\_getBalance

**Purpose:** Get the balance of an account at a given address.

**Parameters:**

* `address` (string): 20-byte address to check
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBalance",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1d863bf76508104fb",
  "id": 1
}
```

**Note:** Result is in wei (hexadecimal).

***

### 3. eth\_getLogs

**Purpose:** Get event logs matching a filter.

**Parameters:**

* `filter` (object): Filter criteria
  * `fromBlock` (string): Starting block
  * `toBlock` (string): Ending block
  * `address` (string|array): Contract address(es)
  * `topics` (array): Topic filters

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "address": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "fromBlock": "0x1234567",
    "toBlock": "latest",
    "topics": ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
  }],
  "id": 1
}
```

**Limitations:** Maximum 1000 logs per request. Use pagination for more.

***

### 4. eth\_gasPrice

**Purpose:** Get current gas price.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_gasPrice",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x4a817c800",
  "id": 1
}
```

***

### 5. eth\_getTransactionByHash

**Purpose:** Get transaction details by hash.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionByHash",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "hash": "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b",
    "from": "0x...",
    "to": "0x...",
    "value": "0x...",
    "gas": "0x...",
    "gasPrice": "0x...",
    "input": "0x...",
    "nonce": "0x...",
    "blockNumber": "0x...",
    "blockHash": "0x...",
    "transactionIndex": "0x..."
  },
  "id": 1
}
```

***

### 6. eth\_getTransactionReceipt

**Purpose:** Get transaction receipt including logs and status.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionReceipt",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "transactionHash": "0x88df...",
    "transactionIndex": "0x1",
    "blockHash": "0x...",
    "blockNumber": "0x...",
    "from": "0x...",
    "to": "0x...",
    "cumulativeGasUsed": "0x...",
    "gasUsed": "0x5208",
    "contractAddress": null,
    "logs": [],
    "logsBloom": "0x...",
    "status": "0x1",
    "effectiveGasPrice": "0x..."
  },
  "id": 1
}
```

**Status values:**

* `0x1` = Success
* `0x0` = Failure

***

### 7. eth\_chainId

**Purpose:** Get the chain ID for signing replay-protected transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_chainId",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1",
  "id": 1
}
```

**Common Chain IDs:**

* `0x1` = Ethereum Mainnet
* `0x2105` = Base
* `0xa` = Optimism
* `0x64` = Gnosis Chain

***

### 8. eth\_maxPriorityFeePerGas

**Purpose:** Get max priority fee per gas for EIP-1559 transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_maxPriorityFeePerGas",
  "params": [],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x59682f00",
  "id": 1
}
```

***

### 9. eth\_getTransactionCount

**Purpose:** Get the nonce (transaction count) for an address.

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionCount",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5",
  "id": 1
}
```

***

### 10. eth\_getCode

**Purpose:** Get the bytecode at a given address (smart contract code).

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getCode",
  "params": [
    "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x600160008035811a818181146012578301005b601b6001356025565b8060005260206000f25b600060078202905091905056",
  "id": 1
}
```

**Note:** Returns "0x" for EOAs (non-contract addresses).

***

### 11. eth\_getStorageAt

**Purpose:** Get value from a storage position at a given address.

**Parameters:**

* `address` (string): 20-byte address of the storage
* `position` (string): Position in hex
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getStorageAt",
  "params": [
    "0x295a70b2de5e3953354a6a8344e616ed314d7251",
    "0x0",
    "latest"
  ],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id": 1
}
```

***

### 12. eth\_estimateGas

**Purpose:** Estimate gas required to execute a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `from` (string, optional): Sender address
  * `to` (string): Recipient address
  * `value` (string, optional): Value in hex
  * `data` (string, optional): Call data
  * `gas` (string, optional): Gas limit in hex
  * `gasPrice` (string, optional): Gas price in hex
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_estimateGas",
  "params": [{
    "from": "0x8D97689C9818892B700e27F316cc3E41e17fBeb9",
    "to": "0xd3CdA913deB6f67967B99D67aCDFa1712C293601",
    "value": "0x186a0"
  }, "latest"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5208",
  "id": 1
}
```

***

### 13. eth\_getBlockByNumber

**Purpose:** Get block information by block number.

**Parameters:**

* `block` (string): Block number in hex, or "latest", "earliest", "pending"
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByNumber",
  "params": ["0x1234567", false],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "number": "0x1234567",
    "hash": "0x...",
    "parentHash": "0x...",
    "timestamp": "0x...",
    "transactions": ["0x...", "0x..."],
    "gasLimit": "0x...",
    "gasUsed": "0x...",
    "miner": "0x...",
    ...
  },
  "id": 1
}
```

***

### 14. eth\_getBlockByHash

**Purpose:** Get block information by block hash.

**Parameters:**

* `hash` (string): 32-byte block hash
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByHash",
  "params": [
    "0x9b83c12c69edb74f6c8dd5d052765c1adf940e320bd1291696e6fa07829eee71",
    false
  ],
  "id": 1
}
```

***

### 15. eth\_sendRawTransaction

**Purpose:** Submit a pre-signed transaction for broadcast.

**Parameters:**

* `data` (string): Signed transaction data in hex

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_sendRawTransaction",
  "params": ["0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331",
  "id": 1
}
```

**Note:** Result is the transaction hash.

***

### 16. eth\_call

**Purpose:** Execute a contract call immediately without creating a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `to` (string): Contract address
  * `from` (string, optional): Sender address
  * `data` (string): Encoded function call
  * `gas` (string, optional): Gas limit
  * `gasPrice` (string, optional): Gas price
  * `value` (string, optional): Value to send
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_call",
  "params": [{
    "to": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "data": "0x70a082310000000000000000000000006E0d01A76C3Cf4288372a29124A26D4353EE51BE"
  }, "latest"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id": 1
}
```

**Common Use Cases:**

* Reading contract state
* Simulating transactions
* Calling view/pure functions
* Checking balances of ERC-20 tokens

***

## 🔧 Usage Tips

### Batch Requests

You can send multiple requests in a single HTTP call:

```json  theme={null}
[
  {
    "jsonrpc": "2.0",
    "method": "eth_blockNumber",
    "params": [],
    "id": 1
  },
  {
    "jsonrpc": "2.0",
    "method": "eth_gasPrice",
    "params": [],
    "id": 2
  }
]
```

### Error Handling

JSON-RPC errors follow this format:

```json  theme={null}
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params"
  },
  "id": 1
}
```

Common error codes:

* `-32700` = Parse error
* `-32600` = Invalid request
* `-32601` = Method not found
* `-32602` = Invalid params
* `-32603` = Internal error
*> ## Documentation Index
> Fetch the complete documentation index at: https://docs.blockscout.com/llms.txt
> Use this file to discover all available pages before exploring further.

# ETH RPC API

# Blockscout ETH RPC Methods Reference

Complete reference for all 16 Ethereum JSON-RPC methods supported by Blockscout.

## 📋 Quick Reference

Methods use POST requests to `/api/eth-rpc` with JSON-RPC 2.0 format. API keys are not required but will increase RPS for your calls.

<Tip>
  Try these methods in the ETH RPC Endpoint Testing section
</Tip>

### Base URL Pattern

```
https://{instance}.blockscout.com/api/eth-rpc
```

Examples:

* `https://eth.blockscout.com/api/eth-rpc`
* `https://base.blockscout.com/api/eth-rpc`
* `https://optimism.blockscout.com/api/eth-rpc`

## 🔢 Methods Overview

### Read Operations (State Queries)

| Method                     | Description             | Parameters               |
| -------------------------- | ----------------------- | ------------------------ |
| `eth_blockNumber`          | Get latest block number | None                     |
| `eth_getBalance`           | Get account balance     | address, block           |
| `eth_getTransactionCount`  | Get nonce               | address, block           |
| `eth_getCode`              | Get contract bytecode   | address, block           |
| `eth_getStorageAt`         | Get storage value       | address, position, block |
| `eth_gasPrice`             | Get current gas price   | None                     |
| `eth_maxPriorityFeePerGas` | Get max priority fee    | None                     |
| `eth_chainId`              | Get chain ID            | None                     |

### Transaction Operations

| Method                      | Description               | Parameters |
| --------------------------- | ------------------------- | ---------- |
| `eth_getTransactionByHash`  | Get transaction details   | hash       |
| `eth_getTransactionReceipt` | Get transaction receipt   | hash       |
| `eth_sendRawTransaction`    | Submit signed transaction | signedData |

### Block Operations

| Method                 | Description         | Parameters          |
| ---------------------- | ------------------- | ------------------- |
| `eth_getBlockByNumber` | Get block by number | blockNumber, fullTx |
| `eth_getBlockByHash`   | Get block by hash   | blockHash, fullTx   |

### Call Operations

| Method            | Description           | Parameters         |
| ----------------- | --------------------- | ------------------ |
| `eth_call`        | Execute contract call | transaction, block |
| `eth_estimateGas` | Estimate gas cost     | transaction, block |

### Log Operations

| Method        | Description    | Parameters |
| ------------- | -------------- | ---------- |
| `eth_getLogs` | Get event logs | filter     |

***

## 📚 Detailed Method Specifications

### 1. eth\_blockNumber

**Purpose:** Get the latest block number in the chain.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_blockNumber",
  "params": [],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1234567",
  "id": 0x6b95B4f2...2F67e66a4c
}
```

***

### 2. eth\_getBalance

**Purpose:** Get the balance of an account at a given address.

**Parameters:**

* `address` (string): 20-byte address to check
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBalance",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1d863bf76508104fb",
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Note:** Result is in wei (hexadecimal).

***

### 3. eth\_getLogs

**Purpose:** Get event logs matching a filter.

**Parameters:**

* `filter` (object): Filter criteria
  * `fromBlock` (string): Starting block
  * `toBlock` (string): Ending block
  * `address` (string|array): Contract address(es)
  * `topics` (array): Topic filters

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "address": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "fromBlock": "0x1234567",
    "toBlock": "latest",
    "topics": ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
  }],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Limitations:** Maximum 1000 logs per request. Use pagination for more.

***

### 4. eth\_gasPrice

**Purpose:** Get current gas price.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_gasPrice",
  "params": [],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x4a817c800",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 5. eth\_getTransactionByHash

**Purpose:** Get transaction details by hash.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionByHash",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "hash": "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b",
    "from": "0x...",
    "to": "0x...",
    "value": "0x...",
    "gas": "0x...",
    "gasPrice": "0x...",
    "input": "0x...",
    "nonce": "0x...",
    "blockNumber": "0x...",
    "blockHash": "0x...",
    "transactionIndex": "0x..."
  },
  "id": 0x6b95B4f2...2F67e66a4c
}
```

***

### 6. eth\_getTransactionReceipt

**Purpose:** Get transaction receipt including logs and status.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionReceipt",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "transactionHash": "0x88df...",
    "transactionIndex": "0x1",
    "blockHash": "0x...",
    "blockNumber": "0x...",
    "from": "0x...",
    "to": "0x...",
    "cumulativeGasUsed": "0x...",
    "gasUsed": "0x5208",
    "contractAddress": null,
    "logs": [],
    "logsBloom": "0x...",
    "status": "0x1",
    "effectiveGasPrice": "0x..."
  },
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Status values:**

* `0x1` = Success
* `0x0` = Failure

***

### 7. eth\_chainId

**Purpose:** Get the chain ID for signing replay-protected transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_chainId",
  "params": [],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1",
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Common Chain IDs:**

* `0x1` = Ethereum Mainnet
* `0x2105` = Base
* `0xa` = Optimism
* `0x64` = Gnosis Chain

***

### 8. eth\_maxPriorityFeePerGas

**Purpose:** Get max priority fee per gas for EIP-1559 transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_maxPriorityFeePerGas",
  "params": [],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x59682f00",
  "id": 0x6b95B4f2...2F67e66a4c
}
```

***

### 9. eth\_getTransactionCount

**Purpose:** Get the nonce (transaction count) for an address.

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionCount",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5",
  "id": 0x6b95B4f2...2F67e66a4c
}
```

***

### 10. eth\_getCode

**Purpose:** Get the bytecode at a given address (smart contract code).

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getCode",
  "params": [
    "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
    "latest"
  ],
  "id"0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x600160008035811a818181146012578301005b601b6001356025565b8060005260206000f25b600060078202905091905056",
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Note:** Returns "0x" for EOAs (non-contract addresses).

***

### 11. eth\_getStorageAt

**Purpose:** Get value from a storage position at a given address.

**Parameters:**

* `address` (string): 20-byte address of the storage
* `position` (string): Position in hex
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getStorageAt",
  "params": [
    "0x295a70b2de5e3953354a6a8344e616ed314d7251",
    "0x0",
    "latest"
  ],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 12. eth\_estimateGas

**Purpose:** Estimate gas required to execute a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `from` (string, optional): Sender address
  * `to` (string): Recipient address
  * `value` (string, optional): Value in hex
  * `data` (string, optional): Call data
  * `gas` (string, optional): Gas limit in hex
  * `gasPrice` (string, optional): Gas price in hex
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_estimateGas",
  "params": [{
    "from": "0x8D97689C9818892B700e27F316cc3E41e17fBeb9",
    "to": "0xd3CdA913deB6f67967B99D67aCDFa1712C293601",
    "value": "0x186a0"
  }, "latest"],
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5208",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 13. eth\_getBlockByNumber

**Purpose:** Get block information by block number.

**Parameters:**

* `block` (string): Block number in hex, or "latest", "earliest", "pending"
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByNumber",
  "params": ["0x1234567", false],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "number": "0x1234567",
    "hash": "0x...",
    "parentHash": "0x...",
    "timestamp": "0x...",
    "transactions": ["0x...", "0x..."],
    "gasLimit": "0x...",
    "gasUsed": "0x...",
    "miner": "0x...",
    ...
  },
  "id"0x6b95B4f2...2F67e66a4c
}
```

***

### 14. eth\_getBlockByHash

**Purpose:** Get block information by block hash.

**Parameters:**

* `hash` (string): 32-byte block hash
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByHash",
  "params": [
    "0x9b83c12c69edb74f6c8dd5d052765c1adf940e320bd1291696e6fa07829eee71",
    false
  ],
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 15. eth\_sendRawTransaction

**Purpose:** Submit a pre-signed transaction for broadcast.

**Parameters:**

* `data` (string): Signed transaction data in hex

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_sendRawTransaction",
  "params": ["0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83"],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331",
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Note:** Result is the transaction hash.

***

### 16. eth\_call

**Purpose:** Execute a contract call immediately without creating a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `to` (string): Contract address
  * `from` (string, optional): Sender address
  * `data` (string): Encoded function call
  * `gas` (string, optional): Gas limit
  * `gasPrice` (string, optional): Gas price
  * `value` (string, optional): Value to send
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_call",
  "params": [{
    "to": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "data": "0x70a082310000000000000000000000006E0d01A76C3Cf4288372a29124A26D4353EE51BE"
  }, "latest"],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id": 0x6b95B4f2...2F67e66a4c
}
```

**Common Use Cases:**

* Reading contract state
* Simulating transactions
* Calling view/pure functions
* Checking balances of ERC-20 tokens

***

## 🔧 Usage Tips

### Batch Requests

You can send multiple requests in a single HTTP call:

```json  theme={null}
[
  {
    "jsonrpc": "2.0",
    "method": "eth_blockNumber",
    "params": [],
    "id":0x6b95B4f2...2F67e66a4c
  },
  {
    "jsonrpc": "2.0",
    "method": "eth_gasPrice",
    "params": [],
    "id":0x6b95B4f2...2F67e66a4c
  }
]
```

### Error Handling

JSON-RPC errors follow this format:

```json  theme={null}
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params"
  },
  "id":0x6b95B4f2...2F67e66a4c
}
```

Common error codes:

* `-32700` = Parse error
* `-32600` = Invalid request
* `-32601` = Method not found
* `-32602` = Invalid params
* `-32603` = Internal error
* > ## Documentation Index
> Fetch the complete documentation index at: https://docs.blockscout.com/llms.txt
> Use this file to discover all available pages before exploring further.

# ETH RPC API

# Blockscout ETH RPC Methods Reference

Complete reference for all 16 Ethereum JSON-RPC methods supported by Blockscout.

## 📋 Quick Reference

Methods use POST requests to `/api/eth-rpc` with JSON-RPC 2.0 format. API keys are not required but will increase RPS for your calls.

<Tip>
  Try these methods in the ETH RPC Endpoint Testing section
</Tip>

### Base URL Pattern

```
https://{instance}.blockscout.com/api/eth-rpc
```

Examples:

* `https://eth.blockscout.com/api/eth-rpc`
* `https://base.blockscout.com/api/eth-rpc`
* `https://optimism.blockscout.com/api/eth-rpc`

## 🔢 Methods Overview

### Read Operations (State Queries)

| Method                     | Description             | Parameters               |
| -------------------------- | ----------------------- | ------------------------ |
| `eth_blockNumber`          | Get latest block number | None                     |
| `eth_getBalance`           | Get account balance     | address, block           |
| `eth_getTransactionCount`  | Get nonce               | address, block           |
| `eth_getCode`              | Get contract bytecode   | address, block           |
| `eth_getStorageAt`         | Get storage value       | address, position, block |
| `eth_gasPrice`             | Get current gas price   | None                     |
| `eth_maxPriorityFeePerGas` | Get max priority fee    | None                     |
| `eth_chainId`              | Get chain ID  0x6b95B4f2...2F67e66a4c          | None                     |

### Transaction Operations

| Method                      | Description               | Parameters |
| --------------------------- | ------------------------- | ---------- |
| `eth_getTransactionByHash`  | Get transaction details   | hash       |
| `eth_getTransactionReceipt` | Get transaction receipt   | hash       |
| `eth_sendRawTransaction`    | Submit signed transaction | signedData |

### Block Operations

| Method                 | Description         | Parameters          |
| ---------------------- | ------------------- | ------------------- |
| `eth_getBlockByNumber` | Get block by number | blockNumber, fullTx |
| `eth_getBlockByHash`   | Get block by hash   | blockHash, fullTx   |

### Call Operations

| Method            | Description           | Parameters         |
| ----------------- | --------------------- | ------------------ |
| `eth_call`        | Execute contract call | transaction, block |
| `eth_estimateGas` | Estimate gas cost     | transaction, block |

### Log Operations

| Method        | Description    | Parameters |
| ------------- | -------------- | ---------- |
| `eth_getLogs` | Get event logs | filter     |

***

## 📚 Detailed Method Specifications

### 1. eth\_blockNumber

**Purpose:** Get the latest block number in the chain.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_blockNumber",
  "params": [],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1234567",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 2. eth\_getBalance

**Purpose:** Get the balance of an account at a given address.

**Parameters:**

* `address` (string): 20-byte address to check
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBalance",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1d863bf76508104fb",
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Note:** Result is in wei (hexadecimal).

***

### 3. eth\_getLogs

**Purpose:** Get event logs matching a filter.

**Parameters:**

* `filter` (object): Filter criteria
  * `fromBlock` (string): Starting block
  * `toBlock` (string): Ending block
  * `address` (string|array): Contract address(es)
  * `topics` (array): Topic filters

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "address": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "fromBlock": "0x1234567",
    "toBlock": "latest",
    "topics": ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
  }],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Limitations:** Maximum 1000 logs per request. Use pagination for more.

***

### 4. eth\_gasPrice

**Purpose:** Get current gas price.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_gasPrice",
  "params": [],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x4a817c800",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 5. eth\_getTransactionByHash

**Purpose:** Get transaction details by hash.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionByHash",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "hash": "0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b",
    "from": "0x...",
    "to": "0x...",
    "value": "0x...",
    "gas": "0x...",
    "gasPrice": "0x...",
    "input": "0x...",
    "nonce": "0x...",
    "blockNumber": "0x...",
    "blockHash": "0x...",
    "transactionIndex": "0x..."
  },
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 6. eth\_getTransactionReceipt

**Purpose:** Get transaction receipt including logs and status.

**Parameters:**

* `hash` (string): 32-byte transaction hash

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionReceipt",
  "params": ["0x88df016429689c079f3b2f6ad39fa052532c56795b733da78a91ebe6a713944b"],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "transactionHash": "0x88df...",
    "transactionIndex": "0x1",
    "blockHash": "0x...",
    "blockNumber": "0x...",
    "from": "0x...",
    "to": "0x...",
    "cumulativeGasUsed": "0x...",
    "gasUsed": "0x5208",
    "contractAddress": null,
    "logs": [],
    "logsBloom": "0x...",
    "status": "0x1",
    "effectiveGasPrice": "0x..."
  },
  "id"0x6b95B4f2...2F67e66a4c
}
```

**Status values:**

* `0x1` = Success
* `0x0` = Failure

***

### 7. eth\_chainId

**Purpose:** Get the chain ID for signing replay-protected transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_chainId",
  "params": [],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x1",
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Common Chain IDs:**

* `0x1` = Ethereum Mainnet
* `0x2105` = Base
* `0xa` = Optimism
* `0x64` = Gnosis Chain

***

### 8. eth\_maxPriorityFeePerGas

**Purpose:** Get max priority fee per gas for EIP-1559 transactions.

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_maxPriorityFeePerGas",
  "params": [],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x59682f00",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 9. eth\_getTransactionCount

**Purpose:** Get the nonce (transaction count) for an address.

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionCount",
  "params": [
    "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    "latest"
  ],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 10. eth\_getCode

**Purpose:** Get the bytecode at a given address (smart contract code).

**Parameters:**

* `address` (string): 20-byte address
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getCode",
  "params": [
    "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
    "latest"
  ],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x600160008035811a818181146012578301005b601b6001356025565b8060005260206000f25b600060078202905091905056",
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Note:** Returns "0x" for EOAs (non-contract addresses).

***

### 11. eth\_getStorageAt

**Purpose:** Get value from a storage position at a given address.

**Parameters:**

* `address` (string): 20-byte address of the storage
* `position` (string): Position in hex
* `block` (string): Block number in hex, or "latest", "earliest", "pending"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getStorageAt",
  "params": [
    "0x295a70b2de5e3953354a6a8344e616ed314d7251",
    "0x0",
    "latest"
  ],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 12. eth\_estimateGas

**Purpose:** Estimate gas required to execute a transaction.

**Parameters:**

* `transaction` (object): Transaction call object
  * `from` (string, optional): Sender address
  * `to` (string): Recipient address
  * `value` (string, optional): Value in hex
  * `data` (string, optional): Call data
  * `gas` (string, optional): Gas limit in hex
  * `gasPrice` (string, optional): Gas price in hex
* `block` (string, optional): Block number or "latest"

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_estimateGas",
  "params": [{
    "from": "0x8D97689C9818892B700e27F316cc3E41e17fBeb9",
    "to": "0xd3CdA913deB6f67967B99D67aCDFa1712C293601",
    "value": "0x186a0"
  }, "latest"],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0x5208",
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 13. eth\_getBlockByNumber

**Purpose:** Get block information by block number.

**Parameters:**

* `block` (string): Block number in hex, or "latest", "earliest", "pending"
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByNumber",
  "params": ["0x1234567", false],
  "id":0x6b95B4f2...2F67e66a4c
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": {
    "number": "0x1234567",
    "hash": "0x...",
    "parentHash": "0x...",
    "timestamp": "0x...",
    "transactions": ["0x...", "0x..."],
    "gasLimit": "0x...",
    "gasUsed": "0x...",
    "miner": "0x...",
    ...
  },
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 14. eth\_getBlockByHash

**Purpose:** Get block information by block hash.

**Parameters:**

* `hash` (string): 32-byte block hash
* `fullTx` (boolean): If true, returns full transaction objects; if false, only hashes

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_getBlockByHash",
  "params": [
    "0x9b83c12c69edb74f6c8dd5d052765c1adf940e320bd1291696e6fa07829eee71",
    false
  ],
  "id":0x6b95B4f2...2F67e66a4c
}
```

***

### 15. eth\_sendRawTransaction

**Purpose:** Submit a pre-signed transaction for broadcast.

**Parameters:**

* `data` (string): Signed transaction data in hex

**Request:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "method": "eth_sendRawTransaction",
  "params": ["0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83"],
  "id": 1
}
```

**Response:**

```json  theme={null}
{
  "jsonrpc": "2.0",
  "result": "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331",
  "id": 1
}
```

**Note:** Result is the transaction hash.

***

### 16. eth\_call

**Purpose:** Execute a contract call immediately without creating a transaction.

**Paramet
