defmodule EthereumJSONRPC.Log do
  @moduledoc """
  Log included in return from
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt).
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @type elixir :: %{String.t() => String.t() | [String.t()] | non_neg_integer()}

  @typedoc """
   * `"address"` - `t:EthereumJSONRPC.address/0` from which event originated.
   * `"blockHash"` - `t:EthereumJSONRPC.hash/0` of the block this transaction is in.
   * `"blockNumber"` - `t:EthereumJSONRPC.quantity/0` for the block number this transaction is in.
   * `"data"` - Data containing non-indexed log parameter
   * `"logIndex"` - `t:EthereumJSONRPC.quantity/0` of the event index position in the block.
   * `"topics"` - `t:list/0` of at most 4 32-byte topics.  Topic 1-3 contains indexed parameters of the log.
   * `"transactionHash"` - `t:EthereumJSONRPC.hash/0` of the transaction
   * `"transactionIndex"` - `t:EthereumJSONRPC.quantity/0` for the index of the transaction in the block.
  """
  @type t :: %{String.t() => String.t() | [String.t()]}

  @doc """
  Converts `t:elixir/0` format to params used in `Explorer.Chain`.

      iex> EthereumJSONRPC.Log.elixir_to_params(
      ...>   %{
      ...>     "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     "blockNumber" => 37,
      ...>     "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>     "logIndex" => 0,
      ...>     "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
      ...>     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>     "transactionIndex" => 0,
      ...>     "transactionLogIndex" => 0,
      ...>     "type" => "mined"
      ...>   }
      ...> )
      %{
        address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
        block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
        block_number: 37,
        data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
        first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
        fourth_topic: nil,
        index: 0,
        second_topic: nil,
        third_topic: nil,
        transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
        type: "mined"
      }

  Geth does not supply a `"type"`

      iex> EthereumJSONRPC.Log.elixir_to_params(
      ...>   %{
      ...>     "address" => "0xda8b3276cde6d768a44b9dac659faa339a41ac55",
      ...>     "blockHash" => "0x0b89f7f894f5d8ba941e16b61490e999a0fcaaf92dfcc70aee2ac5ddb5f243e1",
      ...>     "blockNumber" => 4448,
      ...>     "data" => "0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563",
      ...>     "logIndex" => 0,
      ...>     "removed" => false,
      ...>     "topics" => ["0xadc1e8a294f8415511303acc4a8c0c5906c7eb0bf2a71043d7f4b03b46a39130",
      ...>       "0x000000000000000000000000c15bf627accd3b054075c7880425f903106be72a",
      ...>       "0x000000000000000000000000a59eb37750f9c8f2e11aac6700e62ef89187e4ed"],
      ...>     "transactionHash" => "0xf9b663b4e9b1fdc94eb27b5cfba04eb03d2f7b3fa0b24eb2e1af34f823f2b89e",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> )
      %{
        address_hash: "0xda8b3276cde6d768a44b9dac659faa339a41ac55",
        block_hash: "0x0b89f7f894f5d8ba941e16b61490e999a0fcaaf92dfcc70aee2ac5ddb5f243e1",
        block_number: 4448,
        data: "0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563",
        first_topic: "0xadc1e8a294f8415511303acc4a8c0c5906c7eb0bf2a71043d7f4b03b46a39130",
        fourth_topic: nil,
        index: 0,
        second_topic: "0x000000000000000000000000c15bf627accd3b054075c7880425f903106be72a",
        third_topic: "0x000000000000000000000000a59eb37750f9c8f2e11aac6700e62ef89187e4ed",
        transaction_hash: "0xf9b663b4e9b1fdc94eb27b5cfba04eb03d2f7b3fa0b24eb2e1af34f823f2b89e"
      }

  """
  def elixir_to_params(
        %{
          "address" => address_hash,
          "blockNumber" => block_number,
          "blockHash" => block_hash,
          "data" => data,
          "logIndex" => index,
          "topics" => topics,
          "transactionHash" => transaction_hash
        } = elixir
      ) do
    %{
      address_hash: address_hash,
      block_number: block_number,
      block_hash: block_hash,
      data: data,
      index: index,
      transaction_hash: transaction_hash
    }
    |> put_topics(topics)
    |> put_type(elixir)
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.

      iex> EthereumJSONRPC.Log.to_elixir(
      ...>   %{
      ...>   "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>   "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>   "blockNumber" => "0x25",
      ...>   "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>   "logIndex" => "0x0",
      ...>   "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
      ...>   "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>   "transactionIndex" => "0x0",
      ...>   "transactionLogIndex" => "0x0",
      ...>   "type" => "mined"
      ...>   }
      ...> )
      %{
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
        "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
        "blockNumber" => 37,
        "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
        "logIndex" => 0,
        "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
        "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
        "transactionIndex" => 0,
        "transactionLogIndex" => 0,
        "type" => "mined"
      }

  Geth includes a `"removed"` key

      iex> EthereumJSONRPC.Log.to_elixir(
      ...>   %{
      ...>     "address" => "0xda8b3276cde6d768a44b9dac659faa339a41ac55",
      ...>     "blockHash" => "0x0b89f7f894f5d8ba941e16b61490e999a0fcaaf92dfcc70aee2ac5ddb5f243e1",
      ...>     "blockNumber" => "0x1160",
      ...>     "data" => "0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563",
      ...>     "logIndex" => "0x0",
      ...>     "removed" => false,
      ...>     "topics" => ["0xadc1e8a294f8415511303acc4a8c0c5906c7eb0bf2a71043d7f4b03b46a39130",
      ...>      "0x000000000000000000000000c15bf627accd3b054075c7880425f903106be72a",
      ...>      "0x000000000000000000000000a59eb37750f9c8f2e11aac6700e62ef89187e4ed"],
      ...>     "transactionHash" => "0xf9b663b4e9b1fdc94eb27b5cfba04eb03d2f7b3fa0b24eb2e1af34f823f2b89e",
      ...>     "transactionIndex" => "0x0"
      ...>   }
      ...> )
      %{
        "address" => "0xda8b3276cde6d768a44b9dac659faa339a41ac55",
        "blockHash" => "0x0b89f7f894f5d8ba941e16b61490e999a0fcaaf92dfcc70aee2ac5ddb5f243e1",
        "blockNumber" => 4448,
        "data" => "0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563",
        "logIndex" => 0,
        "removed" => false,
        "topics" => ["0xadc1e8a294f8415511303acc4a8c0c5906c7eb0bf2a71043d7f4b03b46a39130",
         "0x000000000000000000000000c15bf627accd3b054075c7880425f903106be72a",
         "0x000000000000000000000000a59eb37750f9c8f2e11aac6700e62ef89187e4ed"],
        "transactionHash" => "0xf9b663b4e9b1fdc94eb27b5cfba04eb03d2f7b3fa0b24eb2e1af34f823f2b89e",
        "transactionIndex" => 0
      }

  """
  def to_elixir(log) when is_map(log) do
    Enum.into(log, %{}, &entry_to_elixir/1)
  end

  defp entry_to_elixir({key, _} = entry)
       when key in ~w(address blockHash data removed topics transactionHash type timestamp),
       do: entry

  defp entry_to_elixir({key, quantity}) when key in ~w(blockNumber logIndex transactionIndex transactionLogIndex) do
    if is_nil(quantity) do
      {key, nil}
    else
      {key, quantity_to_integer(quantity)}
    end
  end

  defp put_topics(params, topics) when is_map(params) and is_list(topics) do
    params
    |> Map.put(:first_topic, Enum.at(topics, 0))
    |> Map.put(:second_topic, Enum.at(topics, 1))
    |> Map.put(:third_topic, Enum.at(topics, 2))
    |> Map.put(:fourth_topic, Enum.at(topics, 3))
  end

  defp put_type(params, %{"type" => type}) do
    Map.put(params, :type, type)
  end

  defp put_type(params, _), do: params
end
