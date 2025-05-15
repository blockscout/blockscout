defmodule EthereumJSONRPC.Blocks do
  @moduledoc """
  Blocks format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_getblockbynumber) from batch requests.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias EthereumJSONRPC.{Block, Transactions, Transport, Uncles, Withdrawals}

  @type elixir :: [Block.elixir()]
  @type params :: [Block.params()]

  @default_struct_fields [
    blocks_params: [],
    block_second_degree_relations_params: [],
    transactions_params: [],
    withdrawals_params: [],
    errors: []
  ]

  case @chain_type do
    :zilliqa ->
      @chain_type_fields quote(
                           do: [
                             zilliqa_quorum_certificates_params: [
                               EthereumJSONRPC.Zilliqa.QuorumCertificate.params()
                             ],
                             zilliqa_aggregate_quorum_certificates_params: [
                               EthereumJSONRPC.Zilliqa.AggregateQuorumCertificate.params()
                             ],
                             zilliqa_nested_quorum_certificates_params: [
                               EthereumJSONRPC.Zilliqa.NestedQuorumCertificates.params()
                             ]
                           ]
                         )

      @chain_type_struct_fields [
        zilliqa_quorum_certificates_params: [],
        zilliqa_aggregate_quorum_certificates_params: [],
        zilliqa_nested_quorum_certificates_params: []
      ]

    _ ->
      @chain_type_struct_fields []
      @chain_type_fields quote(do: [])
  end

  @type t :: %__MODULE__{
          unquote_splicing(@chain_type_fields),
          blocks_params: [map()],
          block_second_degree_relations_params: [map()],
          transactions_params: [map()],
          withdrawals_params: Withdrawals.params(),
          errors: [Transport.error()]
        }

  defstruct @default_struct_fields ++ @chain_type_struct_fields

  @doc """
    Generates a list of JSON-RPC requests for fetching block data.

    Takes a map of request IDs to parameters and a request function, and generates
    a list of JSON-RPC requests by applying the request function to each parameter
    set after adding the ID.

    ## Parameters
    - `id_to_params`: Map of request IDs to their corresponding request parameters
    - `request`: Function that takes a parameter map and returns a JSON-RPC request

    ## Returns
    - List of JSON-RPC request maps ready to be sent to the Ethereum node
  """
  @spec requests(%{EthereumJSONRPC.request_id() => map()}, function()) :: [EthereumJSONRPC.Transport.request()]
  def requests(id_to_params, request) when is_map(id_to_params) and is_function(request, 1) do
    Enum.map(id_to_params, fn {id, params} ->
      params
      |> Map.put(:id, id)
      |> request.()
    end)
  end

  @doc """
    Processes batch responses from JSON-RPC block requests into structured block data.

    Converts raw JSON-RPC responses into a structured format containing block data,
    transactions, uncles, withdrawals and any errors encountered during processing.
    Sanitizes responses by handling missing IDs and adjusts errors to maintain
    request-response correlation.

    ## Parameters
    - `responses`: List of JSON-RPC responses from block requests.
    - `id_to_params`: Map of request IDs to their corresponding requests parameters.

    ## Returns
    A `t:t/0` struct containing:
    - `blocks_params`: List of processed block parameters
    - `block_second_degree_relations_params`: List of uncle block relations
    - `transactions_params`: List of transaction parameters
    - `withdrawals_params`: List of withdrawal parameters
    - `errors`: List of errors encountered during processing, with adjusted IDs to
      match original requests
  """
  @spec from_responses(EthereumJSONRPC.Transport.batch_response(), %{EthereumJSONRPC.request_id() => map()}) :: t()
  def from_responses(responses, id_to_params) when is_list(responses) and is_map(id_to_params) do
    %{errors: errors, blocks: blocks} =
      responses
      |> EthereumJSONRPC.sanitize_responses(id_to_params)
      |> Enum.map(&Block.from_response(&1, id_to_params))
      |> Enum.reduce(%{errors: [], blocks: []}, fn
        {:ok, block}, %{blocks: blocks} = acc ->
          %{acc | blocks: [block | blocks]}

        {:error, error}, %{errors: errors} = acc ->
          %{acc | errors: [error | errors]}
      end)

    elixir_blocks = to_elixir(blocks)

    elixir_uncles = elixir_to_uncles(elixir_blocks)
    elixir_transactions = elixir_to_transactions(elixir_blocks)
    elixir_withdrawals = elixir_to_withdrawals(elixir_blocks)

    block_second_degree_relations_params = Uncles.elixir_to_params(elixir_uncles)
    transactions_params = Transactions.elixir_to_params(elixir_transactions)
    withdrawals_params = Withdrawals.elixir_to_params(elixir_withdrawals)
    blocks_params = elixir_to_params(elixir_blocks)

    %__MODULE__{
      errors: errors,
      blocks_params: blocks_params,
      block_second_degree_relations_params: block_second_degree_relations_params,
      transactions_params: transactions_params,
      withdrawals_params: withdrawals_params
    }
    |> extend_with_chain_type_fields(elixir_blocks)
  end

  @spec extend_with_chain_type_fields(t(), elixir()) :: t()
  case @chain_type do
    :zilliqa ->
      defp extend_with_chain_type_fields(%__MODULE__{} = blocks, elixir_blocks) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        EthereumJSONRPC.Zilliqa.Helper.extend_blocks_struct(blocks, elixir_blocks)
      end

    _ ->
      defp extend_with_chain_type_fields(%__MODULE__{} = blocks, _elixir_blocks) do
        blocks
      end
  end

  @doc """
  Converts `t:elixir/0` elements to params used by `Explorer.Chain.Block.changeset/2`.

      iex> EthereumJSONRPC.Blocks.elixir_to_params(
      ...>   [
      ...>     %{
      ...>       "author" => "0x0000000000000000000000000000000000000000",
      ...>       "difficulty" => 131072,
      ...>       "extraData" => "0x",
      ...>       "gasLimit" => 6700000,
      ...>       "gasUsed" => 0,
      ...>       "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
      ...>       "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>       "miner" => "0x0000000000000000000000000000000000000000",
      ...>       "number" => 0,
      ...>       "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
      ...>       "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>       "sealFields" => ["0x80",
      ...>        "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"],
      ...>       "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>       "signature" => "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>       "size" => 533,
      ...>       "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
      ...>       "step" => "0",
      ...>       "timestamp" => Timex.parse!("1970-01-01T00:00:00Z", "{ISO:Extended:Z}"),
      ...>       "totalDifficulty" => 131072,
      ...>       "transactions" => [],
      ...>       "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>       "uncles" => ["0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311"]
      ...>     }
      ...>   ]
      ...> )
      [
        %{
          difficulty: 131072,
          extra_data: "0x",
          gas_limit: 6700000,
          gas_used: 0,
          hash: "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
          logs_bloom: "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
          miner_hash: "0x0000000000000000000000000000000000000000",
          mix_hash: "0x0",
          nonce: 0,
          number: 0,
          parent_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
          receipts_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
          sha3_uncles: "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
          size: 533,
          state_root: "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
          timestamp: Timex.parse!("1970-01-01T00:00:00Z", "{ISO:Extended:Z}"),
          total_difficulty: 131072,
          transactions_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",\
  #{case @chain_type do
    :rsk -> """
              bitcoin_merged_mining_coinbase_transaction: nil,\
              bitcoin_merged_mining_header: nil,\
              bitcoin_merged_mining_merkle_proof: nil,\
              hash_for_merged_mining: nil,\
              minimum_gas_price: nil,\
      """
    :ethereum -> """
              withdrawals_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",\
              blob_gas_used: 0,\
              excess_blob_gas: 0,\
      """
    :arbitrum -> """
              send_root: nil,\
              send_count: nil,\
              l1_block_number: nil,\
      """
    :zilliqa -> """
                zilliqa_view: nil,\
      """
    _ -> ""
  end}
          uncles: ["0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311"]
        }
      ]

  """
  @spec elixir_to_params(elixir) :: params()
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Block.elixir_to_params/1)
  end

  @doc """
  Extracts the `t:EthereumJSONRPC.Transactions.elixir/0` from the `t:elixir/0`.

      iex> EthereumJSONRPC.Blocks.elixir_to_transactions([
      ...>   %{
      ...>     "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "difficulty" => 340282366920938463463374607431768211454,
      ...>     "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
      ...>     "gasLimit" => 6926030,
      ...>     "gasUsed" => 269607,
      ...>     "hash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "number" => 34,
      ...>     "parentHash" => "0x106d528393159b93218dd410e2a778f083538098e46f1a44902aa67a164aed0b",
      ...>     "receiptsRoot" => "0xf45ed4ab910504ffe231230879c86e32b531bb38a398a7c9e266b4a992e12dfb",
      ...>     "sealFields" => ["0x84120a71db",
      ...>      "0xb8417ad0ecca535f81e1807dac338a57c7ccffd05d3e7f0687944650cd005360a192205df306a68eddfe216e0674c6b113050d90eff9b627c1762d43657308f986f501"],
      ...>     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>     "signature" => "7ad0ecca535f81e1807dac338a57c7ccffd05d3e7f0687944650cd005360a192205df306a68eddfe216e0674c6b113050d90eff9b627c1762d43657308f986f501",
      ...>     "size" => 1493,
      ...>     "stateRoot" => "0x6eaa6281df37b9b010f4779affc25ee059088240547ce86cf7ca7b7acd952d4f",
      ...>     "step" => "302674395",
      ...>     "timestamp" => Timex.parse!("2017-12-15T21:06:15Z", "{ISO:Extended:Z}"),
      ...>     "totalDifficulty" => 11569600475311907757754736652679816646147,
      ...>     "transactions" => [
      ...>       %{
      ...>         "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>         "blockNumber" => 34,
      ...>         "chainId" => 77,
      ...>         "condition" => nil,
      ...>         "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>         "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         "gas" => 4700000,
      ...>         "gasPrice" => 100000000000,
      ...>         "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>         "input" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>         "nonce" => 0,
      ...>         "publicKey" => "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
      ...>         "r" => "0xad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75",
      ...>         "raw" => "0xf9038d8085174876e8008347b7608080b903396060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b002981bda0ad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75a072caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
      ...>         "s" => "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
      ...>         "standardV" => "0x0",
      ...>         "to" => nil,
      ...>         "transactionIndex" => 0,
      ...>         "v" => "0xbd",
      ...>         "value" => 0
      ...>       }
      ...>     ],
      ...>     "transactionsRoot" => "0x2c2e243e9735f6d0081ffe60356c0e4ec4c6a9064c68d10bf8091ff896f33087",
      ...>     "uncles" => []
      ...>   }
      ...> ])
      [
        %{
          "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
          "blockNumber" => 34,
          "chainId" => 77,
          "condition" => nil,
          "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
          "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
          "gas" => 4700000,
          "gasPrice" => 100000000000,
          "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
          "input" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
          "nonce" => 0,
          "publicKey" => "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
          "r" => "0xad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75",
          "raw" => "0xf9038d8085174876e8008347b7608080b903396060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b002981bda0ad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75a072caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
          "s" => "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
          "standardV" => "0x0",
          "to" => nil,
          "transactionIndex" => 0,
          "v" => "0xbd",
          "value" => 0
        }
      ]

  """
  @spec elixir_to_transactions(elixir) :: Transactions.elixir()
  def elixir_to_transactions(elixir) when is_list(elixir) do
    Enum.flat_map(elixir, &Block.elixir_to_transactions/1)
  end

  @doc """
  Extracts the `t:EthereumJSONRPC.Uncles.elixir/0` from the `t:elixir/0`.

      iex> EthereumJSONRPC.Blocks.elixir_to_uncles([
      ...>   %{
      ...>     "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "difficulty" => 340282366920938463463374607431768211454,
      ...>     "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
      ...>     "gasLimit" => 6926030,
      ...>     "gasUsed" => 269607,
      ...>     "hash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "number" => 34,
      ...>     "parentHash" => "0x106d528393159b93218dd410e2a778f083538098e46f1a44902aa67a164aed0b",
      ...>     "receiptsRoot" => "0xf45ed4ab910504ffe231230879c86e32b531bb38a398a7c9e266b4a992e12dfb",
      ...>     "sealFields" => ["0x84120a71db",
      ...>      "0xb8417ad0ecca535f81e1807dac338a57c7ccffd05d3e7f0687944650cd005360a192205df306a68eddfe216e0674c6b113050d90eff9b627c1762d43657308f986f501"],
      ...>     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>     "signature" => "7ad0ecca535f81e1807dac338a57c7ccffd05d3e7f0687944650cd005360a192205df306a68eddfe216e0674c6b113050d90eff9b627c1762d43657308f986f501",
      ...>     "size" => 1493,
      ...>     "stateRoot" => "0x6eaa6281df37b9b010f4779affc25ee059088240547ce86cf7ca7b7acd952d4f",
      ...>     "step" => "302674395",
      ...>     "timestamp" => Timex.parse!("2017-12-15T21:06:15Z", "{ISO:Extended:Z}"),
      ...>     "totalDifficulty" => 11569600475311907757754736652679816646147,
      ...>     "transactions" => [
      ...>       %{
      ...>         "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>         "blockNumber" => 34,
      ...>         "chainId" => 77,
      ...>         "condition" => nil,
      ...>         "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>         "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         "gas" => 4700000,
      ...>         "gasPrice" => 100000000000,
      ...>         "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>         "input" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>         "nonce" => 0,
      ...>         "publicKey" => "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
      ...>         "r" => "0xad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75",
      ...>         "raw" => "0xf9038d8085174876e8008347b7608080b903396060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b002981bda0ad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75a072caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
      ...>         "s" => "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
      ...>         "standardV" => "0x0",
      ...>         "to" => nil,
      ...>         "transactionIndex" => 0,
      ...>         "v" => "0xbd",
      ...>         "value" => 0
      ...>       }
      ...>     ],
      ...>     "transactionsRoot" => "0x2c2e243e9735f6d0081ffe60356c0e4ec4c6a9064c68d10bf8091ff896f33087",
      ...>     "uncles" => ["0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311"]
      ...>   }
      ...> ])
      [
        %{
          "hash" => "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311",
          "nephewHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
          "index" => 0
        }
      ]

  """
  @spec elixir_to_uncles(elixir) :: Uncles.elixir()
  def elixir_to_uncles(elixir) do
    Enum.flat_map(elixir, &Block.elixir_to_uncles/1)
  end

  @doc """
  Extracts the `t:EthereumJSONRPC.Withdrawals.elixir/0` from the `t:elixir/0`.

      iex> EthereumJSONRPC.Blocks.elixir_to_withdrawals([
      ...>   %{
      ...>     "baseFeePerGas" => 7,
      ...>     "difficulty" => 0,
      ...>     "extraData" => "0x",
      ...>     "gasLimit" => 7_009_844,
      ...>     "gasUsed" => 0,
      ...>     "hash" => "0xc0b72358464dc55cb51c990360d94809e40f291603a7664d55cf83f87edb799d",
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "miner" => "0xe7c180eada8f60d63e9671867b2e0ca2649207a8",
      ...>     "mixHash" => "0x9cc5c22d51f47caf700636f629e0765a5fe3388284682434a3717d099960681a",
      ...>     "nonce" => "0x0000000000000000",
      ...>     "number" => 541,
      ...>     "parentHash" => "0x9bc27f8db423bea352a32b819330df307dd351da71f3b3f8ac4ad56856c1e053",
      ...>     "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>     "size" => 1107,
      ...>     "stateRoot" => "0x9de54b38595b4b8baeece667ae1f7bec8cfc814a514248985e3d98c91d331c71",
      ...>     "timestamp" => Timex.parse!("2022-12-15T21:06:15Z", "{ISO:Extended:Z}"),
      ...>     "totalDifficulty" => 1,
      ...>     "transactions" => [],
      ...>     "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>     "uncles" => [],
      ...>     "withdrawals" => [
      ...>       %{
      ...>         "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
      ...>         "amount" => 4_040_000_000_000,
      ...>         "blockHash" => "0xc0b72358464dc55cb51c990360d94809e40f291603a7664d55cf83f87edb799d",
      ...>         "index" => 3867,
      ...>         "validatorIndex" => 1721
      ...>       },
      ...>       %{
      ...>         "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
      ...>         "amount" => 4_040_000_000_000,
      ...>         "blockHash" => "0xc0b72358464dc55cb51c990360d94809e40f291603a7664d55cf83f87edb799d",
      ...>         "index" => 3868,
      ...>         "validatorIndex" => 1771
      ...>       }
      ...>     ],
      ...>     "withdrawalsRoot" => "0x23e926286a20cba56ee0fcf0eca7aae44f013bd9695aaab58478e8d69b0c3d68"
      ...>   }
      ...> ])
      [
        %{
          "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
          "amount" => 4040000000000,
          "blockHash" => "0xc0b72358464dc55cb51c990360d94809e40f291603a7664d55cf83f87edb799d",
          "index" => 3867,
          "validatorIndex" => 1721
        },
        %{
          "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
          "amount" => 4040000000000,
          "blockHash" => "0xc0b72358464dc55cb51c990360d94809e40f291603a7664d55cf83f87edb799d",
          "index" => 3868,
          "validatorIndex" => 1771
        }
      ]

  """
  @spec elixir_to_withdrawals(elixir) :: Withdrawals.elixir()
  def elixir_to_withdrawals(elixir) do
    Enum.flat_map(elixir, &Block.elixir_to_withdrawals/1)
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0` and the timestamps to `t:DateTime.t/0`

      iex> EthereumJSONRPC.Blocks.to_elixir(
      ...>   [
      ...>     %{
      ...>       "author" => "0x0000000000000000000000000000000000000000",
      ...>       "difficulty" => "0x20000",
      ...>       "extraData" => "0x",
      ...>       "gasLimit" => "0x663be0",
      ...>       "gasUsed" => "0x0",
      ...>       "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
      ...>       "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>       "miner" => "0x0000000000000000000000000000000000000000",
      ...>       "number" => "0x0",
      ...>       "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
      ...>       "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>       "sealFields" => ["0x80",
      ...>        "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"],
      ...>       "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>       "signature" => "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>       "size" => "0x215",
      ...>       "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
      ...>       "step" => "0",
      ...>       "timestamp" => "0x0",
      ...>       "totalDifficulty" => "0x20000",
      ...>       "transactions" => [],
      ...>       "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>       "uncles" => [],
      ...>       "withdrawals" => [
      ...>         %{
      ...>           "index" => "0xf1b",
      ...>           "validatorIndex" => "0x6b9",
      ...>           "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
      ...>           "amount" => "0x3aca2c3d000"
      ...>         },
      ...>         %{
      ...>           "index" => "0xf1c",
      ...>           "validatorIndex" => "0x6eb",
      ...>           "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
      ...>           "amount" => "0x3aca2c3d000"
      ...>         }
      ...>       ],
      ...>       "withdrawalsRoot" => "0x23e926286a20cba56ee0fcf0eca7aae44f013bd9695aaab58478e8d69b0c3d68"
      ...>     }
      ...>   ]
      ...> )
      [
        %{
          "author" => "0x0000000000000000000000000000000000000000",
          "difficulty" => 131072,
          "extraData" => "0x",
          "gasLimit" => 6700000,
          "gasUsed" => 0,
          "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
          "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
          "miner" => "0x0000000000000000000000000000000000000000",
          "number" => 0,
          "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
          "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
          "sealFields" => ["0x80",
           "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"],
          "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
          "signature" => "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
          "size" => 533,
          "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
          "step" => "0",
          "timestamp" => Timex.parse!("1970-01-01T00:00:00Z", "{ISO:Extended:Z}"),
          "totalDifficulty" => 131072,
          "transactions" => [],
          "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
          "uncles" => [],
          "withdrawals" => [
            %{
              "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
              "amount" => 4_040_000_000_000,
              "blockHash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
              "index" => 3867,
              "validatorIndex" => 1721,
              "blockNumber" => 0
            },
            %{
              "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
              "amount" => 4_040_000_000_000,
              "blockHash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
              "index" => 3868,
              "validatorIndex" => 1771,
              "blockNumber" => 0
            }
          ],
          "withdrawalsRoot" => "0x23e926286a20cba56ee0fcf0eca7aae44f013bd9695aaab58478e8d69b0c3d68"
        }
      ]
  """
  @spec to_elixir([Block.t()]) :: elixir
  def to_elixir(blocks) when is_list(blocks) do
    Enum.map(blocks, &Block.to_elixir/1)
  end
end
