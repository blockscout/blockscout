defmodule Explorer.EthRPC do
  @moduledoc """
  Ethereum JSON RPC methods logic implementation.
  """
  import Explorer.EthRpcHelper

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Ecto.Type, as: EctoType
  alias Explorer.{BloomFilter, Chain, Helper, Repo}

  alias Explorer.Chain.{
    Block,
    Data,
    DenormalizationHelper,
    Hash,
    Hash.Address,
    Transaction,
    Transaction.Status,
    Wei
  }

  alias Explorer.Chain.Cache.{BlockNumber, GasPriceOracle}
  alias Explorer.Etherscan.{Blocks, Logs}

  @nil_gas_price_message "Gas price is not estimated yet"

  @methods %{
    "eth_blockNumber" => %{
      action: :eth_block_number,
      notes: nil,
      example: """
      {"id": 0, "jsonrpc": "2.0", "method": "eth_blockNumber", "params": []}
      """,
      params: [],
      result: """
      {"id": 0, "jsonrpc": "2.0", "result": "0xb3415c"}
      """
    },
    "eth_getBalance" => %{
      action: :eth_get_balance,
      notes: """
      The `earliest` parameter will not work as expected currently, because genesis block balances
      are not currently imported
      """,
      example: """
      {"id": 0, "jsonrpc": "2.0", "method": "eth_getBalance", "params": ["0x0000000000000000000000000000000000000007", "latest"]}
      """,
      params: [
        %{
          name: "Data",
          description: "20 Bytes - address to check for balance",
          type: "string",
          default: nil,
          required: true
        },
        %{
          name: "Quantity|Tag",
          description: "Integer block number, or the string \"latest\", \"earliest\" or \"pending\"",
          type: "string",
          default: "latest",
          required: true
        }
      ],
      result: """
      {"id": 0, "jsonrpc": "2.0", "result": "0x0234c8a3397aab58"}
      """
    },
    "eth_getLogs" => %{
      action: :eth_get_logs,
      notes: """
      Will never return more than 1000 log entries.\n
      For this reason, you can use pagination options to request the next page. Pagination options params: {"logIndex": "3D", "blockNumber": "6423AC"} which include parameters from the last log received from the previous request. These three parameters are required for pagination.
      """,
      example: """
      {"id": 0, "jsonrpc": "2.0", "method": "eth_getLogs",
       "params": [
        {"address": "0xc78Be425090Dbd437532594D12267C5934Cc6c6f",
         "paging_options": {"logIndex": "3D", "blockNumber": "6423AC"},
         "fromBlock": "earliest",
         "toBlock": "latest",
         "topics": ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]}]}
      """,
      params: [
        %{name: "Object", description: "The filter options", type: "json", default: nil, required: true}
      ],
      result: """
      {
        "id":0,
        "jsonrpc":"2.0",
        "result": [{
          "logIndex": "0x1",
          "blockNumber":"0x1b4",
          "blockHash": "0x8216c5785ac562ff41e2dcfdf5785ac562ff41e2dcfdf829c5a142f1fccd7d",
          "transactionHash":  "0xdf829c5a142f1fccd7d8216c5785ac562ff41e2dcfdf5785ac562ff41e2dcf",
          "transactionIndex": "0x0",
          "address": "0x16c5785ac562ff41e2dcfdf829c5a142f1fccd7d",
          "data":"0x0000000000000000000000000000000000000000000000000000000000000000",
          "topics": ["0x59ebeb90bc63057b6515673c3ecf9438e5058bca0f92585014eced636878c9a5"]
          }]
      }
      """
    },
    "eth_gasPrice" => %{
      action: :eth_gas_price,
      notes: """
      Returns the average gas price per gas in wei.
      """,
      example: """
      {"jsonrpc": "2.0", "id": 4, "method": "eth_gasPrice", "params": []}
      """,
      params: [],
      result: """
      {"jsonrpc": "2.0", "id": 4, "result": "0xbf69c09bb"}
      """
    },
    "eth_getTransactionByHash" => %{
      action: :eth_get_transaction_by_hash,
      notes: """
      """,
      example: """
      {"jsonrpc": "2.0", "id": 4, "method": "eth_getTransactionByHash", "params": ["0x98318a5a22e363928d4565382c1022a8aed169b6a657f639c2f5c6e2c5114e4c"]}
      """,
      params: [
        %{
          name: "Data",
          description: "32 Bytes - transaction hash to get",
          type: "string",
          default: nil,
          required: true
        }
      ],
      result: """
      {
        "jsonrpc": "2.0",
        "result": {
            "blockHash": "0x33c4ddb4478395b9d73aad2eb8640004a4a312da29ebccbaa33933a43edda019",
            "blockNumber": "0x87855e",
            "chainId": "0x5",
            "from": "0xe38ecdf3cfbaf5cf347e6a3d6490eb34e3a0119d",
            "gas": "0x186a0",
            "gasPrice": "0x195d",
            "hash": "0xfe524295c6c01ab25645035a228387bf0e64c8af429f3dd9d6ef2e3b05337839",
            "input": "0xe9e05c42000000000000000000000000e38ecdf3cfbaf5cf347e6a3d6490eb34e3a0119d0000000000000000000000000000000000000000000000000001c6bf5263400000000000000000000000000000000000000000000000000000000000000186a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "maxFeePerGas": null,
            "maxPriorityFeePerGas": null,
            "nonce": "0x1",
            "r": "0xf2a3f18fd456ef9a9d6201cf622b5ad14db9cfc6786ba574e036037f80a15d61",
            "s": "0x4cbb018dc0a966cd15a6bf5f3d432c72127639314d6aeb7a6bbb36000d86dc08",
            "to": "0xe93c8cd0d409341205a592f8c4ac1a5fe5585cfa",
            "transactionIndex": "0x7f",
            "type": "0x0",
            "v": "0x2d",
            "value": "0x1c6bf52634000"
        },
        "id": 4
      }
      """
    },
    "eth_getTransactionReceipt" => %{
      action: :eth_get_transaction_receipt,
      notes: """
      """,
      example: """
      {"jsonrpc": "2.0","id": 0,"method": "eth_getTransactionReceipt","params": ["0xFE524295C6C01AB25645035A228387BF0E64C8AF429F3DD9D6EF2E3B05337839"]}
      """,
      params: [
        %{
          name: "Data",
          description: "32 Bytes - transaction hash to get",
          type: "string",
          default: nil,
          required: true
        }
      ],
      result: """
      {
        "jsonrpc": "2.0",
        "result": {
            "logsBloom": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000040000000000000000000000000002000000000000000000000000000000000000000000000000030000000000000000000800000000000000000000000000000000000000000000000002000000008000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000002000000000000000080000000000000000000000",
            "blockHash": "0x33c4ddb4478395b9d73aad2eb8640004a4a312da29ebccbaa33933a43edda019",
            "blockNumber": "0x87855e",
            "contractAddress": null,
            "cumulativeGasUsed": "0x15a9b84",
            "effectiveGasPrice": "0x195d",
            "from": "0xe38ecdf3cfbaf5cf347e6a3d6490eb34e3a0119d",
            "gasUsed": "0x9821",
            "logs": [
                {
                    "address": "0xe93c8cd0d409341205a592f8c4ac1a5fe5585cfa",
                    "blockHash": "0x33c4ddb4478395b9d73aad2eb8640004a4a312da29ebccbaa33933a43edda019",
                    "blockNumber": "0x87855e",
                    "data": "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000490000000000000000000000000000000000000000000000000001c6bf526340000000000000000000000000000000000000000000000000000001c6bf5263400000000000000186a0000000000000000000000000000000000000000000000000",
                    "logIndex": "0xdf",
                    "removed": false,
                    "topics": [
                        "0xb3813568d9991fc951961fcb4c784893574240a28925604d09fc577c55bb7c32",
                        "0x000000000000000000000000e38ecdf3cfbaf5cf347e6a3d6490eb34e3a0119d",
                        "0x000000000000000000000000e38ecdf3cfbaf5cf347e6a3d6490eb34e3a0119d",
                        "0x0000000000000000000000000000000000000000000000000000000000000000"
                    ],
                    "transactionHash": "0xfe524295c6c01ab25645035a228387bf0e64c8af429f3dd9d6ef2e3b05337839",
                    "transactionIndex": "0x7f"
                }
            ],
            "status": "0x1",
            "to": "0xe93c8cd0d409341205a592f8c4ac1a5fe5585cfa",
            "transactionHash": "0xfe524295c6c01ab25645035a228387bf0e64c8af429f3dd9d6ef2e3b05337839",
            "transactionIndex": "0x7f",
            "type": "0x0"
        },
        "id": 0
      }
      """
    },
    "eth_chainId" => %{
      action: :eth_chain_id,
      notes: """
      """,
      example: """
      {"jsonrpc": "2.0","id": 0,"method": "eth_chainId","params": []}
      """,
      params: [],
      result: """
      {
        "jsonrpc": "2.0",
        "id": 0,
        "result": "0x5"
      }
      """
    },
    "eth_maxPriorityFeePerGas" => %{
      action: :eth_max_priority_fee_per_gas,
      notes: """
      """,
      example: """
      {"jsonrpc": "2.0","id": 0,"method": "eth_maxPriorityFeePerGas","params": []}
      """,
      params: [],
      result: """
      {
        "jsonrpc": "2.0",
        "id": 0,
        "result": "0x3b9aca00"
      }
      """
    }
  }

  @proxy_methods %{
    "eth_getTransactionCount" => %{
      arity: 2,
      params_validators: [&address_hash_validator/1, &block_validator/1],
      example: """
      {"id": 0, "jsonrpc": "2.0", "method": "eth_getTransactionCount", "params": ["0x0000000000000000000000000000000000000007", "latest"]}
      """,
      result: """
      {"id": 0, "jsonrpc": "2.0", "result": "0x2"}
      """
    },
    "eth_getCode" => %{
      arity: 2,
      params_validators: [&address_hash_validator/1, &block_validator/1],
      example: """
      {"jsonrpc":"2.0","id": 0,"method":"eth_getCode","params":["0x1BF313AADe1e1f76295943f40B558Eb13Db7aA99", "latest"]}
      """,
      result: """
      {
        "jsonrpc": "2.0",
        "result": "0x60806040523661001357610011610017565b005b6100115b610027610022610067565b61009f565b565b606061004e838360405180606001604052806027815260200161026b602791396100c3565b9392505050565b6001600160a01b03163b151590565b90565b600061009a7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc546001600160a01b031690565b905090565b3660008037600080366000845af43d6000803e8080156100be573d6000f35b3d6000fd5b6060600080856001600160a01b0316856040516100e0919061021b565b600060405180830381855af49150503d806000811461011b576040519150601f19603f3d011682016040523d82523d6000602084013e610120565b606091505b50915091506101318683838761013b565b9695505050505050565b606083156101af5782516000036101a8576001600160a01b0385163b6101a85760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e747261637400000060448201526064015b60405180910390fd5b50816101b9565b6101b983836101c1565b949350505050565b8151156101d15781518083602001fd5b8060405162461bcd60e51b815260040161019f9190610237565b60005b838110156102065781810151838201526020016101ee565b83811115610215576000848401525b50505050565b6000825161022d8184602087016101eb565b9190910192915050565b60208152600082518060208401526102568160408501602087016101eb565b601f01601f1916919091016040019291505056fe416464726573733a206c6f772d6c6576656c2064656c65676174652063616c6c206661696c6564a2646970667358221220ef6e0977d993c1b69ec75a2f9fd6a53122d4ad4f9d71477641195afb6a6a45dd64736f6c634300080f0033",
        "id": 0
      }
      """
    },
    "eth_getStorageAt" => %{
      arity: 3,
      params_validators: [&address_hash_validator/1, &integer_validator/1, &block_validator/1],
      example: """
      {"jsonrpc":"2.0","id":4,"method":"eth_getStorageAt","params":["0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F", "0x", "latest"]}
      """,
      result: """
      {
        "jsonrpc": "2.0",
        "result": "0x0000000000000000000000000000000000000000000000000000000000000000",
        "id": 4
      }
      """
    },
    "eth_estimateGas" => %{
      arity: 2,
      params_validators: [&eth_call_validator/1, &block_validator/1],
      example: """
      {"jsonrpc":"2.0","id": 0,"method":"eth_estimateGas","params":[{"to": "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F", "input": "0xd4aae0c4", "from": "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F"}, "latest"]}
      """,
      result: """
      {
        "jsonrpc": "2.0",
        "result": "0x5bb6",
        "id": 0
      }
      """
    },
    "eth_getBlockByNumber" => %{
      arity: 2,
      params_validators: [&block_validator/1, &bool_validator/1],
      example: """
      {"jsonrpc":"2.0","id": 0,"method":"eth_getBlockByNumber","params":["latest", false]}
      """,
      result: """
      {
        "jsonrpc": "2.0",
        "result": {
            "baseFeePerGas": "0x7",
            "blobGasUsed": "0x0",
            "difficulty": "0x0",
            "excessBlobGas": "0x4bc0000",
            "extraData": "0xd883010d0a846765746888676f312e32312e35856c696e7578",
            "gasLimit": "0x1c9c380",
            "gasUsed": "0x29b80d",
            "hash": "0xbc2e3a9caf7364d306fe4af34d2e9f0a3d478ed1a8e135bf7cd0845646c858f5",
            "logsBloom": "0x022100021800180480000040e0008004001044020100000204080000a20001100100100002000802c00020194040204000020010000200400000020004212000804100a4242020041800108d0228082402000040090000c80001040080000080000600000224a0b00000d88000004803000000220008014000204010100040008000804408000004200000250010400004001481a80001080080404104114040032000307022969010004000840040000322400002010108490180088040205030055002481208004903100400070000104000002008001008080010002020001818002020a04000501101080000000000201004000001400040880000000000",
            "miner": "0x94750381be1aba0504c666ee1db118f68f0780d4",
            "mixHash": "0xd6b01921b81abdec5eccc9f5e17246be9dfec6d3bdbf59503bdeee2db3f97a57",
            "nonce": "0x0000000000000000",
            "number": "0xa0ff94",
            "parentBeaconBlockRoot": "0xbd4670ba8503146561cb96962185fc251e2040eed07fccc749a26b8edbfd2d1c",
            "parentHash": "0x7d4de3172a22e4549b28492ab9ffe6b5bf050b82d2c9b744133657aa7ae4385d",
            "receiptsRoot": "0x13ae8ce96a643074f94bc1358b1ac1a3e3660856df943b9c6b60d499386e580d",
            "sha3Uncles": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
            "size": "0x2d07",
            "stateRoot": "0x68510947af6edb94d0d1852d881589001318872b5bad832006c569e1a4f26871",
            "timestamp": "0x65d07350",
            "totalDifficulty": "0xa4a470",
            "transactions": [
                "0xa3bb1b7bb5ee2d04114d47bbca1d8597c390e7c8ccfe04b5bfe96f6dfe897ec7",
                "0xb6f680d4ba7e258e5e306744e61be1abb9b6cd005eb9423badc0b3603eb4ad5c",
                "0x3c97b4ee54827e95ebf915dafdba9059ba5f4013c0371d443fe934a644725c60",
                "0xd91e6db89992030da48d92825220053b1ea39f6d8d619c0f3fbc9a9e059c903e",
                "0xbf763dc0a81dd2ef44f19673f001de560bce4db1499b7c0461c208afd863a62c",
                "0xadd61d6e79560df74dc72891b2b19c83586d7857e313c0fdea9edbe1bfb11866",
                "0xc66df09eaefac0348f48ce9e3f79e27a537bc8f274c525dd884f285d5e05bf31",
                "0x217a26e8e407638e68364c2edebdae35f2a55eae080caa9ab31be430247a06e7",
                "0xcae598dde02f35993cc4dad6f431596d8326a69b8f6563156edc3e970d6736d6",
                "0xcfa79201e7574bce217f3f790f99bee8e0af45cffcd75ad17a9742630664df3f",
                "0xe1e9b3b32e1098b3e08786407043410a6142481c1076818341cb05d7ebb3aaa3",
                "0x7ce2eb696fd7c60e443bfeeeb39c2011d968b7bcfa40c20613549963f11e30a6",
                "0xb4b5db2b4397e89b068ca01fc1b6bf8494a7fcd60e39e7059baef2968e874ba4",
                "0x877e4ce429f4b64a095e0648b5ee69c31591116a697d03fddc5ff069302c944d",
                "0xa5b8f358a3210221551250369c8dc2584c79fb424af1dd134bdab3a125eb1ea8",
                "0x1c1d3df874c3ff9b84195bfe0bd5dbd50677443ff9a429bd01de4a18ccaf9293",
                "0x79be4e1a433f250a35b7898916a0611f957fb7ca522836354eebfa421b2c8c99",
                "0xd1c7fc2537a6627d0056e70a23bf90f988eabc518a31cd3d7520ec4ca0f9f9f0",
                "0xb8c0b577257a0a184bf53454b68ce612a7567bcce48a64ee10e8b3d899c6ee16",
                "0x26e81d1ba0109e5f50da13cb03d70a4fd5ffc97a0dad8e0c33fa7a8856db1480",
                "0x4667088b1ab61818ebd08810a354dbe2f1ce9a4cb3f735aa692efcc8f15c7e5f"
            ],
            "transactionsRoot": "0x9d4d5a21e9ae6294a2a197c6d051a184c109882a7f74b7e63aaf3e64e4a77a33",
            "uncles": [],
            "withdrawals": [
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x13d378",
                    "index": "0x1cdf824",
                    "validatorIndex": "0xa6d24"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x124012",
                    "index": "0x1cdf825",
                    "validatorIndex": "0xa6d25"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x175e6f",
                    "index": "0x1cdf826",
                    "validatorIndex": "0xa6d26"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x16b5fe",
                    "index": "0x1cdf827",
                    "validatorIndex": "0xa6d27"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x1660d2",
                    "index": "0x1cdf828",
                    "validatorIndex": "0xa6d28"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x145405",
                    "index": "0x1cdf829",
                    "validatorIndex": "0xa6d29"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x16246d",
                    "index": "0x1cdf82a",
                    "validatorIndex": "0xa6d2a"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x14a5a1",
                    "index": "0x1cdf82b",
                    "validatorIndex": "0xa6d2b"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x142199",
                    "index": "0x1cdf82c",
                    "validatorIndex": "0xa6d2c"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x182250",
                    "index": "0x1cdf82d",
                    "validatorIndex": "0xa6d2d"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x18b97e",
                    "index": "0x1cdf82e",
                    "validatorIndex": "0xa6d2e"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x151536",
                    "index": "0x1cdf82f",
                    "validatorIndex": "0xa6d2f"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x14bc4a",
                    "index": "0x1cdf830",
                    "validatorIndex": "0xa6d30"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x162f06",
                    "index": "0x1cdf831",
                    "validatorIndex": "0xa6d31"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x13563b",
                    "index": "0x1cdf832",
                    "validatorIndex": "0xa6d32"
                },
                {
                    "address": "0x46e77b9485b13b4d401dac9ad3f59700a5200aeb",
                    "amount": "0x148d8b",
                    "index": "0x1cdf833",
                    "validatorIndex": "0xa6d33"
                }
            ],
            "withdrawalsRoot": "0xc6a4b2cace2cc78c3a304731165b848e455fc7a3bf876837048cb4974a62c25f"
        },
        "id": 0
      }
      """
    },
    "eth_getBlockByHash" => %{
      arity: 2,
      params_validators: [&hash_validator/1, &bool_validator/1],
      example: """
      {"jsonrpc":"2.0","id": 0,"method":"eth_getBlockByHash","params":["0x2980314632a35ff83ef1f26a2a972259dca49353ed9368a04f21bcd7a5512231", false]}
      """,
      result: """
      {
        "jsonrpc": "2.0",
        "id": 0,
        "result": {
            "baseFeePerGas": "0x7",
            "blobGasUsed": "0xc0000",
            "difficulty": "0x0",
            "excessBlobGas": "0x4b40000",
            "extraData": "0x496c6c756d696e61746520446d6f63726174697a6520447374726962757465",
            "gasLimit": "0x1c9c380",
            "gasUsed": "0x2ff140",
            "hash": "0x2980314632a35ff83ef1f26a2a972259dca49353ed9368a04f21bcd7a5512231",
            "logsBloom": "0x40200000202018800808200040082040800001000040000000200984800600000200000000000810000020014000200028000000200000010530034004202010000440800d00a0000100000800000820020100009040808c80004000000040000017000003040610800002002800081a405800080060140080004a100000000308220100000400020002000100004000040412020010020000018040000000010700804008040088108001020004110008026280800021824180002c00008200a01440120000223009022014801001120080000020080000090100020000281004102000802802a1820024000c00020008000290151802004000080000000804",
            "miner": "0xb64a30399f7f6b0c154c2e7af0a3ec7b0a5b131a",
            "mixHash": "0xe5cf393a9e4b40800fd4e4a1d2be0de08e7aabc83de5fd16ff719680d7a04253",
            "nonce": "0x0000000000000000",
            "number": "0xa21bc8",
            "parentBeaconBlockRoot": "0xca280fd409ee503ae331931d64ee7fc29da9ed566cba6dfc4212a2f2f8004c41",
            "parentHash": "0xc2fc3c51d15a2fe6f219079694865ffd9f8fe56e714d9bc49e9451e1c430acf9",
            "receiptsRoot": "0x7941071eea76cec0eb4541854bd7820ef36c4d44ae51413063b45d9ea127313d",
            "sha3Uncles": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
            "size": "0x34cf",
            "stateRoot": "0xcff5056271c6e6f6bf04d2e82392fa3ebcf2bc4aca9fe8801edcfcc261ddb557",
            "timestamp": "0x65e324a4",
            "totalDifficulty": "0xa4a470",
            "transactions": [
                "0x204c69c327e3202adba5cfb1e15b99e63fe104905e19a2359d827788f24b0579",
                "0x2d07b3bc722c139ffe2ed6a32fc56e944569cc47511fef6e0351dc1da9a23562",
                "0x87772fafc7eee41d723a2dcdf2ceaae3726d40a9588ae1f7802f03dce6902fbc",
                "0x2e18d4a8bd9b4d0d70651097e44b25f29b4c013ff548ea6e5f3eb975b2bdfb78",
                "0xf54ef7af503a7031dc01696339cfcfee3066979a63e3ed626c15bb8282273cea",
                "0xb71201da6ad30304942a308e3a7666198394f1916accc9db72d03c1b508c8065",
                "0xdc854518c44ae0c3fb80b8b9fdde5da72445552356f79bbfc45d7503a32a23f8",
                "0x8b866e254a609a1a4163484cf330bdfc6c6a1878cd35dcc9fbfe2256f324a626",
                "0xbc7448bf0c34c0a358ead13e8d3687cbccbbb7fe4048d005cb6648c897bc9254",
                "0xa01733dc6d416a59d69fe17dc9d6960dbeb013b0dab2cd59b72cf84b371d19c1",
                "0x1c194a1bca34deb14e93e9007de6f971856c43a65208393254f0b2e6f99deab3",
                "0x9e9c8a6094300ed29a22892e87ab7fe33d19630ccdd85a0cce72ce6095d0c7da",
                "0xa1d6c2fe6a937e437cda199cc0f6891727c0f3ca810a262fb3179fd961cb95c4",
                "0xc4b55bada8c0c044f1e8bbd7fb57cd3a46844848e273720fc7bbc757d8e68665",
                "0x8e971964ef06896d541d5cefef7cebc79d60d6746aae2fa39e954608e2c49824",
                "0x6d120cf3998a767e567ef1b6615e5a14c380103b287c92d1da229cabc49ebb77",
                "0x95d1b8d32a80809d79f4a0246e960fec11b59c07f1a33207485dda0b356b3c2c",
                "0xa19b4b6372a9c8145e03d62e91536468169350790162508c0f07c66849fde86d",
                "0x55348af743327b1377082b9fccddfcdefe7300b65e7ed32575c09d881ece711d",
                "0xaaf03a35d70aa96582889565d1211e32fc395c9e63ce82d25cc23518e38aa4bc",
                "0x85054ea8eddd5b1e8d010f8aac77693484c5863d3355756a64bd0225124c8fca"
            ],
            "transactionsRoot": "0x22309b0cc7df445160ca2c6ca344e63296231fad2e9322989477851d38c0eea0",
            "uncles": [],
            "withdrawals": [
                {
                    "index": "0x1dfb534",
                    "validatorIndex": "0xaef81",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1e2a5b"
                },
                {
                    "index": "0x1dfb535",
                    "validatorIndex": "0xaef82",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1f9526"
                },
                {
                    "index": "0x1dfb536",
                    "validatorIndex": "0xaef83",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1fa60c"
                },
                {
                    "index": "0x1dfb537",
                    "validatorIndex": "0xaef84",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1e806a"
                },
                {
                    "index": "0x1dfb538",
                    "validatorIndex": "0xaef85",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1eb4e4"
                },
                {
                    "index": "0x1dfb539",
                    "validatorIndex": "0xaef86",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x2054a0"
                },
                {
                    "index": "0x1dfb53a",
                    "validatorIndex": "0xaef87",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1d984a"
                },
                {
                    "index": "0x1dfb53b",
                    "validatorIndex": "0xaef88",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1fa4d4"
                },
                {
                    "index": "0x1dfb53c",
                    "validatorIndex": "0xaef89",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x203a98"
                },
                {
                    "index": "0x1dfb53d",
                    "validatorIndex": "0xaef8a",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1fec28"
                },
                {
                    "index": "0x1dfb53e",
                    "validatorIndex": "0xaef8b",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x2025a5"
                },
                {
                    "index": "0x1dfb53f",
                    "validatorIndex": "0xaef8c",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1fdb08"
                },
                {
                    "index": "0x1dfb540",
                    "validatorIndex": "0xaef8d",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x200a11"
                },
                {
                    "index": "0x1dfb541",
                    "validatorIndex": "0xaef8e",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1f03d5"
                },
                {
                    "index": "0x1dfb542",
                    "validatorIndex": "0xaef8f",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x200804"
                },
                {
                    "index": "0x1dfb543",
                    "validatorIndex": "0xaef90",
                    "address": "0xe2e336478e97bfd6a84c0e246f1b8695dd4e990d",
                    "amount": "0x1dd0bb"
                }
            ],
            "withdrawalsRoot": "0xcba66455c17861d36575f98adedc90b1fc56bbef7982992cab6914528dbd0100"
        }
      }
      """
    },
    "eth_sendRawTransaction" => %{
      arity: 1,
      params_validators: [&hex_data_validator/1],
      example: """
      {"jsonrpc":"2.0","id": 0,"method":"eth_sendRawTransaction","params":["0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675"]}
      """,
      result: """
      {
        "jsonrpc": "2.0",
        "id": 0,
        "result": "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d1527331"
      }
      """
    },
    "eth_call" => %{
      arity: 2,
      params_validators: [&eth_call_validator/1, &block_validator/1],
      example: """
      {"jsonrpc":"2.0","id": 0,"method":"eth_call","params":[{"to": "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F", "input": "0xd4aae0c4", "from": "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F"}, "latest"]}
      """,
      result: """
      {
        "jsonrpc": "2.0",
        "result": "0x0000000000000000000000001dd91b354ebd706ab3ac7c727455c7baa164945a",
        "id": 0
      }
      """
    }
  }

  @index_to_word %{
    0 => "first",
    1 => "second",
    2 => "third",
    3 => "fourth"
  }

  @incorrect_number_of_params "Incorrect number of params."

  @spec responses([map()]) :: [map()]
  def responses(requests) do
    requests =
      requests
      |> Enum.with_index()

    proxy_requests =
      requests
      |> Enum.reduce(%{}, fn {request, index}, acc ->
        case proxy_method?(request) do
          true ->
            Map.put(acc, index, request)

          {:error, _reason} = error ->
            Map.put(acc, index, error)

          false ->
            acc
        end
      end)
      |> json_rpc()

    Enum.map(requests, fn {request, index} ->
      with {:proxy, nil} <- {:proxy, proxy_requests[index]},
           {:id, {:ok, id}} <- {:id, Map.fetch(request, "id")},
           {:request, {:ok, result}} <- {:request, do_eth_request(request)} do
        format_success(result, id)
      else
        {:id, :error} -> format_error("id is a required field", 0)
        {:request, {:error, message}} -> format_error(message, Map.get(request, "id"))
        {:proxy, {:error, message}} -> format_error(message, Map.get(request, "id"))
        {:proxy, %{result: result}} -> format_success(result, Map.get(request, "id"))
        {:proxy, %{error: error}} -> format_error(error, Map.get(request, "id"))
      end
    end)
  end

  defp proxy_method?(%{"jsonrpc" => "2.0", "method" => method, "params" => params, "id" => id})
       when is_list(params) and (is_number(id) or is_binary(id) or is_nil(id)) do
    with method_definition when not is_nil(method_definition) <- @proxy_methods[method],
         {:arity, true} <- {:arity, method_definition[:arity] == length(params)},
         :ok <- validate_params(method_definition[:params_validators], params) do
      true
    else
      {:error, _reason} = error ->
        error

      {:arity, false} ->
        {:error, @incorrect_number_of_params}

      _ ->
        false
    end
  end

  defp proxy_method?(_), do: false

  defp validate_params(validators, params) do
    validators
    |> Enum.zip(params)
    |> Enum.reduce_while(:ok, fn
      {validator_func, param}, :ok ->
        {:cont, validator_func.(param)}

      _, error ->
        {:halt, error}
    end)
  end

  defp json_rpc(map) when is_map(map) do
    to_request =
      Enum.flat_map(Map.values(map), fn
        {:error, _} ->
          []

        map when is_map(map) ->
          [request_to_elixir(map)]
      end)

    with [_ | _] = to_request <- to_request,
         {:ok, responses} <-
           EthereumJSONRPC.json_rpc(to_request, Application.get_env(:explorer, :json_rpc_named_arguments)) do
      {map, []} =
        Enum.map_reduce(map, responses, fn
          {_index, {:error, _}} = elem, responses ->
            {elem, responses}

          {index, _request}, [response | other_responses] ->
            {{index, response}, other_responses}
        end)

      Enum.into(map, %{})
    else
      [] ->
        map

      {:error, _reason} = error ->
        map
        |> Enum.map(fn
          {_index, {:error, _}} = elem ->
            elem

          {index, _request} ->
            {index, error}
        end)
        |> Enum.into(%{})
    end
  end

  defp request_to_elixir(%{"jsonrpc" => json_rpc, "method" => method, "params" => params, "id" => id}) do
    %{jsonrpc: json_rpc, method: method, params: params, id: id}
  end

  @doc """
  Handles `eth_blockNumber` method
  """
  @spec eth_block_number() :: {:ok, String.t()}
  def eth_block_number do
    max_block_number = BlockNumber.get_max()

    max_block_number_hex =
      max_block_number
      |> encode_quantity()

    {:ok, max_block_number_hex}
  end

  @doc """
  Handles `eth_getBalance` method
  """
  @spec eth_get_balance(String.t(), String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def eth_get_balance(address_param, block_param \\ nil) do
    with {:address, {:ok, address}} <- {:address, Chain.string_to_address_hash(address_param)},
         {:block, {:ok, block}} <- {:block, block_param(block_param)},
         {:balance, {:ok, balance}} <- {:balance, Blocks.get_balance_as_of_block(address, block)} do
      {:ok, Wei.hex_format(balance)}
    else
      {:address, :error} ->
        {:error, "Query parameter 'address' is invalid"}

      {:block, :error} ->
        {:error, "Query parameter 'block' is invalid"}

      {:balance, {:error, :not_found}} ->
        {:error, "Balance not found"}
    end
  end

  @doc """
  Handles `eth_gasPrice` method
  """
  @spec eth_gas_price() :: {:ok, String.t()} | {:error, String.t()}
  def eth_gas_price do
    case GasPriceOracle.get_gas_prices() do
      {:ok, gas_prices} ->
        {:ok, Wei.hex_format(gas_prices[:average][:wei])}

      _ ->
        {:error, @nil_gas_price_message}
    end
  end

  @doc """
  Handles `eth_maxPriorityFeePerGas` method
  """
  @spec eth_max_priority_fee_per_gas() :: {:ok, String.t()} | {:error, String.t()}
  def eth_max_priority_fee_per_gas do
    case GasPriceOracle.get_gas_prices() do
      {:ok, gas_prices} ->
        {:ok, Wei.hex_format(gas_prices[:average][:priority_fee_wei])}

      _ ->
        {:error, @nil_gas_price_message}
    end
  end

  @doc """
  Handles `eth_chainId` method
  """
  @spec eth_chain_id() :: {:ok, String.t() | nil}
  def eth_chain_id do
    {:ok, chain_id()}
  end

  @doc """
  Handles `eth_getTransactionByHash` method
  """
  @spec eth_get_transaction_by_hash(String.t()) :: {:ok, map() | nil} | {:error, String.t()}
  def eth_get_transaction_by_hash(transaction_hash_string) do
    necessity_by_association =
      %{signed_authorizations: :optional}
      |> Map.merge(chain_type_transaction_necessity_by_association())

    validate_and_render_transaction(transaction_hash_string, &render_transaction/1,
      api?: true,
      necessity_by_association: necessity_by_association
    )
  end

  defp render_transaction(transaction) do
    result =
      %{
        "blockHash" => transaction.block_hash,
        "blockNumber" => encode_quantity(transaction.block_number),
        "from" => transaction.from_address_hash,
        "gas" => encode_quantity(transaction.gas),
        "gasPrice" => transaction.gas_price |> Wei.to(:wei) |> encode_quantity(),
        "hash" => transaction.hash,
        "input" => transaction.input,
        "nonce" => encode_quantity(transaction.nonce),
        "to" => transaction.to_address_hash,
        "transactionIndex" => encode_quantity(transaction.index),
        "value" => transaction.value |> Wei.to(:wei) |> encode_quantity(),
        "type" => encode_quantity(transaction.type) || "0x0",
        "chainId" => chain_id(),
        "v" => encode_quantity(transaction.v),
        "r" => encode_quantity(transaction.r),
        "s" => encode_quantity(transaction.s)
      }
      |> maybe_add_eip_1559_fields(transaction)
      |> maybe_add_y_parity(transaction)
      |> maybe_add_signed_authorizations(transaction)
      |> maybe_add_chain_type_extra_transaction_info_properties(transaction)
      |> maybe_add_access_list(transaction)

    {:ok, result}
  end

  @doc """
  Handles `eth_getTransactionReceipt` method
  """
  @spec eth_get_transaction_receipt(String.t()) :: {:ok, map() | nil} | {:error, String.t()}
  def eth_get_transaction_receipt(transaction_hash_string) do
    necessity_by_association =
      %{block: :optional, logs: :optional}
      |> Map.merge(chain_type_transaction_necessity_by_association())

    validate_and_render_transaction(transaction_hash_string, &render_transaction_receipt/1,
      api?: true,
      necessity_by_association: necessity_by_association
    )
  end

  defp chain_type_transaction_necessity_by_association do
    if Application.get_env(:explorer, :chain_type) == :ethereum do
      %{:beacon_blob_transaction => :optional}
    else
      %{}
    end
  end

  defp render_transaction_receipt(transaction) do
    {:ok, status} = Status.dump(transaction.status)

    props =
      %{
        "blockHash" => transaction.block_hash,
        "blockNumber" => encode_quantity(transaction.block_number),
        "contractAddress" => transaction.created_contract_address_hash,
        "cumulativeGasUsed" => encode_quantity(transaction.cumulative_gas_used),
        "effectiveGasPrice" =>
          (transaction.gas_price || transaction |> Transaction.effective_gas_price())
          |> Wei.to(:wei)
          |> encode_quantity(),
        "from" => transaction.from_address_hash,
        "gasUsed" => encode_quantity(transaction.gas_used),
        "logs" => Enum.map(transaction.logs, &render_log(&1, transaction)),
        "logsBloom" => "0x" <> (transaction.logs |> BloomFilter.logs_bloom() |> Base.encode16(case: :lower)),
        "status" => encode_quantity(status),
        "to" => transaction.to_address_hash,
        "transactionHash" => transaction.hash,
        "transactionIndex" => encode_quantity(transaction.index),
        "type" => encode_quantity(transaction.type) || "0x0"
      }
      |> maybe_add_chain_type_extra_receipt_properties(transaction)

    {:ok, props}
  end

  defp maybe_add_eip_1559_fields(props, %Transaction{
         max_fee_per_gas: max_fee_per_gas,
         max_priority_fee_per_gas: max_priority_fee_per_gas
       })
       when not is_nil(max_fee_per_gas) and not is_nil(max_priority_fee_per_gas) do
    props
    |> Map.put("maxFeePerGas", max_fee_per_gas |> Wei.to(:wei) |> encode_quantity())
    |> Map.put("maxPriorityFeePerGas", max_priority_fee_per_gas |> Wei.to(:wei) |> encode_quantity())
  end

  defp maybe_add_eip_1559_fields(props, _), do: props

  # yParity shouldn't be added for legacy (type 0) and is_nil(type) transactions
  defp maybe_add_y_parity(props, %Transaction{type: type, v: v}) when not is_nil(type) and type > 0 do
    props
    |> Map.put("yParity", encode_quantity(v))
  end

  defp maybe_add_y_parity(props, %Transaction{type: _type}), do: props

  defp maybe_add_signed_authorizations(props, %Transaction{type: 4, signed_authorizations: signed_authorizations}) do
    prepared_signed_authorizations =
      signed_authorizations
      |> Enum.map(fn signed_authorization ->
        %{
          "chainId" => String.downcase(integer_to_quantity(signed_authorization.chain_id)),
          "nonce" => Helper.integer_to_hex(Decimal.to_integer(signed_authorization.nonce)),
          "address" => to_string(signed_authorization.address),
          "r" => Helper.decimal_to_hex(signed_authorization.r),
          "s" => Helper.decimal_to_hex(signed_authorization.s),
          "yParity" => Helper.integer_to_hex(signed_authorization.v)
        }
      end)

    props
    |> Map.put("authorizationList", prepared_signed_authorizations)
  end

  defp maybe_add_signed_authorizations(props, %Transaction{type: 4}) do
    props
    |> Map.put("authorizationList", [])
  end

  defp maybe_add_signed_authorizations(props, _transaction), do: props

  defp maybe_add_access_list(props, %Transaction{type: type}) when not is_nil(type) and type > 0 do
    props
    |> Map.put("accessList", [])
  end

  defp maybe_add_access_list(props, _transaction), do: props

  defp maybe_add_chain_type_extra_transaction_info_properties(props, %{beacon_blob_transaction: beacon_blob_transaction}) do
    if Application.get_env(:explorer, :chain_type) == :ethereum && beacon_blob_transaction do
      props
      |> Map.put("maxFeePerBlobGas", Helper.decimal_to_hex(beacon_blob_transaction.max_fee_per_blob_gas))
      |> Map.put("blobVersionedHashes", beacon_blob_transaction.blob_versioned_hashes)
    else
      props
    end
  end

  defp maybe_add_chain_type_extra_transaction_info_properties(props, _transaction), do: props

  defp maybe_add_chain_type_extra_receipt_properties(props, %{beacon_blob_transaction: beacon_blob_transaction}) do
    if Application.get_env(:explorer, :chain_type) == :ethereum && beacon_blob_transaction do
      props
      |> Map.put("blobGasPrice", Helper.decimal_to_hex(beacon_blob_transaction.blob_gas_price))
      |> Map.put("blobGasUsed", Helper.decimal_to_hex(beacon_blob_transaction.blob_gas_used))
    else
      props
    end
  end

  defp maybe_add_chain_type_extra_receipt_properties(props, _transaction), do: props

  defp validate_and_render_transaction(transaction_hash_string, render_func, params) do
    with {:transaction_hash, {:ok, transaction_hash}} <-
           {:transaction_hash, Chain.string_to_full_hash(transaction_hash_string)},
         {:transaction, {:ok, transaction}} <- {:transaction, Chain.hash_to_transaction(transaction_hash, params)} do
      render_func.(transaction)
    else
      {:transaction_hash, :error} ->
        {:error, "Transaction hash is invalid"}

      {:transaction, _} ->
        {:ok, nil}
    end
  end

  def eth_get_logs(filter_options) do
    with {:ok, address_or_topic_params} <- address_or_topic_params(filter_options),
         {:ok, from_block_param, to_block_param} <- logs_blocks_filter(filter_options),
         {:ok, from_block} <- cast_block(from_block_param),
         {:ok, to_block} <- cast_block(to_block_param),
         {:ok, paging_options} <- paging_options(filter_options) do
      filter =
        address_or_topic_params
        |> Map.put(:from_block, from_block)
        |> Map.put(:to_block, to_block)

      logs =
        filter
        |> Logs.list_logs(paging_options)
        |> Enum.map(&render_log/1)

      {:ok, logs}
    else
      {:error, message} when is_bitstring(message) ->
        {:error, message}

      {:error, :empty} ->
        {:ok, []}

      _ ->
        {:error, "Something went wrong."}
    end
  end

  defp render_log(log) do
    topics = prepare_topics(log)

    %{
      "address" => to_string(log.address_hash),
      "blockHash" => to_string(log.block_hash),
      "blockNumber" =>
        log.block_number
        |> encode_quantity(),
      "data" => to_string(log.data),
      "logIndex" =>
        log.index
        |> encode_quantity(),
      "removed" => log.block_consensus == false,
      "topics" => topics,
      "transactionHash" => to_string(log.transaction_hash),
      "transactionIndex" =>
        log.transaction_index
        |> encode_quantity()
    }
  end

  defp render_log(log, transaction) do
    topics = prepare_topics(log)

    %{
      "address" => log.address_hash,
      "blockHash" => log.block_hash,
      "blockNumber" => encode_quantity(log.block_number),
      "data" => log.data,
      "logIndex" => encode_quantity(log.index),
      "removed" => transaction_consensus(transaction) == false,
      "topics" => topics,
      "transactionHash" => log.transaction_hash,
      "transactionIndex" => encode_quantity(transaction.index)
    }
  end

  defp transaction_consensus(transaction) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      transaction.block_consensus
    else
      transaction.block.consensus
    end
  end

  defp prepare_topics(log) do
    Enum.reject(
      [log.first_topic, log.second_topic, log.third_topic, log.fourth_topic],
      &is_nil/1
    )
  end

  defp cast_block("0x" <> hexadecimal_digits = input) do
    case Integer.parse(hexadecimal_digits, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, input <> " is not a valid block number"}
    end
  end

  defp cast_block(integer) when is_integer(integer), do: {:ok, integer}
  defp cast_block(_), do: {:error, "invalid block number"}

  defp address_or_topic_params(filter_options) do
    address_param = Map.get(filter_options, "address")
    topics_param = Map.get(filter_options, "topics")

    with {:ok, address} <- validate_address(address_param),
         {:ok, topics} <- validate_topics(topics_param) do
      address_and_topics(address, topics)
    end
  end

  defp address_and_topics(nil, nil), do: {:error, "Must supply one of address and topics"}
  defp address_and_topics(address, nil), do: {:ok, %{address_hash: address}}
  defp address_and_topics(nil, topics), do: {:ok, topics}
  defp address_and_topics(address, topics), do: {:ok, Map.put(topics, :address_hash, address)}

  defp validate_address(nil), do: {:ok, nil}

  defp validate_address(address) do
    case Address.cast(address) do
      {:ok, address} -> {:ok, address}
      :error -> {:error, "invalid address"}
    end
  end

  defp validate_topics(nil), do: {:ok, nil}
  defp validate_topics([]), do: []

  defp validate_topics(topics) when is_list(topics) do
    topics
    |> Enum.filter(&(!is_nil(&1)))
    |> Stream.with_index()
    |> Enum.reduce({:ok, %{}}, fn {topic, index}, {:ok, acc} ->
      case cast_topics(topic) do
        {:ok, data} ->
          with_filter = Map.put(acc, String.to_existing_atom("#{@index_to_word[index]}_topic"), data)

          {:ok, add_operator(with_filter, index)}

        :error ->
          {:error, "invalid topics"}
      end
    end)
  end

  defp add_operator(filters, 0), do: filters

  defp add_operator(filters, index) do
    Map.put(filters, String.to_existing_atom("topic#{index - 1}_#{index}_opr"), "and")
  end

  defp cast_topics(topics) when is_list(topics) do
    case EctoType.cast({:array, Data}, topics) do
      {:ok, data} -> {:ok, Enum.map(data, &to_string/1)}
      :error -> :error
    end
  end

  defp cast_topics(topic) do
    case Data.cast(topic) do
      {:ok, data} -> {:ok, to_string(data)}
      :error -> :error
    end
  end

  defp logs_blocks_filter(filter_options) do
    with {:filter, %{"blockHash" => block_hash_param}} <- {:filter, filter_options},
         {:block_hash, {:ok, block_hash}} <- {:block_hash, Hash.Full.cast(block_hash_param)},
         {:block, %{number: number}} <- {:block, Repo.replica().get(Block, block_hash)} do
      {:ok, number, number}
    else
      {:filter, filters} ->
        from_block = Map.get(filters, "fromBlock", "latest")
        to_block = Map.get(filters, "toBlock", "latest")

        if from_block == "latest" || to_block == "latest" || from_block == "pending" || to_block == "pending" do
          max_block_number = max_consensus_block_number()

          if is_nil(max_block_number) do
            {:error, :empty}
          else
            to_block_numbers(from_block, to_block, max_block_number)
          end
        else
          to_block_numbers(from_block, to_block, nil)
        end

      {:block, _} ->
        {:error, "Invalid Block Hash"}

      {:block_hash, _} ->
        {:error, "Invalid Block Hash"}
    end
  end

  defp paging_options(%{
         "paging_options" => %{
           "logIndex" => log_index,
           "blockNumber" => block_number
         }
       }) do
    with {:ok, parsed_block_number} <- to_number(block_number, "invalid block number"),
         {:ok, parsed_log_index} <- to_number(log_index, "invalid log index") do
      {:ok,
       %{
         log_index: parsed_log_index,
         block_number: parsed_block_number
       }}
    end
  end

  defp paging_options(_), do: {:ok, nil}

  defp to_block_numbers(from_block, to_block, max_block_number) do
    with {:ok, from} <- to_block_number(from_block, max_block_number),
         {:ok, to} <- to_block_number(to_block, max_block_number) do
      {:ok, from, to}
    end
  end

  defp to_block_number(integer, _) when is_integer(integer), do: {:ok, integer}
  defp to_block_number("latest", max_block_number), do: {:ok, max_block_number || 0}
  defp to_block_number("pending", max_block_number), do: {:ok, max_block_number || 0}
  defp to_block_number("earliest", _), do: {:ok, 0}

  defp to_block_number("0x" <> number, _) do
    case Integer.parse(number, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "invalid block number"}
    end
  end

  defp to_block_number(number, _) when is_bitstring(number) do
    case Integer.parse(number, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "invalid block number"}
    end
  end

  defp to_block_number(_, _), do: {:error, "invalid block number"}

  defp to_number(number, error_message) when is_bitstring(number) do
    case Integer.parse(number, 16) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, error_message}
    end
  end

  defp to_number(_, error_message), do: {:error, error_message}

  defp max_consensus_block_number do
    case Chain.max_consensus_block_number() do
      {:ok, number} -> number
      _ -> nil
    end
  end

  defp format_success(result, id) do
    %{result: result, id: id}
  end

  defp format_error(message, id) do
    %{error: message, id: id}
  end

  defp do_eth_request(%{"jsonrpc" => rpc_version}) when rpc_version != "2.0" do
    {:error, "invalid rpc version"}
  end

  defp do_eth_request(%{"jsonrpc" => "2.0", "method" => method, "params" => params})
       when is_list(params) do
    with {:ok, action} <- get_action(method),
         {:correct_arity, true} <-
           {:correct_arity, :erlang.function_exported(__MODULE__, action, Enum.count(params))} do
      apply(__MODULE__, action, params)
    else
      {:correct_arity, _} ->
        {:error, "Incorrect number of params."}

      _ ->
        {:error, "Action not found."}
    end
  end

  defp do_eth_request(%{"params" => _params, "method" => _}) do
    {:error, "Invalid params. Params must be a list."}
  end

  defp do_eth_request(%{"jsonrpc" => jsonrpc, "method" => method}) do
    do_eth_request(%{"jsonrpc" => jsonrpc, "method" => method, "params" => []})
  end

  defp do_eth_request(_) do
    {:error, "Method, and jsonrpc are required parameters."}
  end

  defp get_action(action) do
    case Map.get(@methods, action) do
      %{action: action} ->
        {:ok, action}

      _ ->
        :error
    end
  end

  defp block_param("latest"), do: {:ok, :latest}
  defp block_param("earliest"), do: {:ok, :earliest}
  defp block_param("pending"), do: {:ok, :pending}

  defp block_param(string_integer) when is_bitstring(string_integer) do
    case Integer.parse(string_integer) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  defp block_param(nil), do: {:ok, :latest}
  defp block_param(_), do: :error

  def encode_quantity(%Decimal{} = decimal), do: encode_quantity(Decimal.to_integer(decimal))

  def encode_quantity(binary) when is_binary(binary) do
    hex_binary = Base.encode16(binary, case: :lower)

    result = String.replace_leading(hex_binary, "0", "")

    final_result = if result == "", do: "0", else: result

    "0x#{final_result}"
  end

  def encode_quantity(value) when is_integer(value) do
    value
    |> :binary.encode_unsigned()
    |> encode_quantity()
  end

  def encode_quantity(value) when is_nil(value) do
    nil
  end

  def methods, do: @methods

  defp chain_id, do: :block_scout_web |> Application.get_env(:chain_id) |> Helper.parse_integer() |> encode_quantity()
end
