defmodule Explorer.InternalTransactionImporter do
  @moduledoc "Imports a transaction's internal transactions given its hash."

  import Ecto.Query

  alias Explorer.Address
  alias Explorer.EthereumexExtensions
  alias Explorer.InternalTransaction
  alias Explorer.Repo
  alias Explorer.Transaction

  def import(hash) do
    transaction = find_transaction(hash)
    hash
    |> download_trace
    |> extract_attrs
    |> persist_internal_transactions(transaction)
  end

  defp download_trace(hash) do
    EthereumexExtensions.trace_transaction(hash)
  end

  defp find_transaction(hash) do
    query = from t in Transaction,
      where: fragment("lower(?)", t.hash) == ^String.downcase(hash),
      limit: 1
    Repo.one!(query)
  end

  defp extract_attrs(attrs) do
    trace = attrs["trace"]
    trace |> Enum.with_index() |> Enum.map(&extract_trace/1)
  end

  def extract_trace({trace, index}) do
    %{
      index: index,
      call_type: trace["action"]["callType"] || trace["type"],
      to_address_id: trace |> to_address() |> address_id(),
      from_address_id: trace |> from_address() |> address_id(),
      trace_address: trace["traceAddress"],
      value: trace["action"]["value"] |> decode_integer_field,
      gas: trace["action"]["gas"] |> decode_integer_field,
      gas_used: trace["result"]["gasUsed"] |> decode_integer_field,
      input: trace["action"]["input"],
      output: trace["result"]["output"],
    }
  end

  defp to_address(%{"action" => %{"to" => address}})
  when not is_nil(address), do: address

  defp to_address(%{"result" => %{"address" => address}}), do: address

  defp from_address(%{"action" => %{"from" => address}}), do: address

  defp persist_internal_transactions(traces, transaction) do
    Enum.map(traces, fn(trace) ->
      trace = Map.merge(trace, %{transaction_id: transaction.id})
      %InternalTransaction{}
      |> InternalTransaction.changeset(trace)
      |> Repo.insert()
    end)
  end

  defp decode_integer_field(hex) do
    {"0x", base_16} = String.split_at(hex, 2)
    String.to_integer(base_16, 16)
  end

  defp address_id(hash) do
    Address.find_or_create_by_hash(hash).id
  end
end
