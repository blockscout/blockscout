defmodule EthereumJSONRPC.Receipts do
  @moduledoc """
  Receipts format as returned by
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt) from batch
  requests.
  """

  import EthereumJSONRPC, only: [config: 1, json_rpc: 2]

  alias EthereumJSONRPC.{Logs, Receipt}

  @type elixir :: [Receipt.elixir()]
  @type t :: [Receipt.t()]

  @doc """
  Extracts logs from `t:elixir/0`

      iex> EthereumJSONRPC.Receipts.elixir_to_logs([
      ...>   %{
      ...>     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     "blockNumber" => 37,
      ...>     "contractAddress" => nil,
      ...>     "cumulativeGasUsed" => 50450,
      ...>     "gasUsed" => 50450,
      ...>     "logs" => [
      ...>       %{
      ...>         "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         "blockNumber" => 37,
      ...>         "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         "logIndex" => 0,
      ...>         "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
      ...>         "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         "transactionIndex" => 0,
      ...>         "transactionLogIndex" => 0,
      ...>         "type" => "mined"
      ...>       }
      ...>     ],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => :ok,
      ...>     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> ])
      [
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
      ]

  """
  @spec elixir_to_logs(elixir) :: Logs.elixir()
  def elixir_to_logs(elixir) when is_list(elixir) do
    Enum.flat_map(elixir, &Receipt.elixir_to_logs/1)
  end

  @doc """
  Converts each element of `t:elixir/0` to params used by `Explorer.Chain.Receipt.changeset/2`.

      iex> EthereumJSONRPC.Receipts.elixir_to_params([
      ...>   %{
      ...>     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     "blockNumber" => 37,
      ...>     "contractAddress" => nil,
      ...>     "cumulativeGasUsed" => 50450,
      ...>     "gasUsed" => 50450,
      ...>     "logs" => [
      ...>       %{
      ...>         "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         "blockNumber" => 37,
      ...>         "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         "logIndex" => 0,
      ...>         "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
      ...>         "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         "transactionIndex" => 0,
      ...>         "transactionLogIndex" => 0,
      ...>         "type" => "mined"
      ...>       }
      ...>     ],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => :ok,
      ...>     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> ])
      [
        %{
          cumulative_gas_used: 50450,
          gas_used: 50450,
          status: :ok,
          transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
          transaction_index: 0
        }
      ]

  """
  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Receipt.elixir_to_params/1)
  end

  def fetch(hashes) when is_list(hashes) do
    hashes
    |> Enum.map(&hash_to_json/1)
    |> json_rpc(config(:url))
    |> case do
      {:ok, responses} ->
        elixir_receipts =
          responses
          |> responses_to_receipts()
          |> to_elixir()
        elixir_logs = elixir_to_logs(elixir_receipts)
        receipts = elixir_to_params(elixir_receipts)
        logs = Logs.elixir_to_params(elixir_logs)

        {:ok, %{logs: logs, receipts: receipts}}

      {:error, _reason} = err ->
        err
    end
  end

  @doc """
  Converts stringly typed fields to native Elixir types.

      iex> EthereumJSONRPC.Receipts.to_elixir([
      ...>   %{
      ...>     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     "blockNumber" => "0x25",
      ...>     "contractAddress" => nil,
      ...>     "cumulativeGasUsed" => "0xc512",
      ...>     "gasUsed" => "0xc512",
      ...>     "logs" => [
      ...>       %{
      ...>         "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         "blockNumber" => "0x25",
      ...>         "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         "logIndex" => "0x0",
      ...>         "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
      ...>         "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         "transactionIndex" => "0x0",
      ...>         "transactionLogIndex" => "0x0",
      ...>         "type" => "mined"
      ...>       }
      ...>     ],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => "0x1",
      ...>     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>     "transactionIndex" => "0x0"
      ...>   }
      ...> ])
      [
        %{
          "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
          "blockNumber" => 37,
          "contractAddress" => nil,
          "cumulativeGasUsed" => 50450,
          "gasUsed" => 50450,
          "logs" => [
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
          ],
          "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
          "root" => nil,
          "status" => :ok,
          "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
          "transactionIndex" => 0
        }
      ]

  """
  @spec to_elixir(t) :: elixir
  def to_elixir(receipts) when is_list(receipts) do
    Enum.map(receipts, &Receipt.to_elixir/1)
  end

  defp hash_to_json(hash) do
    %{
      "id" => hash,
      "jsonrpc" => "2.0",
      "method" => "eth_getTransactionReceipt",
      "params" => [hash]
    }
  end

  defp response_to_receipt(%{"result" => receipt}), do: receipt

  defp responses_to_receipts(responses) when is_list(responses) do
    Enum.map(responses, &response_to_receipt/1)
  end
end
