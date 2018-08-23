defmodule BlockScoutWeb.Etherscan do
  @moduledoc """
  Documentation data for Etherscan-compatible API.
  """

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
        "balance" => "40807168566070000000000"
      },
      %{
        "account" => "0x63a9975ba31b0b9626b34300f7f627147df1f526",
        "balance" => "332567136222827062478"
      },
      %{
        "account" => "0x198ef1ec325a96cc354c7266a038be8b5c558f67",
        "balance" => "185178830000000000"
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
        "input" => "",
        "type" => "create",
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
    "message" => "Invalid contractaddress format",
    "result" => nil
  }

  @stats_tokensupply_example_value %{
    "status" => "1",
    "message" => "OK",
    "result" => "21265524714464"
  }

  @status_type %{
    type: "status",
    enum: ~s(["0", "1"]),
    enum_interpretation: %{"0" => "error", "1" => "ok"}
  }

  @message_type %{
    type: "string",
    example: ~s("OK")
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

  @address_balance %{
    name: "AddressBalance",
    fields: %{
      address: @address_hash_type,
      balance: @wei_type
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
      transactionIndex: %{
        type: "transaction index",
        definition: "Index of the transaction in it's block.",
        example: ~s("0")
      },
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
      input: %{
        type: "input",
        definition: "Data sent along with the transaction. A variable-byte-length binary.",
        example: ~s("0x797af627d02e23b68e085092cd0d47d6cfb54be025f37b5989c0264398f534c08af7dea9")
      },
      contractAddress: @address_hash_type,
      cumulativeGasUsed: @gas_type,
      gasUsed: @gas_type,
      confirmations: %{
        type: "confirmations",
        definition: "A number equal to the current block height minus the transaction's block-number.",
        example: ~s("6005998")
      }
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
      input: %{
        type: "input",
        definition: "Data sent along with the call. A variable-byte-length binary.",
        example: ~s("0x797af627d02e23b68e085092cd0d47d6cfb54be025f37b5989c0264398f534c08af7dea9")
      },
      type: %{
        type: "type",
        definition: ~s(Possible values: "create", "call", "reward", or "suicide"),
        example: ~s("create")
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
      name: %{
        type: "string",
        definition: "Name of the token.",
        example: ~s("Some Token Name")
      },
      symbol: %{
        type: "string",
        definition: "Trading symbol of the token.",
        example: ~s("SYMBOL")
      },
      totalSupply: %{
        type: "integer",
        definition: "The total supply of the token.",
        example: ~s("1000000000")
      },
      decimals: %{
        type: "integer",
        definition: "Number of decimal place the token can be subdivided to.",
        example: ~s("18")
      },
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

  @account_balance_action %{
    name: "balance",
    description: "Get balance for address",
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
    description: "Get balance for multiple addresses",
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

  @account_txlist_action %{
    name: "txlist",
    description: "Get transactions by address. Up to a maximum of 10,000 transactions.",
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
    description: "Get internal transactions by transaction hash. Up to a maximum of 10,000 internal transactions.",
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
    description: "Get ERC-20 or ERC-721 token by contract address.",
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

  @stats_tokensupply_action %{
    name: "tokensupply",
    description: "Get an ERC-20 or ERC-721 token total supply by contract address.",
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

  @account_module %{
    name: "account",
    actions: [
      @account_balance_action,
      @account_balancemulti_action,
      @account_txlist_action,
      @account_txlistinternal_action
    ]
  }

  @logs_module %{
    name: "logs",
    actions: [@logs_getlogs_action]
  }

  @token_module %{
    name: "token",
    actions: [@token_gettoken_action]
  }

  @stats_module %{
    name: "stats",
    actions: [@stats_tokensupply_action]
  }

  @documentation [@account_module, @logs_module, @token_module, @stats_module]

  def get_documentation do
    @documentation
  end

  def wei_type_definition(coin) do
    "The smallest subdenomination of #{coin}, " <>
      "and thus the one in which all integer values of the currency are counted, is the Wei. " <>
      "One #{coin} is defined as being 10<sup>18</sup> Wei."
  end
end
