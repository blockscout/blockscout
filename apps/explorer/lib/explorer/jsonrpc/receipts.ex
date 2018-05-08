defmodule Explorer.JSONRPC.Receipts do
  @moduledoc """
  Receipts format as returned by
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt) from batch
  requests.
  """

  import Explorer.JSONRPC, only: [config: 1, json_rpc: 2]

  alias Explorer.JSONRPC.{Logs, Receipt}

  @type elixir :: [Receipt.elixir()]
  @type t :: [Receipt.t()]

  @spec elixir_to_logs(elixir) :: Logs.elixir()
  def elixir_to_logs(elixir) when is_list(elixir) do
    Enum.flat_map(elixir, &Receipt.elixir_to_logs/1)
  end

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
