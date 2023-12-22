defmodule BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation do
  @moduledoc """
    Module to interact with Transaction Interpretation Service
  """

  alias BlockScoutWeb.API.V2.{Helper, TokenView, TransactionView}
  alias Explorer.Chain
  alias Explorer.Chain.Transaction
  alias HTTPoison.Response

  import Explorer.Utility.Microservice, only: [base_url: 2]

  require Logger

  @post_timeout :timer.minutes(5)
  @request_error_msg "Error while sending request to Transaction Interpretation Service"
  @api_true api?: true
  @items_limit 50

  @spec interpret(Transaction.t()) :: {:error, :disabled | binary | Jason.DecodeError.t()} | {:ok, any}
  def interpret(transaction) do
    if enabled?() do
      url = interpret_url()

      body = prepare_request_body(transaction)

      http_post_request(url, body)
    else
      {:error, :disabled}
    end
  end

  def get_request_body(transaction) do
    prepare_request_body(transaction)
  end

  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %Response{body: body, status_code: 200}} ->
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
    transaction =
      Chain.select_repo(@api_true).preload(transaction, [
        :transaction_actions,
        to_address: [:names, :smart_contract],
        from_address: [:names, :smart_contract],
        created_contract_address: [:names, :token, :smart_contract]
      ])

    skip_sig_provider? = false
    {decoded_input, _abi_acc, _methods_acc} = Transaction.decoded_input_data(transaction, skip_sig_provider?, @api_true)

    decoded_input_data = decoded_input |> TransactionView.format_decoded_input() |> TransactionView.decoded_input()

    %{
      data: %{
        to: Helper.address_with_info(nil, transaction.to_address, transaction.to_address_hash, true),
        from:
          Helper.address_with_info(
            nil,
            transaction.from_address,
            transaction.from_address_hash,
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
        token_transfers: prepare_token_transfers(transaction, decoded_input)
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

  defp preload_template_variable(%{"type" => "token", "value" => %{"address" => address_hash_string} = value}),
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
          [
            necessity_by_association: %{
              :names => :optional,
              :smart_contract => :optional
            },
            api?: true
          ],
          false
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
end
