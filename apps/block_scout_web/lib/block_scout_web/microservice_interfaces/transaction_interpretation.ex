defmodule BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation do
  @moduledoc """
    Module to interact with Transaction Interpretation Service
  """

  alias BlockScoutWeb.API.V2.{Helper, TransactionView}
  alias Explorer.Chain
  alias Explorer.Chain.Transaction
  alias HTTPoison.Response

  import Explorer.Utility.Microservice, only: [base_url: 2]

  require Logger

  @post_timeout :timer.minutes(5)
  @request_error_msg "Error while sending request to Transaction Interpretation Service"
  @api_true api?: true
  @items_limit 50

  @spec interpret(any) :: {:error, :disabled | binary} | {:ok, any}
  def interpret(transaction) do
    if enabled?() do
      url = interpret_url()

      body = prepare_request_body(transaction)

      http_post_request(url, body)
    else
      {:error, :disabled}
    end
  end

  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, body}

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
        {:error, @request_error_msg}
    end
  end

  defp config do
    Application.get_env(:block_scout_web, __MODULE__)
  end

  def enabled?, do: config()[:enabled]

  defp interpret_url do
    base_url(:block_scout_web, __MODULE__) <> "/transactions/summary"
  end

  defp prepare_request_body(transaction) do
    preloaded_transaction =
      Chain.select_repo(@api_true).preload(transaction, [
        :transaction_actions,
        to_address: [:names, :smart_contract],
        from_address: [:names, :smart_contract],
        created_contract_address: [:names, :token, :smart_contract]
      ])

    skip_sig_provider? = true
    {decoded_input, _abi_acc, _methods_acc} = Transaction.decoded_input_data(transaction, skip_sig_provider?, @api_true)

    decoded_input_data = TransactionView.decoded_input(decoded_input)

    %{
      data: %{
        to:
          Helper.address_with_info(nil, preloaded_transaction.to_address, preloaded_transaction.to_address_hash, true),
        from:
          Helper.address_with_info(
            nil,
            preloaded_transaction.from_address,
            preloaded_transaction.from_address_hash,
            true
          ),
        hash: transaction.hash,
        type: transaction.type,
        value: transaction.value,
        method: TransactionView.method_name(transaction, decoded_input),
        status: transaction.status,
        actions: TransactionView.transaction_actions(transaction.transaction_actions),
        tx_types: TransactionView.tx_types(transaction),
        raw_input: transaction.input,
        decoded_input: decoded_input_data,
        token_transfers: prepare_token_transfers(preloaded_transaction, decoded_input)
      },
      logs_data: %{items: prepare_logs(transaction)}
    }
  end

  defp prepare_token_transfers(transaction, decoded_input) do
    full_options =
      [
        necessity_by_association: %{
          [from_address: :smart_contract] => :optional,
          [to_address: :smart_contract] => :optional,
          [from_address: :names] => :optional,
          [to_address: :names] => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    transaction.hash
    |> Chain.transaction_to_token_transfers(full_options)
    |> Chain.flat_1155_batch_token_transfers()
    |> Enum.take(@items_limit)
    |> Enum.map(&TransactionView.prepare_token_transfer(&1, nil, decoded_input))
  end

  defp prepare_logs(transaction) do
    full_options =
      [
        necessity_by_association: %{
          [address: :names] => :optional,
          [address: :smart_contract] => :optional,
          address: :optional
        }
      ]
      |> Keyword.merge(@api_true)

    logs =
      transaction.hash
      |> Chain.transaction_to_logs(full_options)
      |> Enum.take(@items_limit)

    decoded_logs = TransactionView.decode_logs(logs, true)

    logs
    |> Enum.zip(decoded_logs)
    |> Enum.map(fn {log, decoded_log} -> TransactionView.prepare_log(log, transaction.hash, decoded_log, true) end)
  end
end
