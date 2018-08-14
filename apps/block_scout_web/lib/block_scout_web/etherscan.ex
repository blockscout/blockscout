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
    result: [
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
    definition: "A 160-bit code used for identifying Accounts.",
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

  @account_module %{
    name: "account",
    actions: [
      @account_balance_action,
      @account_balancemulti_action,
      @account_txlist_action
    ]
  }

  @documentation [@account_module]

  def get_documentation do
    @documentation
  end

  def wei_type_definition(coin) do
    "The smallest subdenomination of #{coin}, " <>
      "and thus the one in which all integer values of the currency are counted, is the Wei. " <>
      "One #{coin} is defined as being 10<sup>18</sup> Wei."
  end
end
