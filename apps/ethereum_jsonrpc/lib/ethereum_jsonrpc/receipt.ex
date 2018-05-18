defmodule EthereumJSONRPC.Receipt do
  @moduledoc """
  Receipts format as returned by
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt).
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias Explorer.Chain.Receipt.Status
  alias EthereumJSONRPC
  alias EthereumJSONRPC.Logs

  @type elixir :: %{String.t() => String.t() | non_neg_integer}

  @typedoc """
   * `"contractAddress"` - The contract `t:EthereumJSONRPC.address/0` created, if the transaction was a contract
     creation, otherwise `nil`.
   * `"blockHash"` - `t:EthereumJSONRPC.hash/0` of the block where `"transactionHash"` was in.
   * `"blockNumber"` - The block number `t:EthereumJSONRPC.quanity/0`.
   * `"cumulativeGasUsed"` - `t:EthereumJSONRPC.quantity/0` of gas used when this transaction was executed in the
     block.
   * `"gasUsed"` - `t:EthereumJSONRPC.quantity/0` of gas used by this specific transaction alone.
   * `"logs"` - `t:list/0` of log objects, which this transaction generated.
   * `"logsBloom"` - `t:EthereumJSONRPC.data/0` of 256 Bytes for
     [Bloom filter](https://en.wikipedia.org/wiki/Bloom_filter) for light clients to quickly retrieve related logs.
   * `"root"` - `t:EthereumJSONRPC.hash/0`  of post-transaction stateroot (pre-Byzantium)
   * `"status"` - `t:EthereumJSONRPC.quantity/0` of either 1 (success) or 0 (failure) (post-Byzantium)
   * `"transactionHash"` - `t:EthereumJSONRPC.hash/0` the transaction.
   * `"transactionIndex"` - `t:EthereumJSONRPC.quantity/0` for the transaction index in the block.
  """
  @type t :: %{
          String.t() =>
            EthereumJSONRPC.address()
            | EthereumJSONRPC.data()
            | EthereumJSONRPC.hash()
            | EthereumJSONRPC.quantity()
            | list
            | nil
        }

  @doc """
  Get `t:EthereumJSONRPC.Logs.elixir/0` from `t:elixir/0`
  """
  @spec elixir_to_logs(elixir) :: Logs.elixir()
  def elixir_to_logs(%{"logs" => logs}), do: logs

  @doc """
  Converts `t:elixir/0` format to params used in `Explorer.Chain`.

      iex> EthereumJSONRPC.Receipt.elixir_to_params(
      ...>   %{
      ...>     "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     "blockNumber" => 34,
      ...>     "contractAddress" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>     "cumulativeGasUsed" => 269607,
      ...>     "gasUsed" => 269607,
      ...>     "logs" => [],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => :ok,
      ...>     "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> )
      %{
        cumulative_gas_used: 269607,
        gas_used: 269607,
        status: :ok,
        transaction_hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
        transaction_index: 0
      }

  """

  @spec elixir_to_params(elixir) :: %{
          cumulative_gas_used: non_neg_integer,
	  gas_used: non_neg_integer,
          status: Status.t(),
          transaction_hash: String.t(),
          transaction_index: non_neg_integer()
        }
  def elixir_to_params(%{
        "cumulativeGasUsed" => cumulative_gas_used,
        "gasUsed" => gas_used,
        "transactionHash" => transaction_hash,
        "transactionIndex" => transaction_index
      }) do
    %{
      cumulative_gas_used: cumulative_gas_used,
      gas_used: gas_used,
      status: 1,
      transaction_hash: transaction_hash,
      transaction_index: transaction_index
    }
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.

      iex> EthereumJSONRPC.Receipt.to_elixir(
      ...>   %{
      ...>     "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     "blockNumber" => "0x22",
      ...>     "contractAddress" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>     "cumulativeGasUsed" => "0x41d27",
      ...>     "gasUsed" => "0x41d27",
      ...>     "logs" => [],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => "0x1",
      ...>     "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     "transactionIndex" => "0x0"
      ...>   }
      ...> )
      %{
        "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
        "blockNumber" => 34,
        "contractAddress" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
        "cumulativeGasUsed" => 269607,
        "gasUsed" => 269607,
        "logs" => [],
        "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "root" => nil,
        "status" => :ok,
        "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
        "transactionIndex" => 0
      }

  """
  @spec to_elixir(t) :: elixir
  def to_elixir(receipt) when is_map(receipt) do
    Enum.into(receipt, %{}, &entry_to_elixir/1)
  end

  # double check that no new keys are being missed by requiring explicit match for passthrough
  # `t:EthereumJSONRPC.address/0` and `t:EthereumJSONRPC.hash/0` pass through as `Explorer.Chain` can verify correct
  # hash format

  # add from, to for ethereum

  defp entry_to_elixir({key, _} = entry) when key in ~w(blockHash from to contractAddress logsBloom root transactionHash),
    do: entry

  defp entry_to_elixir({key, quantity}) when key in ~w(blockNumber cumulativeGasUsed gasUsed transactionIndex) do
    {key, quantity_to_integer(quantity)}
  end

  defp entry_to_elixir({"logs" = key, logs}) do
    {key, Logs.to_elixir(logs)}
  end

  defp entry_to_elixir({"status" = key, status}) do
    elixir_status =
      case status do
        "0x0" -> :error
        "0x1" -> :ok
      end

    {key, elixir_status}
  end
end
