# credo:disable-for-this-file
defmodule EthereumJSONRPC.Erigon do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Parity](https://wiki.parity.io/).
  """
  require Logger
  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.Parity.{FetchedBeneficiaries, Traces}
  alias EthereumJSONRPC.Transactions

  @behaviour EthereumJSONRPC.Variant

  @impl EthereumJSONRPC.Variant
  def fetch_beneficiaries(block_numbers, json_rpc_named_arguments)
      when is_list(block_numbers) and is_list(json_rpc_named_arguments) do
    Logger.info(["### Beneficiaries started. Range starts with ", inspect(Enum.at(block_numbers, 0)), " ###"])

    id_to_params =
      block_numbers
      |> block_numbers_to_params_list()
      |> id_to_params()

    with {:ok, responses} <-
           id_to_params
           |> FetchedBeneficiaries.requests()
           |> json_rpc(json_rpc_named_arguments) do
      Logger.info(["### Beneficiaries FINISHED. Range starts with ", inspect(Enum.at(block_numbers, 0)), " ###"])
      {:ok, FetchedBeneficiaries.from_responses(responses, id_to_params)}
    end
  end

  @doc """
  Internal transaction fetching for individual transactions is no longer supported for Parity.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(_transactions_params, _json_rpc_named_arguments), do: :ignore

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the Parity trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) when is_list(block_numbers) do
    id_to_params = id_to_params(block_numbers)

    with {:ok, responses} <-
           id_to_params
           |> trace_replay_block_transactions_requests()
           |> json_rpc(json_rpc_named_arguments) do
      trace_replay_block_transactions_responses_to_internal_transactions_params(responses, id_to_params)
    end
  end

  @impl EthereumJSONRPC.Variant
  def fetch_first_trace(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    id_to_params = id_to_params(transactions_params)

    trace_replay_transaction_response =
      id_to_params
      |> trace_replay_transaction_requests()
      |> json_rpc(json_rpc_named_arguments)

    case trace_replay_transaction_response do
      {:ok, responses} ->
        case trace_replay_transaction_responses_to_first_trace_params(responses, id_to_params) do
          {:ok, [first_trace]} ->
            %{block_hash: block_hash} =
              transactions_params
              |> Enum.at(0)

            {:ok,
             [%{first_trace: first_trace, block_hash: block_hash, json_rpc_named_arguments: json_rpc_named_arguments}]}

          {:error, error} ->
            Logger.error(inspect(error))
            {:error, error}
        end

      {:error, :econnrefused} ->
        {:error, :econnrefused}

      {:error, [error]} ->
        Logger.error(inspect(error))
        {:error, error}
    end
  end

  @doc """
  Fetches the pending transactions from the Geth node.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_pending_transactions(json_rpc_named_arguments) do
    with {:ok, transaction_data} <-
           %{id: 1, method: "txpool_content", params: []} |> request() |> json_rpc(json_rpc_named_arguments) do
      transactions_params =
        transaction_data["pending"]
        |> Enum.flat_map(fn {_address, nonce_transactions_map} ->
          nonce_transactions_map
          |> Enum.map(fn {_nonce, transaction} ->
            transaction
          end)
        end)
        |> Transactions.to_elixir()
        |> Transactions.elixir_to_params()
        |> Enum.map(fn params ->
          # txpool_content always returns transaction with 0x0000000000000000000000000000000000000000000000000000000000000000 value in block hash and index is null.
          # https://github.com/ethereum/go-ethereum/issues/19897
          params
          |> Map.merge(%{:block_hash => nil, :index => nil})
        end)

      {:ok, transactions_params}
    end
  end

  defp block_numbers_to_params_list(block_numbers) when is_list(block_numbers) do
    Enum.map(block_numbers, &%{block_quantity: integer_to_quantity(&1)})
  end

  defp trace_replay_block_transactions_responses_to_internal_transactions_params(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    with {:ok, traces} <- trace_replay_block_transactions_responses_to_traces(responses, id_to_params) do
      params =
        traces
        |> Traces.to_elixir()
        |> Traces.elixir_to_params()

      {:ok, params}
    end
  end

  defp trace_replay_block_transactions_responses_to_traces(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    responses
    |> Enum.map(&trace_replay_block_transactions_response_to_traces(&1, id_to_params))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, traces}, {:ok, acc_traces_list} ->
          {:ok, [traces | acc_traces_list]}

        {:ok, _}, {:error, _} = acc_error ->
          acc_error

        {:error, reason}, {:ok, _} ->
          {:error, [reason]}

        {:error, reason}, {:error, acc_reason} ->
          {:error, [reason | acc_reason]}
      end
    )
    |> case do
      {:ok, traces_list} ->
        traces =
          traces_list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, traces}

      {:error, reverse_reasons} ->
        reasons = Enum.reverse(reverse_reasons)
        {:error, reasons}
    end
  end

  defp trace_replay_block_transactions_response_to_traces(%{id: id, result: results}, id_to_params)
       when is_list(results) and is_map(id_to_params) do
    block_number = Map.fetch!(id_to_params, id)

    annotated_traces =
      results
      |> Stream.with_index()
      |> Enum.flat_map(fn {%{"trace" => traces, "transactionHash" => transaction_hash}, transaction_index} ->
        traces
        |> Stream.with_index()
        |> Enum.map(fn {trace, index} ->
          Map.merge(trace, %{
            "blockNumber" => block_number,
            "transactionHash" => transaction_hash,
            "transactionIndex" => transaction_index,
            "index" => index
          })
        end)
      end)

    {:ok, annotated_traces}
  end

  defp trace_replay_block_transactions_response_to_traces(%{id: id, error: error}, id_to_params)
       when is_map(id_to_params) do
    block_number = Map.fetch!(id_to_params, id)

    annotated_error =
      Map.put(error, :data, %{
        "blockNumber" => block_number
      })

    {:error, annotated_error}
  end

  defp trace_replay_block_transactions_requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, block_number} ->
      trace_replay_block_transactions_request(%{id: id, block_number: block_number})
    end)
  end

  defp trace_replay_block_transactions_request(%{id: id, block_number: block_number}) do
    request(%{id: id, method: "trace_replayBlockTransactions", params: [integer_to_quantity(block_number), ["trace"]]})
  end

  def trace_replay_transaction_responses_to_first_trace_params(responses, id_to_params)
      when is_list(responses) and is_map(id_to_params) do
    with {:ok, traces} <- trace_replay_transaction_responses_to_first_trace(responses, id_to_params) do
      params =
        traces
        |> Traces.to_elixir()
        |> Traces.elixir_to_params()

      {:ok, params}
    end
  end

  defp trace_replay_transaction_responses_to_first_trace(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    responses
    |> Enum.map(&trace_replay_transaction_response_to_first_trace(&1, id_to_params))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, traces}, {:ok, acc_traces_list} ->
          {:ok, [traces | acc_traces_list]}

        {:ok, _}, {:error, _} = acc_error ->
          acc_error

        {:error, reason}, {:ok, _} ->
          {:error, [reason]}

        {:error, reason}, {:error, acc_reason} ->
          {:error, [reason | acc_reason]}
      end
    )
    |> case do
      {:ok, traces_list} ->
        traces =
          traces_list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, traces}

      {:error, reverse_reasons} ->
        reasons = Enum.reverse(reverse_reasons)
        {:error, reasons}
    end
  end

  defp trace_replay_transaction_response_to_first_trace(%{id: id, result: %{"trace" => traces}}, id_to_params)
       when is_list(traces) and is_map(id_to_params) do
    %{
      block_hash: block_hash,
      block_number: block_number,
      hash_data: transaction_hash,
      transaction_index: transaction_index
    } = Map.fetch!(id_to_params, id)

    first_trace =
      traces
      |> Stream.with_index()
      |> Enum.map(fn {trace, index} ->
        Map.merge(trace, %{
          "blockHash" => block_hash,
          "blockNumber" => block_number,
          "index" => index,
          "transactionIndex" => transaction_index,
          "transactionHash" => transaction_hash
        })
      end)
      |> Enum.filter(fn trace ->
        Map.get(trace, "index") == 0
      end)

    {:ok, first_trace}
  end

  defp trace_replay_transaction_response_to_first_trace(%{id: id, error: error}, id_to_params)
       when is_map(id_to_params) do
    %{
      block_hash: block_hash,
      block_number: block_number,
      hash_data: transaction_hash,
      transaction_index: transaction_index
    } = Map.fetch!(id_to_params, id)

    annotated_error =
      Map.put(error, :data, %{
        "blockHash" => block_hash,
        "blockNumber" => block_number,
        "transactionIndex" => transaction_index,
        "transactionHash" => transaction_hash
      })

    {:error, annotated_error}
  end

  defp trace_replay_transaction_requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{hash_data: hash_data}} ->
      trace_replay_transaction_request(%{id: id, hash_data: hash_data})
    end)
  end

  defp trace_replay_transaction_request(%{id: id, hash_data: hash_data}) do
    request(%{id: id, method: "trace_replayTransaction", params: [hash_data, ["trace"]]})
  end
end
