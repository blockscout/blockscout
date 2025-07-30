defmodule BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation do
  @moduledoc """
    Module to interact with Transaction Interpretation Service
  """

  alias BlockScoutWeb.API.V2.{Helper, InternalTransactionView, TokenTransferView, TokenView, TransactionView}
  alias Ecto.Association.NotLoaded
  alias Explorer.{Chain, HttpClient}
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.Chain.{Data, InternalTransaction, Log, TokenTransfer, Transaction}

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation,
    only: [proxy_implementations_association: 0, proxy_implementations_smart_contracts_association: 0]

  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]
  import Explorer.Utility.Microservice, only: [base_url: 2, check_enabled: 2]
  require Logger

  @post_timeout :timer.minutes(5)
  @request_error_msg "Error while sending request to Transaction Interpretation Service"
  @api_true api?: true
  @items_limit 50
  @internal_transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
        :optional,
      [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
      [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
    }
  ]

  @doc """
  Interpret transaction or user operation
  """
  @spec interpret(Transaction.t() | map(), (Transaction.t() -> any()) | (map() -> any())) ::
          {{:error, :disabled | binary()}, integer()}
          | {:error, Jason.DecodeError.t()}
          | {:ok, any()}
  def interpret(transaction_or_map, request_builder \\ &prepare_request_body/1) do
    with {:enabled, true} <- {:enabled, enabled?()},
         {:success_transaction, true} <-
           {:success_transaction, success_transaction_or_user_op?(transaction_or_map)},
         {:cache, :no_cached_data} <-
           {:cache, try_get_cached_value(get_hash(transaction_or_map))} do
      url = interpret_url()

      body = request_builder.(transaction_or_map)

      http_post_request(url, body)
    else
      {:cache, {:ok, _response} = result} -> result
      {:success_transaction, false} -> {:ok, nil}
      {:enabled, false} -> {{:error, :disabled}, 403}
    end
  end

  @doc """
  Interpret user operation
  """
  @spec interpret_user_operation(map()) ::
          {{:error, :disabled | binary()}, integer()}
          | {:error, Jason.DecodeError.t()}
          | {:ok, any()}
  def interpret_user_operation(user_operation) do
    interpret(user_operation, &prepare_request_body_from_user_op/1)
  end

  @doc """
  Build the request body as for the transaction interpreter POST request.
  """
  @spec get_request_body(Transaction.t()) :: map()
  def get_request_body(transaction) do
    prepare_request_body(transaction)
  end

  @doc """
  Build the request body as for the transaction interpreter POST request.
  """
  @spec get_user_op_request_body(map()) :: map()
  def get_user_op_request_body(user_op) do
    prepare_request_body_from_user_op(user_op)
  end

  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HttpClient.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %{body: body, status_code: 200}} ->
        body |> Jason.decode() |> preload_template_variables()

      error ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to microservice url: #{url}, body: #{inspect(body, limit: :infinity, printable_limit: :infinity)}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {{:error, @request_error_msg}, http_response_code(error)}
    end
  end

  defp try_get_cached_value(hash) do
    with {:ok, %{body: body, status_code: 200}} <- HttpClient.get(cache_url(hash)),
         {:ok, json} <- body |> Jason.decode() do
      {:ok, json} |> preload_template_variables()
    else
      _ ->
        :no_cached_data
    end
  end

  defp http_response_code({:ok, %{status_code: status_code}}), do: status_code
  defp http_response_code(_), do: 500

  def enabled?, do: check_enabled(:block_scout_web, __MODULE__) == :ok

  defp interpret_url do
    base_url(:block_scout_web, __MODULE__) <> "/transactions/summary"
  end

  defp cache_url(hash) do
    base_url(:block_scout_web, __MODULE__) <> "/cache/#{hash}"
  end

  defp prepare_request_body(transaction) do
    transaction =
      Chain.select_repo(@api_true).preload(transaction, [
        :block,
        to_address: [:scam_badge, :names, :smart_contract],
        from_address: [:scam_badge, :names, :smart_contract],
        created_contract_address: [:scam_badge, :names, :token, :smart_contract]
      ])

    token_transfers = transaction |> fetch_token_transfers() |> Enum.reverse()
    internal_transactions = transaction |> fetch_internal_transactions() |> Enum.reverse()
    logs = transaction |> fetch_logs() |> Enum.reverse()

    [transaction_with_meta | other_elements] =
      ([transaction | token_transfers] ++ internal_transactions ++ logs)
      |> maybe_preload_metadata()

    %{
      logs: logs_with_meta,
      token_transfers: token_transfers_with_meta,
      internal_transactions: internal_transactions_with_meta
    } =
      Enum.reduce(other_elements, %{logs: [], token_transfers: [], internal_transactions: []}, fn element, acc ->
        case element do
          %InternalTransaction{} ->
            Map.put(acc, :internal_transactions, [element | acc.internal_transactions])

          %TokenTransfer{} ->
            Map.put(acc, :token_transfers, [element | acc.token_transfers])

          %Log{} ->
            Map.put(acc, :logs, [element | acc.logs])
        end
      end)

    skip_sig_provider? = false
    decoded_input = Transaction.decoded_input_data(transaction, skip_sig_provider?, @api_true)

    decoded_input_data = decoded_input |> Transaction.format_decoded_input() |> TransactionView.decoded_input()

    %{
      data: %{
        to:
          Helper.address_with_info(nil, transaction_with_meta.to_address, transaction_with_meta.to_address_hash, true),
        from:
          Helper.address_with_info(
            nil,
            transaction_with_meta.from_address,
            transaction_with_meta.from_address_hash,
            true
          ),
        hash: transaction_with_meta.hash,
        type: transaction_with_meta.type,
        value: transaction_with_meta.value,
        method: Transaction.method_name(transaction_with_meta, Transaction.format_decoded_input(decoded_input)),
        status: transaction_with_meta.status,
        transaction_types: TransactionView.transaction_types(transaction_with_meta),
        raw_input: transaction_with_meta.input,
        decoded_input: decoded_input_data,
        token_transfers: prepare_token_transfers(token_transfers_with_meta, decoded_input),
        internal_transactions: prepare_internal_transactions(internal_transactions_with_meta, transaction_with_meta)
      },
      logs_data: %{items: prepare_logs(logs_with_meta, transaction_with_meta)},
      chain_id: :block_scout_web |> Application.get_env(:chain_id) |> ExplorerHelper.parse_integer()
    }
  end

  defp fetch_token_transfers(transaction) do
    full_options =
      [
        necessity_by_association: %{
          [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
          [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    transaction.hash
    |> Chain.transaction_to_token_transfers(full_options)
    |> Chain.flat_1155_batch_token_transfers()
    |> Enum.take(@items_limit)
  end

  defp prepare_token_transfers(token_transfers, decoded_input) do
    token_transfers
    |> Enum.map(&TokenTransferView.prepare_token_transfer(&1, nil, decoded_input))
  end

  defp fetch_internal_transactions(transaction) do
    full_options =
      @internal_transaction_necessity_by_association
      |> Keyword.merge(@api_true)

    transaction.hash
    |> InternalTransaction.transaction_to_internal_transactions(full_options)
    |> Enum.take(@items_limit)
  end

  defp prepare_internal_transactions(internal_transactions, transaction) do
    internal_transactions
    |> Enum.map(&InternalTransactionView.prepare_internal_transaction(&1, transaction.block))
  end

  defp fetch_logs(transaction) do
    full_options =
      [
        necessity_by_association: %{
          [address: [:names, :smart_contract, proxy_implementations_smart_contracts_association()]] => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    transaction.hash
    |> Chain.transaction_to_logs(full_options)
    |> Enum.take(@items_limit)
  end

  defp prepare_logs(logs, transaction) do
    decoded_logs = TransactionView.decode_logs(logs, false)

    logs
    |> Enum.zip(decoded_logs)
    |> Enum.map(fn {log, decoded_log} -> TransactionView.prepare_log(log, transaction.hash, decoded_log, true) end)
  end

  defp user_op_to_logs_and_token_transfers(user_op, decoded_input) do
    log_options =
      [
        necessity_by_association: %{
          [address: [:names, :smart_contract, proxy_implementations_smart_contracts_association()]] => :optional
        },
        limit: @items_limit
      ]
      |> Keyword.merge(@api_true)

    logs = Log.user_op_to_logs(user_op, log_options)

    decoded_logs = TransactionView.decode_logs(logs, false)

    prepared_logs =
      logs
      |> Enum.zip(decoded_logs)
      |> Enum.map(fn {log, decoded_log} ->
        TransactionView.prepare_log(log, user_op["transaction_hash"], decoded_log, true)
      end)

    token_transfer_options =
      [
        necessity_by_association: %{
          [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
          [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
          :token => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    prepared_token_transfers =
      logs
      |> TokenTransfer.logs_to_token_transfers(token_transfer_options)
      |> Chain.flat_1155_batch_token_transfers()
      |> Enum.take(@items_limit)
      |> Enum.map(&TokenTransferView.prepare_token_transfer(&1, nil, decoded_input))

    {prepared_logs, prepared_token_transfers}
  end

  defp preload_template_variables({:ok, %{"success" => true, "data" => %{"summaries" => summaries} = data}}) do
    summaries_updated =
      Enum.map(summaries, fn %{"summary_template_variables" => summary_template_variables} = summary ->
        summary_template_variables_preloaded =
          Enum.reduce(summary_template_variables, %{}, fn {key, value}, acc ->
            Map.put(acc, key, preload_template_variable(value))
          end)

        Map.put(summary, "summary_template_variables", summary_template_variables_preloaded)
      end)

    {:ok, %{"success" => true, "data" => Map.put(data, "summaries", summaries_updated)}}
  end

  defp preload_template_variables(error), do: error

  # TODO: remove this once we have updated the transaction interpretation service
  defp preload_template_variable(%{"type" => "token", "value" => %{"address" => address_hash_string} = value}),
    do: %{
      "type" => "token",
      "value" => address_hash_string |> Chain.token_from_address_hash(@api_true) |> token_from_db() |> Map.merge(value)
    }

  defp preload_template_variable(%{"type" => "token", "value" => %{"address_hash" => address_hash_string} = value}),
    do: %{
      "type" => "token",
      "value" => address_hash_string |> Chain.token_from_address_hash(@api_true) |> token_from_db() |> Map.merge(value)
    }

  defp preload_template_variable(%{"type" => "address", "value" => %{"hash" => address_hash_string} = value}),
    do: %{
      "type" => "address",
      "value" =>
        address_hash_string
        |> Chain.hash_to_address(
          necessity_by_association: %{
            :names => :optional,
            :smart_contract => :optional,
            proxy_implementations_association() => :optional
          },
          api?: true
        )
        |> address_from_db()
        |> Map.merge(value)
    }

  defp preload_template_variable(other), do: other

  defp token_from_db({:error, _}), do: %{}
  defp token_from_db({:ok, token}), do: TokenView.render("token.json", %{token: token})

  defp address_from_db({:error, _}), do: %{}

  defp address_from_db({:ok, address}),
    do:
      Helper.address_with_info(
        nil,
        address,
        address.hash,
        true
      )

  defp prepare_request_body_from_user_op(user_op) do
    user_op_hash = user_op["hash"]
    user_op_call_data = user_op["execute_call_data"] || user_op["call_data"]
    user_op_from = user_op["sender"]
    user_op_to = user_op["execute_target"] || user_op["sender"]

    {mock_transaction, decoded_input, decoded_input_json} = decode_user_op_calldata(user_op_hash, user_op_call_data)

    {prepared_logs, prepared_token_transfers} = user_op_to_logs_and_token_transfers(user_op, decoded_input)

    {:ok, from_address_hash} = Chain.string_to_address_hash(user_op_from)

    {:ok, to_address_hash} = Chain.string_to_address_hash(user_op_to)

    from_address = Chain.hash_to_address(from_address_hash, [])

    to_address = Chain.hash_to_address(to_address_hash, [])

    %{
      data: %{
        to: Helper.address_with_info(nil, to_address, to_address_hash, true),
        from: Helper.address_with_info(nil, from_address, from_address_hash, true),
        hash: user_op_hash,
        type: 0,
        value: "0",
        method: Transaction.method_name(mock_transaction, Transaction.format_decoded_input(decoded_input), true),
        status: user_op["status"],
        actions: [],
        transaction_types: [],
        raw_input: user_op_call_data,
        decoded_input: decoded_input_json,
        token_transfers: prepared_token_transfers
      },
      logs_data: %{items: prepared_logs},
      chain_id: :block_scout_web |> Application.get_env(:chain_id) |> ExplorerHelper.parse_integer()
    }
  end

  @doc """
  Decodes user_op["call_data"] and return {mock_transaction, decoded_input, decoded_input_json}
  """
  @spec decode_user_op_calldata(binary(), binary() | nil) :: {Transaction.t(), tuple(), map()} | {nil, nil, nil}
  def decode_user_op_calldata(_user_op_hash, nil), do: {nil, nil, nil}

  def decode_user_op_calldata(user_op_hash, call_data) do
    {:ok, input} = Data.cast(call_data)

    {:ok, op_hash} = Chain.string_to_full_hash(user_op_hash)

    mock_transaction = %Transaction{
      to_address: %NotLoaded{},
      input: input,
      hash: op_hash
    }

    skip_sig_provider? = false

    decoded_input = Transaction.decoded_input_data(mock_transaction, skip_sig_provider?, @api_true)

    {mock_transaction, decoded_input,
     decoded_input |> Transaction.format_decoded_input() |> TransactionView.decoded_input()}
  end

  defp get_hash(%{hash: hash}), do: hash
  defp get_hash(%{"hash" => hash}), do: hash

  defp success_transaction_or_user_op?(%Transaction{status: :ok}), do: true
  defp success_transaction_or_user_op?(%{"hash" => _hash}), do: true
  defp success_transaction_or_user_op?(_), do: false
end
