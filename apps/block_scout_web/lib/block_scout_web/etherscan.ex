defmodule BlockScoutWeb.Etherscan do
  @moduledoc """
  Documentation data for Etherscan-compatible API.
  """
  use Utils.CompileTimeEnvHelper, bridged_tokens_enabled: [:block_scout_web, [Explorer.Chain.BridgedToken, :enabled]]

  @account_balance_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => "663046792267785498951364"
  }

  @account_balance_example_value_error %{
    "status" => "0",
    "message" => "Invalid address hash",
    "result" => nil
  }

  @account_balancemulti_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "account" => "0xddbd2b932c763ba5b1b7ae3b362eac3e8d40121a",
        "balance" => "40807168566070000000000",
        "stale" => true
      },
      %{
        "account" => "0x63a9975ba31b0b9626b34300f7f627147df1f526",
        "balance" => "332567136222827062478",
        "stale" => false
      },
      %{
        "account" => "0x198ef1ec325a96cc354c7266a038be8b5c558f67",
        "balance" => "185178830000000000",
        "stale" => false
      }
    ]
  }

  @account_pendingtxlist_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "hash" => "0x98beb27135aa0a25650557005ad962919d6a278c4b3dde7f4f6a3a1e65aa746c",
        "nonce" => "0",
        "from" => "0x3fb1cd2cd96c6d5c0b5eb3322d807b34482481d4",
        "to" => "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
        "value" => "0",
        "gas" => "122261",
        "gasPrice" => "50000000000",
        "input" =>
          "0xf00d4b5d000000000000000000000000036c8cecce8d8bbf0831d840d7f29c9e3ddefa63000000000000000000000000c5a96db085dda36ffbe390f455315d30d6d3dc52",
        "contractAddress" => "",
        "cumulativeGasUsed" => "122207",
        "gasUsed" => "122207"
      }
    ]
  }

  @account_txlist_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "blockNumber" => "65204",
        "timeStamp" => "1439232889",
        "hash" => "0x98beb27135aa0a25650557005ad962919d6a278c4b3dde7f4f6a3a1e65aa746c",
        "nonce" => "0",
        "blockHash" => "0x373d339e45a701447367d7b9c7cef84aab79c2b2714271b908cda0ab3ad0849b",
        "transactionIndex" => "0",
        "from" => "0x3fb1cd2cd96c6d5c0b5eb3322d807b34482481d4",
        "to" => "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
        "value" => "0",
        "gas" => "122261",
        "gasPrice" => "50000000000",
        "isError" => "0",
        "txreceipt_status" => "1",
        "input" =>
          "0xf00d4b5d000000000000000000000000036c8cecce8d8bbf0831d840d7f29c9e3ddefa63000000000000000000000000c5a96db085dda36ffbe390f455315d30d6d3dc52",
        "contractAddress" => "",
        "cumulativeGasUsed" => "122207",
        "gasUsed" => "122207",
        "confirmations" => "5994246"
      }
    ]
  }

  @account_txlist_example_value_error %{
    "status" => "0",
    "message" => "No transactions found",
    "result" => []
  }

  @account_txlistinternal_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "blockNumber" => "6153702",
        "timeStamp" => "1534362606",
        "from" => "0x2ca1e3f250f56f1761b9a52bc42db53986085eff",
        "to" => "",
        "value" => "5488334153118633",
        "contractAddress" => "0x883103875d905c11f9ac7dacbfc16deb39655361",
        "transactionHash" => "0xd65b788c610949704a5f9aac2228c7c777434dfe11c863a12306f57fcbd8cdbb",
        "index" => "0",
        "input" => "",
        "type" => "call",
        "callType" => "delegatecall",
        "gas" => "814937",
        "gasUsed" => "536262",
        "isError" => "0",
        "errCode" => ""
      }
    ]
  }

  @account_txlistinternal_example_value_error %{
    "status" => "0",
    "message" => "No internal transactions found",
    "result" => []
  }

  @account_eth_get_balance_example_value %{
    "jsonrpc" => "2.0",
    "result" => "0x0234c8a3397aab58",
    "id" => 1
  }

  @account_tokentx_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "blockNumber" => "5997843",
        "timeStamp" => "1532086946",
        "hash" => "0xd65b788c610949704a5f9aac2228c7c777434dfe11c863a12306f57fcbd8cdbb",
        "nonce" => "765",
        "blockHash" => "0x6169c5dc05d0051564ba3eae8ebfbdefda640c5f5ffc095846b8aed0b44f64ea",
        "from" => "0x4e83362442b8d1bec281594cea3050c8eb01311c",
        "contractAddress" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
        "logIndex" => "0",
        "to" => "0x21e21ba085289f81a86921de890eed30f1ad2375",
        "value" => "10000000000000000000",
        "tokenName" => "Maker",
        "tokenSymbol" => "MKR",
        "tokenDecimal" => "18",
        "transactionIndex" => "27",
        "gas" => "44758",
        "gasPrice" => "7000000000",
        "gasUsed" => "37298",
        "cumulativeGasUsed" => "1043649",
        "input" =>
          "0xa9059cbb00000000000000000000000021e21ba085289f81a86921de890eed30f1ad23750000000000000000000000000000000000000000000000008ac7230489e80000",
        "confirmations" => "199384"
      }
    ]
  }

  @account_tokentx_example_value_error %{
    "status" => "0",
    "message" => "No token transfers found",
    "result" => []
  }

  @account_tokenbalance_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => "135499"
  }

  @account_tokenbalance_example_value_error %{
    "status" => "0",
    "message" => "Invalid address format",
    "result" => nil
  }

  @account_tokenlist_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "balance" => "135499",
        "contractAddress" => "0x0000000000000000000000000000000000000000",
        "name" => "Example Token",
        "decimals" => "18",
        "symbol" => "ET",
        "type" => "ERC-20"
      },
      %{
        "balance" => "1",
        "contractAddress" => "0x0000000000000000000000000000000000000001",
        "name" => "Example ERC-721 Token",
        "decimals" => "18",
        "symbol" => "ET7",
        "type" => "ERC-721"
      }
    ]
  }

  @account_getminedblocks_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "blockNumber" => "3462296",
        "timeStamp" => "1491118514",
        "blockReward" => "5194770940000000000"
      }
    ]
  }

  @account_listaccounts_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "address" => "0x0000000000000000000000000000000000000000",
        "balance" => "135499"
      }
    ]
  }

  @account_getminedblocks_example_value_error %{
    "status" => "0",
    "message" => "No blocks found",
    "result" => []
  }

  @logs_getlogs_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "address" => "0x33990122638b9132ca29c723bdf037f1a891a70c",
        "topics" => [
          "0xf63780e752c6a54a94fc52715dbc5518a3b4c3c2833d301a204226548a2a8545",
          "0x72657075746174696f6e00000000000000000000000000000000000000000000",
          "0x000000000000000000000000d9b2f59f3b5c7b3c67047d2f03c3e8052470be92"
        ],
        "data" => "0x",
        "blockNumber" => "0x5c958",
        "timeStamp" => "0x561d688c",
        "gasPrice" => "0xba43b7400",
        "gasUsed" => "0x10682",
        "logIndex" => "0x",
        "transactionHash" => "0x0b03498648ae2da924f961dda00dc6bb0a8df15519262b7e012b7d67f4bb7e83",
        "transactionIndex" => "0x"
      }
    ]
  }

  @logs_getlogs_example_value_error %{
    "status" => "0",
    "message" => "Invalid address format",
    "result" => nil
  }

  @token_gettoken_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "cataloged" => true,
      "contractAddress" => "0x0000000000000000000000000000000000000000",
      "decimals" => "18",
      "name" => "Example Token",
      "symbol" => "ET",
      "totalSupply" => "1000000000",
      "type" => "ERC-20"
    }
  }

  @token_gettoken_example_value_error %{
    "status" => "0",
    "message" => "Invalid contract address format",
    "result" => nil
  }

  @token_gettokenholders_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "address" => "0x0000000000000000000000000000000000000000",
        "value" => "965208500001258757122850"
      }
    ]
  }

  @token_gettokenholders_example_value_error %{
    "status" => "0",
    "message" => "Invalid contract address format",
    "result" => nil
  }

  @stats_tokensupply_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => "21265524714464"
  }

  @stats_ethsupplyexchange_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => "101959776311500000000000000"
  }

  @stats_ethsupply_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => "101959776311500000000000000"
  }

  @stats_coinsupply_example_value 101_959_776.3115

  @stats_coinprice_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "coin_btc" => "0.03246",
      "coin_btc_timestamp" => "1537212510",
      "coin_usd" => "204",
      "coin_usd_timestamp" => "1537212513"
    }
  }

  @stats_totalfees_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "total_fees" => "75411956011480008034"
    }
  }

  @stats_totalfees_example_value_error %{
    "status" => "0",
    "message" => "An incorrect input date provided. It should be in ISO 8601 format (yyyy-mm-dd).",
    "result" => nil
  }

  @block_getblockreward_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "blockNumber" => "2165403",
      "timeStamp" => "1472533979",
      "blockMiner" => "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3",
      "blockReward" => "5314181600000000000",
      "uncles" => nil,
      "uncleInclusionReward" => nil
    }
  }

  @block_getblockreward_example_value_error %{
    "status" => "0",
    "message" => "Invalid block number",
    "result" => nil
  }

  @block_getblocknobytime_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "blockNumber" => "2165403"
    }
  }

  @block_getblocknobytime_example_value_error %{
    "status" => "0",
    "message" => "Invalid params",
    "result" => nil
  }

  @block_eth_block_number_example_value %{
    "jsonrpc" => "2.0",
    "result" => "0xb33bf1",
    "id" => 1
  }

  @contract_listcontracts_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => [
      %{
        "SourceCode" => """
        pragma solidity >0.4.24;

        contract Test {
        constructor() public { b = hex"12345678901234567890123456789012"; }
        event Event(uint indexed a, bytes32 b);
        event Event2(uint indexed a, bytes32 b);
        function foo(uint a) public { emit Event(a, b); }
        bytes32 b;
        }
        """,
        "ABI" => """
        [{
        "type":"event",
        "inputs": [{"name":"a","type":"uint256","indexed":true},{"name":"b","type":"bytes32","indexed":false}],
        "name":"Event"
        }, {
        "type":"event",
        "inputs": [{"name":"a","type":"uint256","indexed":true},{"name":"b","type":"bytes32","indexed":false}],
        "name":"Event2"
        }, {
        "type":"function",
        "inputs": [{"name":"a","type":"uint256"}],
        "name":"foo",
        "outputs": []
        }]
        """,
        "ContractName" => "Test",
        "CompilerVersion" => "v0.2.1-2016-01-30-91a6b35",
        "OptimizationUsed" => "1"
      }
    ]
  }

  @contract_getabi_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" =>
      ~s([{"constant":false,"inputs":[{"name":"voucher_token","type":"bytes32"}],"name":"burn","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"voucher_token","type":"bytes32"}],"name":"is_expired","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"voucher_token","type":"bytes32"}],"name":"is_burnt","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"inputs":[{"name":"voucher_token","type":"bytes32"},{"name":"_lifetime","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"}])
  }

  @contract_getabi_example_value_error %{
    "status" => "0",
    "message" => "Contract source code not verified",
    "result" => nil
  }

  @contract_verify_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "SourceCode" => """
      pragma solidity >0.4.24;

      contract Test {
      constructor() public { b = hex"12345678901234567890123456789012"; }
      event Event(uint indexed a, bytes32 b);
      event Event2(uint indexed a, bytes32 b);
      function foo(uint a) public { emit Event(a, b); }
      bytes32 b;
      }
      """,
      "ABI" => """
      [{
      "type":"event",
      "inputs": [{"name":"a","type":"uint256","indexed":true},{"name":"b","type":"bytes32","indexed":false}],
      "name":"Event"
      }, {
      "type":"event",
      "inputs": [{"name":"a","type":"uint256","indexed":true},{"name":"b","type":"bytes32","indexed":false}],
      "name":"Event2"
      }, {
      "type":"function",
      "inputs": [{"name":"a","type":"uint256"}],
      "name":"foo",
      "outputs": []
      }]
      """,
      "ContractName" => "Test",
      "CompilerVersion" => "v0.2.1-2016-01-30-91a6b35",
      "OptimizationUsed" => "1",
      "IsProxy" => "true",
      "ImplementationAddress" => "0x000000000000000000000000000000000000000e"
    }
  }

  @contract_verify_example_value_error %{
    "status" => "0",
    "message" => "There was an error verifying the contract.",
    "result" => nil
  }

  @contract_verifysourcecode_example_value %{
    "message" => "OK",
    "result" => "b080b96bd06ad1c9341c2afb7e3730311388544961acde94",
    "status" => "1"
  }

  @contract_checkverifystatus_example_value %{
    "message" => "OK",
    "result" => "Pending in queue",
    "status" => "1"
  }

  @contract_getsourcecode_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "SourceCode" => """
      pragma solidity >0.4.24;

      contract Test {
      constructor() public { b = hex"12345678901234567890123456789012"; }
      event Event(uint indexed a, bytes32 b);
      event Event2(uint indexed a, bytes32 b);
      function foo(uint a) public { emit Event(a, b); }
      bytes32 b;
      }
      """,
      "ABI" => """
      [{
      "type":"event",
      "inputs": [{"name":"a","type":"uint256","indexed":true},{"name":"b","type":"bytes32","indexed":false}],
      "name":"Event"
      }, {
      "type":"event",
      "inputs": [{"name":"a","type":"uint256","indexed":true},{"name":"b","type":"bytes32","indexed":false}],
      "name":"Event2"
      }, {
      "type":"function",
      "inputs": [{"name":"a","type":"uint256"}],
      "name":"foo",
      "outputs": []
      }]
      """,
      "ContractName" => "Test",
      "CompilerVersion" => "v0.2.1-2016-01-30-91a6b35",
      "OptimizationUsed" => "1",
      "FileName" => "{sourcify path or empty}",
      "IsProxy" => "true",
      "ImplementationAddress" => "0x000000000000000000000000000000000000000e"
    }
  }

  @contract_getsourcecode_example_value_error %{
    "status" => "0",
    "message" => "Invalid address hash",
    "result" => nil
  }

  @transaction_gettxinfo_example_value %{
    "status" => "1",
    "result" => %{
      "blockNumber" => "3",
      "confirmations" => "0",
      "from" => "0x000000000000000000000000000000000000000c",
      "gasLimit" => "91966",
      "gasUsed" => "95123",
      "gasPrice" => "100000",
      "hash" => "0x0000000000000000000000000000000000000000000000000000000000000004",
      "input" => "0x04",
      "logs" => [
        %{
          "address" => "0x000000000000000000000000000000000000000e",
          "data" => "0x00",
          "topics" => ["First Topic", "Second Topic", "Third Topic", "Fourth Topic"]
        }
      ],
      "success" => true,
      "timeStamp" => "1541018182",
      "to" => "0x000000000000000000000000000000000000000d",
      "value" => "67612",
      revertReason: "No credit of that type"
    }
  }

  @transaction_gettxreceiptstatus_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "status" => "1"
    }
  }

  @transaction_gettxreceiptstatus_example_value_error %{
    "status" => "0",
    "message" => "Query parameter txhash is required",
    "result" => nil
  }

  @transaction_getstatus_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => %{
      "isError" => "1",
      "errDescription" => "Out of gas"
    }
  }

  @transaction_getstatus_example_value_error %{
    "status" => "0",
    "message" => "Query parameter txhash is required",
    "result" => nil
  }

  @status_type %{
    type: "status",
    enum: ~s(["0", "1"]),
    enum_interpretation: %{"0" => "error", "1" => "ok"}
  }

  @jsonrpc_version_type %{
    type: "string",
    example: ~s("2.0")
  }

  @message_type %{
    type: "string",
    example: ~s("OK")
  }

  @hex_number_type %{
    type: "string",
    example: ~s("767969")
  }

  @id_type %{
    type: "string",
    example: ~s("1")
  }

  @wei_type %{
    type: "wei",
    definition: &__MODULE__.wei_type_definition/1,
    example: ~s("663046792267785498951364")
  }

  @gas_type %{
    type: "gas",
    definition: "A nonnegative number roughly equivalent to computational steps.",
    example: ~s("122261")
  }

  @address_hash_type %{
    type: "address hash",
    definition: "A 160-bit code used for identifying accounts or contracts.",
    example: ~s("0x95426f2bc716022fcf1def006dbc4bb81f5b5164")
  }

  @stale_type %{
    type: "boolean",
    definition:
      "Represents whether or not the balance has not been checked in the last 24 hours, and will be rechecked.",
    example: true
  }

  @transaction_hash_type %{
    type: "transaction hash",
    definition:
      "Either a 20-byte address hash or, in the case of being a contract creation transaction, it is the RLP empty byte sequence. Used for identifying transactions.",
    example: ~s("0x9c81f44c29ff0226f835cd0a8a2f2a7eca6db52a711f8211b566fd15d3e0e8d4")
  }

  @block_number_type %{
    type: "block number",
    definition: "A nonnegative number used to identify blocks.",
    example: ~s("34092")
  }

  @input_type %{
    type: "input",
    definition: "Data sent along with the transaction. A variable-byte-length binary.",
    example: ~s("0x797af627d02e23b68e085092cd0d47d6cfb54be025f37b5989c0264398f534c08af7dea9")
  }

  @confirmation_type %{
    type: "confirmations",
    definition: "A number equal to the current block height minus the transaction's block-number.",
    example: ~s("6005998")
  }

  @transaction_index_type %{
    type: "transaction index",
    definition: "Index of the transaction in it's block.",
    example: ~s("0")
  }

  @token_name_type %{
    type: "string",
    definition: "Name of the token.",
    example: ~s("Some Token Name")
  }

  @token_id_type %{
    name: "Token ID",
    type: "integer",
    definition: "id of token",
    example: ~s("0")
  }

  @token_symbol_type %{
    type: "string",
    definition: "Trading symbol of the token.",
    example: ~s("SYMBOL")
  }

  @token_decimal_type %{
    type: "integer",
    definition: "Number of decimal places the token can be subdivided to.",
    example: ~s("18")
  }

  @revert_reason_type %{
    type: "revert_reason",
    definition: "Revert reason of transaction.",
    example: ~s("No credit of that type")
  }

  @logs_details %{
    name: "Log Detail",
    fields: %{
      address: @address_hash_type,
      topics: %{
        type: "topics",
        definition: "An array including the topics for the log.",
        example: ~s(["0xf63780e752c6a54a94fc52715dbc5518a3b4c3c2833d301a204226548a2a8545"])
      },
      data: %{
        type: "data",
        definition: "Non-indexed log parameters.",
        example: ~s("0x")
      },
      blockNumber: %{
        type: "block number",
        definition: "A nonnegative number used to identify blocks.",
        example: ~s("0x5c958")
      },
      index: %{
        type: "log index",
        definition: "A nonnegative number used to identify logs.",
        example: ~s("1")
      }
    }
  }

  @token_holder_details %{
    name: "Token holder Detail",
    fields: %{
      address: @address_hash_type,
      value: %{
        type: "value",
        definition: "A nonnegative number used to identify the balance of the target token.",
        example: ~s("1000000000000000000")
      }
    }
  }

  @address_balance %{
    name: "AddressBalance",
    fields: %{
      address: @address_hash_type,
      balance: @wei_type,
      stale: @stale_type
    }
  }

  @transaction %{
    name: "Transaction",
    fields: %{
      blockNumber: @block_number_type,
      timeStamp: %{
        type: "timestamp",
        definition: "The transaction's block-timestamp.",
        example: ~s("1439232889")
      },
      hash: @transaction_hash_type,
      nonce: %{
        type: "nonce",
        definition: "A scalar value equal to the number of transactions sent by the sender prior to this transaction.",
        example: ~s("0")
      },
      blockHash: %{
        type: "block hash",
        definition: "A 32-byte hash used for identifying blocks.",
        example: ~s("0xd3cabad6adab0b52eb632c386ea194036805713682c62cb589b5abcd76de2159")
      },
      transactionIndex: @transaction_index_type,
      from: @address_hash_type,
      to: @address_hash_type,
      value: @wei_type,
      gas: @gas_type,
      gasPrice: @wei_type,
      isError: %{
        type: "error",
        enum: ~s(["0", "1"]),
        enum_interpretation: %{"0" => "ok", "1" => "error"}
      },
      txreceipt_status: @status_type,
      input: @input_type,
      contractAddress: @address_hash_type,
      cumulativeGasUsed: @gas_type,
      gasUsed: @gas_type,
      confirmations: @confirmation_type
    }
  }

  @internal_transaction %{
    name: "InternalTransaction",
    fields: %{
      blockNumber: @block_number_type,
      timeStamp: %{
        type: "timestamp",
        definition: "The transaction's block-timestamp.",
        example: ~s("1439232889")
      },
      from: @address_hash_type,
      to: @address_hash_type,
      value: @wei_type,
      contractAddress: @address_hash_type,
      input: @input_type,
      type: %{
        type: "type",
        definition: ~s(Possible values: "create", "call", "reward", or "selfdestruct"),
        example: ~s("create")
      },
      callType: %{
        type: "type",
        definition: ~s(Possible values: "call", "callcode", "delegatecall", or "staticcall"),
        example: ~s("delegatecall")
      },
      gas: @gas_type,
      gasUsed: @gas_type,
      isError: %{
        type: "error",
        enum: ~s(["0", "1"]),
        enum_interpretation: %{"0" => "ok", "1" => "rejected/cancelled"}
      },
      errCode: %{
        type: "string",
        definition: "Error message when call type error.",
        example: ~s("Out of gas")
      }
    }
  }

  @block_model %{
    name: "Block",
    fields: %{
      blockNumber: @block_number_type,
      timeStamp: %{
        type: "timestamp",
        definition: "When the block was collated.",
        example: ~s("1480072029")
      }
    }
  }

  @token_transfer_model %{
    name: "TokenTransfer",
    fields: %{
      blockNumber: @block_number_type,
      timeStamp: %{
        type: "timestamp",
        definition: "The transaction's block-timestamp.",
        example: ~s("1439232889")
      },
      hash: @transaction_hash_type,
      nonce: %{
        type: "nonce",
        definition: "A scalar value equal to the number of transactions sent by the sender prior to this transaction.",
        example: ~s("0")
      },
      blockHash: %{
        type: "block hash",
        definition: "A 32-byte hash used for identifying blocks.",
        example: ~s("0xd3cabad6adab0b52eb632c386ea194036805713682c62cb589b5abcd76de2159")
      },
      from: @address_hash_type,
      contractAddress: @address_hash_type,
      to: @address_hash_type,
      value: %{
        type: "integer",
        definition: "The transferred amount.",
        example: ~s("663046792267785498951364")
      },
      values: %{
        type: "array",
        array_type: %{
          name: "Transferred amount",
          type: "integer",
          definition: "The transferred amount of particular token instance."
        },
        definition: "Transferred amounts of token instances in ERC-1155 batch transfer corresponding to tokenIDs field."
      },
      tokenName: @token_name_type,
      tokenID: @token_id_type,
      tokenIDs: %{
        type: "array",
        array_type: @token_id_type
      },
      tokenSymbol: @token_symbol_type,
      tokenDecimal: @token_decimal_type,
      transactionIndex: @transaction_index_type,
      gas: @gas_type,
      gasPrice: @wei_type,
      gasUsed: @gas_type,
      cumulativeGasUsed: @gas_type,
      input: @input_type,
      confirmations: @confirmation_type
    }
  }

  @log %{
    name: "Log",
    fields: %{
      address: @address_hash_type,
      topics: %{
        type: "topics",
        definition: "An array including the topics for the log.",
        example: ~s(["0xf63780e752c6a54a94fc52715dbc5518a3b4c3c2833d301a204226548a2a8545"])
      },
      data: %{
        type: "data",
        definition: "Non-indexed log parameters.",
        example: ~s("0x")
      },
      blockNumber: %{
        type: "block number",
        definition: "A nonnegative number used to identify blocks.",
        example: ~s("0x5c958")
      },
      timeStamp: %{
        type: "timestamp",
        definition: "The transaction's block-timestamp.",
        example: ~s("0x561d688c")
      },
      gasPrice: %{
        type: "wei",
        definition: &__MODULE__.wei_type_definition/1,
        example: ~s("0xba43b7400")
      },
      gasUsed: %{
        type: "gas",
        definition: "A nonnegative number roughly equivalent to computational steps.",
        example: ~s("0x10682")
      },
      logIndex: %{
        type: "hexadecimal",
        example: ~s("0x")
      },
      transactionHash: @transaction_hash_type,
      transactionIndex: %{
        type: "hexadecimal",
        example: ~s("0x")
      }
    }
  }

  @token_model %{
    name: "Token",
    fields: %{
      name: @token_name_type,
      symbol: @token_symbol_type,
      totalSupply: %{
        type: "integer",
        definition: "The total supply of the token.",
        example: ~s("1000000000")
      },
      decimals: @token_decimal_type,
      type: %{
        type: "token type",
        enum: ~s(["ERC-20", "ERC-721"]),
        enum_interpretation: %{"ERC-20" => "ERC-20 token standard", "ERC-721" => "ERC-721 token standard"}
      },
      cataloged: %{
        type: "boolean",
        definition: "Flag for if token information has been cataloged.",
        example: ~s(true)
      },
      contractAddress: @address_hash_type
    }
  }

  @token_balance_model %{
    name: "TokenBalance",
    fields: %{
      balance: %{
        type: "integer",
        definition: "The token account balance.",
        example: ~s("135499")
      },
      name: @token_name_type,
      symbol: @token_symbol_type,
      decimals: @token_decimal_type,
      contractAddress: @address_hash_type
    }
  }

  @block_reward_model %{
    name: "BlockReward",
    fields: %{
      blockNumber: @block_number_type,
      timeStamp: %{
        type: "timestamp",
        definition: "When the block was collated.",
        example: ~s("1480072029")
      },
      blockMiner: @address_hash_type,
      blockReward: %{
        type: "block reward",
        definition: "The reward given to the miner of a block.",
        example: ~s("5003251945421042780")
      },
      uncles: %{type: "null"},
      uncleInclusionReward: %{type: "null"}
    }
  }

  @block_no_model %{
    name: "BlockNo",
    fields: %{
      blockNumber: @block_number_type
    }
  }

  @account_model %{
    name: "Account",
    fields: %{
      "address" => @address_hash_type,
      "balance" => @wei_type
    }
  }

  @contract_model %{
    name: "Contract",
    fields: %{
      "Address" => @address_hash_type,
      "ABI" => %{
        type: "ABI",
        definition: "JSON string for the contract's Application Binary Interface (ABI)",
        example: """
        "[{
        \\"type\\":\\"event\\",
        \\"inputs\\": [{\\"name\\":\\"a\\",\\"type\\":\\"uint256\\",\\"indexed\\":true},{\\"name\\":\\"b\\",\\"type\\":\\"bytes32\\",\\"indexed\\":false}],
        \\"name\\":\\"Event\\"
        }, {
        \\"type\\":\\"event\\",
        \\"inputs\\": [{\\"name\\":\\"a\\",\\"type\\":\\"uint256\\",\\"indexed\\":true},{\\"name\\":\\"b\\",\\"type\\":\\"bytes32\\",\\"indexed\\":false}],
        \\"name\\":\\"Event2\\"
        }, {
        \\"type\\":\\"function\\",
        \\"inputs\\": [{\\"name\\":\\"a\\",\\"type\\":\\"uint256\\"}],
        \\"name\\":\\"foo\\",
        \\"outputs\\": []
        }]"
        """
      },
      "ContractName" => %{
        type: "string",
        example: ~S("Some name")
      },
      "OptimizationUsed" => %{
        type: "optimization used",
        enum: ~s(["0", "1"]),
        enum_interpretation: %{"0" => "false", "1" => "true"}
      }
    }
  }

  @uid_response_model %{
    name: "UID",
    fields: %{
      "UID" => %{
        type: "string",
        definition: "Unique identifier of the verification attempt",
        example: "b080b96bd06ad1c9341c2afb7e3730311388544961acde94"
      }
    }
  }

  @status_response_model %{
    name: "Status",
    fields: %{
      "status" => %{
        type: "string",
        definition: "Current status of the verification attempt",
        example: "`Pending in queue` | `Pass - Verified` | `Fail - Unable to verify` | `Unknown UID`"
      }
    }
  }

  @contract_source_code_type %{
    type: "contract source code",
    definition: "The contract's source code.",
    example: """
    "pragma solidity >0.4.24;

    contract Test {
      constructor() public { b = hex"12345678901234567890123456789012"; }
      event Event(uint indexed a, bytes32 b);
      event Event2(uint indexed a, bytes32 b);
      function foo(uint a) public { emit Event(a, b); }
      bytes32 b;
    }"
    """
  }

  @contract_with_sourcecode_model @contract_model
                                  |> put_in([:fields, "SourceCode"], @contract_source_code_type)

  @transaction_receipt_status_model %{
    name: "TransactionReceiptStatus",
    fields: %{
      status: %{
        type: "status",
        enum: ~s(["0", "1"]),
        enum_interpretation: %{"0" => "fail", "1" => "pass"}
      }
    }
  }

  @transaction_info_model %{
    name: "TransactionInfo",
    fields: %{
      hash: @transaction_hash_type,
      timeStamp: %{
        type: "timestamp",
        definition: "The transaction's block-timestamp.",
        example: ~s("1439232889")
      },
      blockNumber: @block_number_type,
      confirmations: @confirmation_type,
      success: %{
        type: "boolean",
        definition: "Flag for success during transaction execution",
        example: ~s(true)
      },
      from: @address_hash_type,
      to: @address_hash_type,
      value: @wei_type,
      input: @input_type,
      gasLimit: @wei_type,
      gasUsed: @gas_type,
      gasPrice: @wei_type,
      logs: %{
        type: "array",
        array_type: @logs_details
      },
      revertReason: @revert_reason_type
    }
  }

  @transaction_status_model %{
    name: "TransactionStatus",
    fields: %{
      isError: %{
        type: "isError",
        enum: ~s(["0", "1"]),
        enum_interpretation: %{"0" => "pass", "1" => "error"}
      },
      errDescription: %{
        type: "string",
        example: ~s("Out of gas")
      }
    }
  }

  @coin_price_model %{
    name: "CoinPrice",
    fields: %{
      coin_btc: %{
        type: "coin_btc",
        definition: &__MODULE__.coin_btc_type_definition/1,
        example: ~s("0.03161")
      },
      coin_btc_timestamp: %{
        type: "timestamp",
        definition: "Last updated timestamp.",
        example: ~s("1537234460")
      },
      coin_usd: %{
        type: "coin_usd",
        definition: &__MODULE__.coin_usd_type_definition/1,
        example: ~s("197.57")
      },
      coin_usd_timestamp: %{
        type: "timestamp",
        definition: "Last updated timestamp.",
        example: ~s("1537234460")
      }
    }
  }

  @total_fees_model %{
    name: "TotalFees",
    fields: %{
      total_fees: %{
        type: "total_fees",
        definition: "Total transaction fees in Wei are paid by users to validators per day.",
        example: ~s("75411956011480008034")
      }
    }
  }

  @account_eth_get_balance_action %{
    name: "eth_get_balance",
    description:
      "Mimics Ethereum JSON RPC's eth_getBalance. Returns the balance as of the provided block (defaults to latest)",
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "The address of the account."
      }
    ],
    optional_params: [
      %{
        key: "block",
        placeholder: "block",
        type: "string",
        description: """
        Either the block number as a string, or one of latest, earliest or pending

        latest will be the latest balance in a *consensus* block.
        earliest will be the first recorded balance for the address.
        pending will be the latest balance in consensus *or* nonconsensus blocks.
        """
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_eth_get_balance_example_value),
        model: %{
          name: "Result",
          fields: %{
            jsonrpc: @jsonrpc_version_type,
            id: @id_type,
            result: @hex_number_type
          }
        }
      }
    ]
  }

  @account_balance_action %{
    name: "balance",
    description: """
        Get balance for address. Also available through a GraphQL 'addresses' query.

        If the balance hasn't been updated in a long time, we will double check
        with the node to fetch the absolute latest balance. This will not be
        reflected in the current request, but once it is updated, subsequent requests
        will show the updated balance. If you want to know whether or not we are checking
        for another balance, use the `balancemulti` action. That contains a property
        called `stale` that will let you know to recheck that balance in the near future.
    """,
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying Accounts."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_balance_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: @wei_type
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_balance_example_value_error)
      }
    ]
  }

  @account_balancemulti_action %{
    name: "balancemulti",
    description: """
        Get balance for multiple addresses. Also available through a GraphQL 'addresses' query.

        If the balance hasn't been updated in a long time, we will double check
        with the node to fetch the absolute latest balance. This will not be
        reflected in the current request, but once it is updated, subsequent requests
        will show the updated balance. You can know that this is taking place via
        the `stale` attribute, which is set to `true` if a new balance is being fetched.
    """,
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash1,addressHash2,addressHash3",
        type: "string",
        description:
          "A 160-bit code used for identifying Accounts. Separate addresses by comma. Maximum of 20 addresses."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_balancemulti_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @address_balance
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_balance_example_value_error)
      }
    ]
  }

  @account_pendingtxlist_action %{
    name: "pendingtxlist",
    description: "Get pending transactions by address.",
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying Accounts."
      }
    ],
    optional_params: [
      %{
        key: "page",
        type: "integer",
        description:
          "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction."
      },
      %{
        key: "offset",
        type: "integer",
        description:
          "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_pendingtxlist_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @transaction
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_txlist_example_value_error)
      }
    ]
  }

  @account_txlist_action %{
    name: "txlist",
    description:
      "Get transactions by address. Up to a maximum of 10,000 transactions. Also available through a GraphQL 'address' query.",
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying Accounts."
      }
    ],
    optional_params: [
      %{
        key: "sort",
        type: "string",
        description:
          "A string representing the order by block number direction. Defaults to descending order. Available values: asc, desc"
      },
      %{
        key: "startblock",
        type: "integer",
        description: "A nonnegative integer that represents the starting block number."
      },
      %{
        key: "endblock",
        type: "integer",
        description: "A nonnegative integer that represents the ending block number."
      },
      %{
        key: "page",
        type: "integer",
        description:
          "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction."
      },
      %{
        key: "offset",
        type: "integer",
        description:
          "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction."
      },
      %{
        key: "filter_by",
        type: "string",
        description: """
        A string representing the field to filter by. If none is given
        it returns transactions that match to, from, or contract address.
        Available values: to, from
        """
      },
      %{
        key: "start_timestamp",
        type: "unix timestamp",
        description: "Represents the starting block timestamp."
      },
      %{
        key: "end_timestamp",
        type: "unix timestamp",
        description: "Represents the ending block timestamp."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_txlist_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @transaction
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_txlist_example_value_error)
      }
    ]
  }

  @account_txlistinternal_action %{
    name: "txlistinternal",
    description:
      "Get internal transactions by transaction or address hash. Up to a maximum of 10,000 internal transactions. Also available through a GraphQL 'transaction' query.",
    required_params: [],
    optional_params: [
      %{
        key: "txhash",
        placeholder: "transactionHash",
        type: "string",
        description:
          "Transaction hash. Hash of contents of the transaction. Optional parameter to filter results by a specific transaction hash."
      },
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying accounts. An address hash or transaction hash is required."
      },
      %{
        key: "sort",
        type: "string",
        description:
          "A string representing the order by block number direction. Defaults to ascending order. Available values: asc, desc. WARNING: Only available if 'address' is provided."
      },
      %{
        key: "startblock",
        type: "integer",
        description:
          "A nonnegative integer that represents the starting block number. WARNING: Only available if 'address' is provided."
      },
      %{
        key: "endblock",
        type: "integer",
        description:
          "A nonnegative integer that represents the ending block number. WARNING: Only available if 'address' is provided."
      },
      %{
        key: "page",
        type: "integer",
        description:
          "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction. WARNING: Only available if 'address' is provided."
      },
      %{
        key: "offset",
        type: "integer",
        description:
          "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction. WARNING: Only available if 'address' is provided."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_txlistinternal_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @internal_transaction
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_txlistinternal_example_value_error)
      }
    ]
  }

  @account_tokentx_action %{
    name: "tokentx",
    description:
      "Get token transfer events by address. Up to a maximum of 10,000 token transfer events. Also available through a GraphQL 'token_transfers' query.",
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying accounts."
      }
    ],
    optional_params: [
      %{
        key: "contractaddress",
        placeholder: "contractAddressHash",
        type: "string",
        description: "A 160-bit code used for identifying contracts."
      },
      %{
        key: "sort",
        type: "string",
        description:
          "A string representing the order by block number direction. Defaults to ascending order. Available values: asc, desc"
      },
      %{
        key: "startblock",
        type: "integer",
        description: "A nonnegative integer that represents the starting block number."
      },
      %{
        key: "endblock",
        type: "integer",
        description: "A nonnegative integer that represents the ending block number."
      },
      %{
        key: "page",
        type: "integer",
        description:
          "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction."
      },
      %{
        key: "offset",
        type: "integer",
        description:
          "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_tokentx_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @token_transfer_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_tokentx_example_value_error)
      }
    ]
  }

  @account_tokenbalance_action %{
    name: "tokenbalance",
    description: "Get token account balance for token contract address.",
    required_params: [
      %{
        key: "contractaddress",
        placeholder: "contractAddressHash",
        type: "string",
        description: "A 160-bit code used for identifying contracts."
      },
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying accounts."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_tokenbalance_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "integer",
              definition: "The token account balance for the contract address.",
              example: ~s("135499")
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_tokenbalance_example_value_error)
      }
    ]
  }

  @account_tokenlist_action %{
    name: "tokenlist",
    description: "Get list of tokens owned by address.",
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying accounts."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_tokenlist_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @token_balance_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_tokenbalance_example_value_error)
      }
    ]
  }

  @account_getminedblocks_action %{
    name: "getminedblocks",
    description: "Get list of blocks mined by address.",
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying accounts."
      }
    ],
    optional_params: [
      %{
        key: "page",
        type: "integer",
        description:
          "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction."
      },
      %{
        key: "offset",
        type: "integer",
        description:
          "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_getminedblocks_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @block_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@account_getminedblocks_example_value_error)
      }
    ]
  }

  @account_listaccounts_action %{
    name: "listaccounts",
    description:
      "Get a list of accounts and their balances, sorted ascending by the time they were first seen by the explorer.",
    required_params: [],
    optional_params: [
      %{
        key: "page",
        type: "integer",
        description:
          "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction."
      },
      %{
        key: "offset",
        type: "integer",
        description:
          "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@account_listaccounts_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @account_model
            }
          }
        }
      }
    ]
  }

  @logs_getlogs_action %{
    name: "getLogs",
    description: "Get event logs for an address and/or topics. Up to a maximum of 1,000 event logs.",
    required_params: [
      %{
        key: "fromBlock",
        placeholder: "blockNumber",
        type: "integer",
        description:
          "A nonnegative integer that represents the starting block number. The use of 'latest' is also supported."
      },
      %{
        key: "toBlock",
        placeholder: "blockNumber",
        type: "integer",
        description:
          "A nonnegative integer that represents the ending block number. The use of 'latest' is also supported."
      },
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying contracts. An address and/or topic{x} is required."
      },
      %{
        key: "topic0",
        placeholder: "firstTopic",
        type: "string",
        description: "A string equal to the first topic. A topic{x} and/or address is required."
      }
    ],
    optional_params: [
      %{
        key: "topic1",
        type: "string",
        description: "A string equal to the second topic. A topic{x} and/or address is required."
      },
      %{
        key: "topic2",
        type: "string",
        description: "A string equal to the third topic. A topic{x} and/or address is required."
      },
      %{
        key: "topic3",
        type: "string",
        description: "A string equal to the fourth topic. A topic{x} and/or address is required."
      },
      %{
        key: "topic0_1_opr",
        type: "string",
        description:
          "A string representing the and|or operator for topic0 and topic1. " <>
            "Required if topic0 and topic1 is used. Available values: and, or"
      },
      %{
        key: "topic0_2_opr",
        type: "string",
        description:
          "A string representing the and|or operator for topic0 and topic2. " <>
            "Required if topic0 and topic2 is used. Available values: and, or"
      },
      %{
        key: "topic0_3_opr",
        type: "string",
        description:
          "A string representing the and|or operator for topic0 and topic3. " <>
            "Required if topic0 and topic3 is used. Available values: and, or"
      },
      %{
        key: "topic1_2_opr",
        type: "string",
        description:
          "A string representing the and|or operator for topic1 and topic2. " <>
            "Required if topic1 and topic2 is used. Available values: and, or"
      },
      %{
        key: "topic1_3_opr",
        type: "string",
        description:
          "A string representing the and|or operator for topic1 and topic3. " <>
            "Required if topic1 and topic3 is used. Available values: and, or"
      },
      %{
        key: "topic2_3_opr",
        type: "string",
        description:
          "A string representing the and|or operator for topic2 and topic3. " <>
            "Required if topic2 and topic3 is used. Available values: and, or"
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@logs_getlogs_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @log
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@logs_getlogs_example_value_error)
      }
    ]
  }

  @token_gettoken_action %{
    name: "getToken",
    description:
      "Get <a href='https://github.com/ethereum/EIPs/issues/20'>ERC-20</a> " <>
        "or <a href='https://github.com/ethereum/EIPs/issues/721'>ERC-721</a> token by contract address.",
    required_params: [
      %{
        key: "contractaddress",
        placeholder: "contractAddressHash",
        type: "string",
        description: "A 160-bit code used for identifying contracts."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@token_gettoken_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "model",
              model: @token_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@token_gettoken_example_value_error)
      }
    ]
  }

  @token_gettokenholders_action %{
    name: "getTokenHolders",
    description: "Get token holders by contract address.",
    required_params: [
      %{
        key: "contractaddress",
        placeholder: "contractAddressHash",
        type: "string",
        description: "A 160-bit code used for identifying contracts."
      }
    ],
    optional_params: [
      %{
        key: "page",
        type: "integer",
        description:
          "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction."
      },
      %{
        key: "offset",
        type: "integer",
        description:
          "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@token_gettokenholders_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @token_holder_details
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@token_gettokenholders_example_value_error)
      }
    ]
  }

  if @bridged_tokens_enabled do
    @success_status_type %{
      type: "status",
      enum: ~s(["1"]),
      enum_interpretation: %{"1" => "ok"}
    }

    @bridged_token_details %{
      name: "Bridged Token Detail",
      fields: %{
        foreignChainId: %{
          type: "value",
          definition: "Chain ID of the chain where original token exists.",
          example: ~s("1")
        },
        foreignTokenContractAddressHash: @address_hash_type,
        homeContractAddressHash: @address_hash_type,
        homeDecimals: @token_decimal_type,
        homeHolderCount: %{
          type: "value",
          definition: "Token holders count.",
          example: ~s("393")
        },
        homeName: @token_name_type,
        homeSymbol: @token_symbol_type,
        homeTotalSupply: %{
          type: "value",
          definition: "Total supply of the token on the home side (where token was bridged).",
          example: ~s("1484374.775044204093387391")
        },
        homeUsdValue: %{
          type: "value",
          definition: "Total supply of the token on the home side (where token was bridged) in USD.",
          example: ~s("6638727.472651464170990256943")
        }
      }
    }

    @token_bridgedtokenlist_example_value %{
      "status" => "1",
      "message" => "OK",
      "result" => [
        %{
          "foreignChainId" => "1",
          "foreignTokenContractAddressHash" => "0x0ae055097c6d159879521c384f1d2123d1f195e6",
          "homeContractAddressHash" => "0xb7d311e2eb55f2f68a9440da38e7989210b9a05e",
          "homeDecimals" => "18",
          "homeHolderCount" => 393,
          "homeName" => "STAKE on xDai",
          "homeSymbol" => "STAKE",
          "homeTotalSupply" => "1484374.775044204093387391",
          "homeUsdValue" => "18807028.39981006586321824397"
        },
        %{
          "foreignChainId" => "1",
          "foreignTokenContractAddressHash" => "0xf5581dfefd8fb0e4aec526be659cfab1f8c781da",
          "homeContractAddressHash" => "0xd057604a14982fe8d88c5fc25aac3267ea142a08",
          "homeDecimals" => "18",
          "homeHolderCount" => 73,
          "homeName" => "HOPR Token on xDai",
          "homeSymbol" => "HOPR",
          "homeTotalSupply" => "26600449.86076749062791602",
          "homeUsdValue" => "6638727.472651464170990256943"
        }
      ]
    }

    @token_bridgedtokenlist_action %{
      name: "bridgedTokenList",
      description: "Get bridged tokens list.",
      required_params: [],
      optional_params: [
        %{
          key: "chainid",
          type: "integer",
          description: "A nonnegative integer that represents the chain id, where original token exists."
        },
        %{
          key: "page",
          type: "integer",
          description:
            "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction."
        },
        %{
          key: "offset",
          type: "integer",
          description:
            "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction."
        }
      ],
      responses: [
        %{
          code: "200",
          description: "successful operation",
          example_value: Jason.encode!(@token_bridgedtokenlist_example_value),
          model: %{
            name: "Result",
            fields: %{
              status: @success_status_type,
              message: @message_type,
              result: %{
                type: "array",
                array_type: @bridged_token_details
              }
            }
          }
        }
      ]
    }
  end

  @stats_tokensupply_action %{
    name: "tokensupply",
    description:
      "Get <a href='https://github.com/ethereum/EIPs/issues/20'>ERC-20</a> or " <>
        "<a href='https://github.com/ethereum/EIPs/issues/721'>ERC-721</a> " <>
        " token total supply by contract address.",
    required_params: [
      %{
        key: "contractaddress",
        placeholder: "contractAddressHash",
        type: "string",
        description: "A 160-bit code used for identifying contracts."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@stats_tokensupply_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "integer",
              definition: "The total supply of the token.",
              example: ~s("1000000000")
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@token_gettoken_example_value_error)
      }
    ]
  }

  @stats_ethsupplyexchange_action %{
    name: "ethsupplyexchange",
    description: "Get total supply in Wei from exchange.",
    required_params: [],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@stats_ethsupplyexchange_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "integer",
              description: "The total supply.",
              example: ~s("101959776311500000000000000")
            }
          }
        }
      }
    ]
  }

  @stats_ethsupply_action %{
    name: "ethsupply",
    description: "Get total supply in Wei from DB.",
    required_params: [],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@stats_ethsupply_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "integer",
              description: "The total supply in Wei from DB.",
              example: ~s("101959776311500000000000000")
            }
          }
        }
      }
    ]
  }

  @stats_coinsupply_action %{
    name: "coinsupply",
    description: "Get total coin supply from DB minus burnt number.",
    required_params: [],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@stats_coinsupply_example_value),
        model: %{
          name: "Result",
          fields: %{
            result: %{
              type: "integer",
              description: "The total supply from DB minus burnt number in coin dimension.",
              example: 101_959_776.3115
            }
          }
        }
      }
    ]
  }

  @stats_coinprice_action %{
    name: "coinprice",
    description: "Get latest price of native coin in USD and BTC.",
    required_params: [],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@stats_coinprice_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "model",
              model: @coin_price_model
            }
          }
        }
      }
    ]
  }

  @stats_totalfees_action %{
    name: "totalfees",
    description: "Gets total transaction fees in Wei are paid by users to validators per day.",
    required_params: [
      %{
        key: "date",
        placeholder: "date",
        type: "string",
        description: "day in ISO 8601 format (yyyy-mm-dd)"
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@stats_totalfees_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "model",
              model: @total_fees_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@stats_totalfees_example_value_error)
      }
    ]
  }

  @block_eth_block_number_action %{
    name: "eth_block_number",
    description: "Mimics Ethereum JSON RPC's eth_blockNumber. Returns the latest block number",
    required_params: [],
    optional_params: [
      %{
        key: "id",
        placeholder: "request id",
        type: "integer",
        description: "A nonnegative integer that represents the json rpc request id."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful request",
        example_value: Jason.encode!(@block_eth_block_number_example_value),
        model: %{
          name: "Result",
          fields: %{
            jsonrpc: @jsonrpc_version_type,
            id: @id_type,
            result: @hex_number_type
          }
        }
      }
    ]
  }

  @block_getblockreward_action %{
    name: "getblockreward",
    description: "Get block reward by block number.",
    required_params: [
      %{
        key: "blockno",
        placeholder: "blockNumber",
        type: "integer",
        description: "A nonnegative integer that represents the block number."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@block_getblockreward_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "model",
              model: @block_reward_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@block_getblockreward_example_value_error)
      }
    ]
  }

  @block_getblocknobytime_action %{
    name: "getblocknobytime",
    description: "Get Block Number by Timestamp.",
    required_params: [
      %{
        key: "timestamp",
        placeholder: "blockTimestamp",
        type: "integer",
        description: "A nonnegative integer that represents the block timestamp (Unix timestamp in seconds)."
      },
      %{
        key: "closest",
        placeholder: "before/after",
        type: "string",
        description: "Direction to find the closest block number to given timestamp. Available values: before/after."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@block_getblocknobytime_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "model",
              model: @block_no_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@block_getblocknobytime_example_value_error)
      }
    ]
  }

  @contract_listcontracts_action %{
    name: "listcontracts",
    description: """
    Get a list of contracts, sorted ascending by the time they were first seen by the explorer.

    If you provide the filter `unverified(2)` the results will not
    be sorted for performance reasons.
    """,
    required_params: [],
    optional_params: [
      %{
        key: "page",
        type: "integer",
        description:
          "A nonnegative integer that represents the page number to be used for pagination. 'offset' must be provided in conjunction."
      },
      %{
        key: "offset",
        type: "integer",
        description:
          "A nonnegative integer that represents the maximum number of records to return when paginating. 'page' must be provided in conjunction."
      },
      %{
        key: "filter",
        type: "string",
        description: "verified|unverified|empty, or 1|2|3 respectively. This requests only contracts with that status."
      },
      %{
        key: "verified_at_start_timestamp",
        type: "unix timestamp",
        description:
          "Represents the starting timestamp when contracts verified. Taking into account only with `verified` filter."
      },
      %{
        key: "verified_at_end_timestamp",
        type: "unix timestamp",
        description:
          "Represents the ending timestamp when contracts verified. Taking into account only with `verified` filter."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@contract_listcontracts_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @contract_model
            }
          }
        }
      }
    ]
  }

  @contract_verify_action %{
    name: "verify",
    description: """
    Verify a contract with its source code and contract creation information.
    <br/>
    <br/>
    <p class="api-doc-list-item-text">curl POST example:</p>
    <br/>
    <div class='tab-content'>
    <div class='tab-pane fade show active'>
    <div class="tile tile-muted p-1">
    <div class="m-2">
    curl -d '{"addressHash":"0xc63BB6555C90846afACaC08A0F0Aa5caFCB382a1","compilerVersion":"v0.5.4+commit.9549d8ff",
    "contractSourceCode":"pragma solidity ^0.5.4; \ncontract Test {\n}","name":"Test","optimization":false}'
    -H "Content-Type: application/json" -X POST  "https://blockscout.com/poa/sokol/api?module=contract&action=verify"
    </pre>
    </div>
    </div>
    </div>
    """,
    required_params: [
      %{
        key: "addressHash",
        placeholder: "addressHash",
        type: "string",
        description: "The address of the contract."
      },
      %{
        key: "name",
        placeholder: "name",
        type: "string",
        description: "The name of the contract."
      },
      %{
        key: "compilerVersion",
        placeholder: "compilerVersion",
        type: "string",
        description: "The compiler version for the contract."
      },
      %{
        key: "optimization",
        placeholder: false,
        type: "boolean",
        description: "Whether or not compiler optimizations were enabled."
      },
      %{
        key: "contractSourceCode",
        placeholder: "contractSourceCode",
        type: "string",
        description: "The source code of the contract."
      }
    ],
    optional_params: [
      %{
        key: "constructorArguments",
        type: "string",
        description: "The constructor argument data provided."
      },
      %{
        key: "autodetectConstructorArguments",
        placeholder: false,
        type: "boolean",
        description: "Whether or not automatically detect constructor argument."
      },
      %{
        key: "evmVersion",
        placeholder: "evmVersion",
        type: "string",
        description: "The EVM version for the contract."
      },
      %{
        key: "optimizationRuns",
        placeholder: "optimizationRuns",
        type: "integer",
        description: "The number of optimization runs used during compilation"
      },
      %{
        key: "library1Name",
        type: "string",
        description: "The name of the first library used."
      },
      %{
        key: "library1Address",
        type: "string",
        description: "The address of the first library used."
      },
      %{
        key: "library2Name",
        type: "string",
        description: "The name of the second library used."
      },
      %{
        key: "library2Address",
        type: "string",
        description: "The address of the second library used."
      },
      %{
        key: "library3Name",
        type: "string",
        description: "The name of the third library used."
      },
      %{
        key: "library3Address",
        type: "string",
        description: "The address of the third library used."
      },
      %{
        key: "library4Name",
        type: "string",
        description: "The name of the fourth library used."
      },
      %{
        key: "library4Address",
        type: "string",
        description: "The address of the fourth library used."
      },
      %{
        key: "library5Name",
        type: "string",
        description: "The name of the fourth library used."
      },
      %{
        key: "library5Address",
        type: "string",
        description: "The address of the fourth library used."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@contract_verify_example_value),
        type: "model",
        model: @contract_model
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@contract_verify_example_value_error)
      }
    ]
  }

  @contract_verify_via_sourcify_action %{
    name: "verify_via_sourcify",
    description: """
    Verify a contract through <a href="https://sourcify.dev">Sourcify</a>.<br/>
    a) if smart-contract already verified on Sourcify, it will automatically fetch the data from the <a href="https://repo.sourcify.dev">repo</a><br/>
    b) otherwise you have to upload source files and JSON metadata file(s).
    <br/>
    <br/>
    <p class="api-doc-list-item-text">POST body example:</p>
    <br/>
    <div class='tab-content'>
    <div class='tab-pane fade show active'>
    <div class="tile tile-muted p-1">
    <div class="m-2">
    --6e1e4c11657c62dc1e4349d024de9e28<br/>
    Content-Disposition: form-data; name="addressHash"<br/>
    <br/>
    0xb77b7443e0F32F1FEBf0BE0fBd7124D135d0a525<br/>
    <br/>
    --6e1e4c11657c62dc1e4349d024de9e28<br/>
    Content-Disposition: form-data; name="files[0]"; filename="contract.sol"<br/>
    Content-Type: application/json<br/>
    <br/>
    ...Source code...<br/>
    <br/>
    --6e1e4c11657c62dc1e4349d024de9e28<br/>
    Content-Disposition: form-data; name="files[1]"; filename="metadata.json"<br/>
    Content-Type: application/json<br/>
    <br/>
    ...JSON metadata...<br/>
    <br/>
    --6e1e4c11657c62dc1e4349d024de9e28--<br/>
    </pre>
    </div>
    </div>
    </div>
    """,
    required_params: [
      %{
        key: "addressHash",
        placeholder: "addressHash",
        type: "string",
        description: "The address of the contract."
      }
    ],
    optional_params: [
      %{
        key: "files",
        type: "file[]",
        description: "Array with sources and metadata files"
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@contract_verify_example_value),
        type: "model",
        model: @contract_model
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@contract_verify_example_value_error)
      }
    ]
  }

  @contract_verify_vyper_contract_action %{
    name: "verify_vyper_contract",
    description: """
    Verify a vyper contract with its source code and contract creation information.
    <br/>
    <br/>
    <p class="api-doc-list-item-text">curl POST example:</p>
    <br/>
    <div class='tab-content'>
    <div class='tab-pane fade show active'>
    <div class="tile tile-muted p-1">
    <div class="m-2">
    curl --location --request POST 'http://localhost:4000/api?module=contract&action=verify_vyper_contract' \
    --form 'contractSourceCode="SOURCE_CODE"' \
    --form 'name="Vyper_contract"' \
    --form 'addressHash="0xE60B1B8bD493569a3E945be50A6c89d29a560Fa1"' \
    --form 'compilerVersion="v0.2.12"'
    </pre>
    </div>
    </div>
    </div>
    """,
    required_params: [
      %{
        key: "addressHash",
        placeholder: "addressHash",
        type: "string",
        description: "The address of the contract."
      },
      %{
        key: "name",
        placeholder: "name",
        type: "string",
        description: "The name of the contract."
      },
      %{
        key: "compilerVersion",
        placeholder: "compilerVersion",
        type: "string",
        description: "The compiler version for the contract."
      },
      %{
        key: "contractSourceCode",
        placeholder: "contractSourceCode",
        type: "string",
        description: "The source code of the contract."
      }
    ],
    optional_params: [
      %{
        key: "constructorArguments",
        type: "string",
        description: "The constructor argument data provided."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@contract_verify_example_value),
        type: "model",
        model: @contract_model
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@contract_verify_example_value_error)
      }
    ]
  }

  @contract_verifysourcecode_action %{
    name: "verifysourcecode",
    description: """
    Verify a contract with Standard input JSON file. Its interface the same as <a href="https://docs.etherscan.io/tutorials/verifying-contracts-programmatically">Etherscan</a>'s API endpoint
    <br/>
    <br/>
    """,
    required_params: [
      %{
        name: "solidity-standard-json-input",
        key: "codeformat",
        placeholder: "solidity-standard-json-input",
        type: "string",
        description: "Format of sourceCode(supported only \"solidity-standard-json-input\")"
      },
      %{
        key: "contractaddress",
        placeholder: "contractaddress",
        type: "string",
        description: "The address of the contract."
      },
      %{
        key: "contractname",
        placeholder: "contractname",
        type: "string",
        description:
          "The name of the contract. It could be empty string(\"\"), just contract name(\"ContractName\"), or filename and contract name(\"contracts/contract_1.sol:ContractName\")"
      },
      %{
        key: "compilerversion",
        placeholder: "compilerversion",
        type: "string",
        description: "The compiler version for the contract."
      },
      %{
        key: "sourceCode",
        placeholder: "sourceCode",
        type: "string",
        description: "Standard input json"
      }
    ],
    optional_params: [
      %{
        key: "constructorArguments",
        type: "string",
        description: "The constructor argument data provided."
      },
      %{
        key: "autodetectConstructorArguments",
        placeholder: false,
        type: "boolean",
        description: "Whether or not automatically detect constructor argument."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@contract_verifysourcecode_example_value),
        type: "model",
        model: @uid_response_model
      }
    ]
  }

  @contract_checkverifystatus_action %{
    name: "checkverifystatus",
    description: "Return status of the verification attempt (works in addition to verifysourcecode method)",
    required_params: [
      %{
        key: "guid",
        placeholder: "identifierString",
        type: "string",
        description: "A string used for identifying verification attempt"
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@contract_checkverifystatus_example_value),
        type: "model",
        model: @status_response_model
      }
    ]
  }

  @contract_getabi_action %{
    name: "getabi",
    description: "Get ABI for verified contract. Also available through a GraphQL 'addresses' query.",
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying contracts."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@contract_getabi_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "abi",
              definition: "JSON string for the Application Binary Interface (ABI)"
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@contract_getabi_example_value_error)
      }
    ]
  }

  @contract_getsourcecode_action %{
    name: "getsourcecode",
    description: "Get contract source code for verified contract. Also available through a GraphQL 'addresses' query.",
    required_params: [
      %{
        key: "address",
        placeholder: "addressHash",
        type: "string",
        description: "A 160-bit code used for identifying contracts."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@contract_getsourcecode_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "array",
              array_type: @contract_with_sourcecode_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@contract_getsourcecode_example_value_error)
      }
    ]
  }

  @transaction_gettxinfo_action %{
    name: "gettxinfo",
    description: "Get transaction info.",
    required_params: [
      %{
        key: "txhash",
        placeholder: "transactionHash",
        type: "string",
        description: "Transaction hash. Hash of contents of the transaction."
      }
    ],
    optional_params: [
      %{
        key: "index",
        type: "integer",
        description: "A nonnegative integer that represents the log index to be used for pagination."
      }
    ],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@transaction_gettxinfo_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "model",
              model: @transaction_info_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@transaction_gettxreceiptstatus_example_value_error)
      }
    ]
  }

  @transaction_gettxreceiptstatus_action %{
    name: "gettxreceiptstatus",
    description: "Get transaction receipt status. Also available through a GraphQL 'transaction' query.",
    required_params: [
      %{
        key: "txhash",
        placeholder: "transactionHash",
        type: "string",
        description: "Transaction hash. Hash of contents of the transaction."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@transaction_gettxreceiptstatus_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "model",
              model: @transaction_receipt_status_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@transaction_gettxreceiptstatus_example_value_error)
      }
    ]
  }

  @transaction_getstatus_action %{
    name: "getstatus",
    description: "Get error status and error message. Also available through a GraphQL 'transaction' query.",
    required_params: [
      %{
        key: "txhash",
        placeholder: "transactionHash",
        type: "string",
        description: "Transaction hash. Hash of contents of the transaction."
      }
    ],
    optional_params: [],
    responses: [
      %{
        code: "200",
        description: "successful operation",
        example_value: Jason.encode!(@transaction_getstatus_example_value),
        model: %{
          name: "Result",
          fields: %{
            status: @status_type,
            message: @message_type,
            result: %{
              type: "model",
              model: @transaction_status_model
            }
          }
        }
      },
      %{
        code: "200",
        description: "error",
        example_value: Jason.encode!(@transaction_getstatus_example_value_error)
      }
    ]
  }

  @account_module %{
    name: "account",
    actions: [
      @account_eth_get_balance_action,
      @account_balance_action,
      @account_balancemulti_action,
      @account_pendingtxlist_action,
      @account_txlist_action,
      @account_txlistinternal_action,
      @account_tokentx_action,
      @account_tokenbalance_action,
      @account_tokenlist_action,
      @account_getminedblocks_action,
      @account_listaccounts_action
    ]
  }

  @logs_module %{
    name: "logs",
    actions: [@logs_getlogs_action]
  }

  @base_token_actions [
    @token_gettoken_action,
    @token_gettokenholders_action
  ]

  @token_actions if @bridged_tokens_enabled,
                   do: [@token_bridgedtokenlist_action, @base_token_actions],
                   else: @base_token_actions

  @token_module %{
    name: "token",
    actions: @token_actions
  }

  @stats_module %{
    name: "stats",
    actions: [
      @stats_tokensupply_action,
      @stats_ethsupplyexchange_action,
      @stats_ethsupply_action,
      @stats_coinsupply_action,
      @stats_coinprice_action,
      @stats_totalfees_action
    ]
  }

  @block_module %{
    name: "block",
    actions: [@block_getblockreward_action, @block_getblocknobytime_action, @block_eth_block_number_action]
  }

  @contract_module %{
    name: "contract",
    actions: [
      @contract_listcontracts_action,
      @contract_getabi_action,
      @contract_getsourcecode_action,
      @contract_verify_action,
      @contract_verify_via_sourcify_action,
      @contract_verify_vyper_contract_action,
      @contract_verifysourcecode_action,
      @contract_checkverifystatus_action
    ]
  }

  @transaction_module %{
    name: "transaction",
    actions: [
      @transaction_gettxinfo_action,
      @transaction_gettxreceiptstatus_action,
      @transaction_getstatus_action
    ]
  }

  @documentation [
    @account_module,
    @logs_module,
    @token_module,
    @stats_module,
    @block_module,
    @contract_module,
    @transaction_module
  ]

  def get_documentation do
    @documentation
  end

  def wei_type_definition(coin) do
    "The smallest subdenomination of #{coin}, " <>
      "and thus the one in which all integer values of the currency are counted, is the Wei. " <>
      "One #{coin} is defined as being 10<sup>18</sup> Wei."
  end

  def coin_btc_type_definition(coin) do
    "#{coin} price in Bitcoin."
  end

  def coin_usd_type_definition(coin) do
    "#{coin} price in US dollars."
  end
end
