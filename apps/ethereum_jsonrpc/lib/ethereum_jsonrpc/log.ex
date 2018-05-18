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
   * `"logIndex"` - `t:EthereumJSONRPC.quantity/0` of the event index positon in the block.
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
        data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
        first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
        fourth_topic: nil,
        index: 0,
        second_topic: nil,
        third_topic: nil,
        transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
        type: "mined"
      }

  """
  def elixir_to_params(%{
        "address" => address_hash,
        "data" => data,
        "logIndex" => index,
        "topics" => topics,
        "transactionHash" => transaction_hash,
        "blockHash" => block_hash,
        "blockNumber" => block_number,
        "removed" => removed,
        "transactionIndex" => transaction_index
      }) do
    %{
      address_hash: address_hash,
      data: data,
      index: index,
      transaction_hash: transaction_hash,
      type: "mined",
      block_hash: block_hash,
      block_number: block_number,
      removed: removed,
      transaction_index: transaction_index
    }
    |> put_topics(topics)
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

  """
  def to_elixir(log) when is_map(log) do
    Enum.into(log, %{}, &entry_to_elixir/1)
  end

  defp entry_to_elixir({key, _} = entry) when key in ~w(address blockHash contractAddress from to root removed logsBloom data topics transactionHash type), do: entry

  defp entry_to_elixir({key, quantity}) when key in ~w(blockNumber cumulativeGasUsed gasUsed logIndex transactionIndex transactionLogIndex) do
    {key, quantity_to_integer(quantity)}
  end

  defp put_topics(params, topics) when is_map(params) and is_list(topics) do
    params
    |> Map.put(:first_topic, Enum.at(topics, 0))
    |> Map.put(:second_topic, Enum.at(topics, 1))
    |> Map.put(:third_topic, Enum.at(topics, 2))
    |> Map.put(:fourth_topic, Enum.at(topics, 3))
  end
end
