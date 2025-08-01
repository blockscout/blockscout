defmodule BlockScoutWeb.API.V2.SuaveView do
  alias BlockScoutWeb.API.V2.Helper, as: APIHelper
  alias BlockScoutWeb.API.V2.TransactionView

  alias Explorer.Helper, as: ExplorerHelper

  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.{Address, Hash, Transaction}

  @suave_bid_event "0x83481d5b04dea534715acad673a8177a46fc93882760f36bdc16ccac439d504e"

  def extend_transaction_json_response(
        %Transaction{} = transaction,
        out_json,
        single_transaction?,
        conn,
        watchlist_names
      ) do
    if is_nil(Map.get(transaction, :execution_node_hash)) do
      out_json
    else
      wrapped_to_address = Map.get(transaction, :wrapped_to_address)
      wrapped_to_address_hash = Map.get(transaction, :wrapped_to_address_hash)
      wrapped_input = Map.get(transaction, :wrapped_input)
      wrapped_hash = Map.get(transaction, :wrapped_hash)
      execution_node = Map.get(transaction, :execution_node)
      execution_node_hash = Map.get(transaction, :execution_node_hash)
      wrapped_type = Map.get(transaction, :wrapped_type)
      wrapped_nonce = Map.get(transaction, :wrapped_nonce)
      wrapped_gas = Map.get(transaction, :wrapped_gas)
      wrapped_gas_price = Map.get(transaction, :wrapped_gas_price)
      wrapped_max_priority_fee_per_gas = Map.get(transaction, :wrapped_max_priority_fee_per_gas)
      wrapped_max_fee_per_gas = Map.get(transaction, :wrapped_max_fee_per_gas)
      wrapped_value = Map.get(transaction, :wrapped_value)

      [wrapped_decoded_input] =
        Transaction.decode_transactions(
          [
            %Transaction{
              to_address: wrapped_to_address,
              input: wrapped_input,
              hash: wrapped_hash
            }
          ],
          false,
          api?: true
        )

      out_json
      |> Map.put("allowed_peekers", suave_parse_allowed_peekers(transaction.logs))
      |> Map.put(
        "execution_node",
        APIHelper.address_with_info(
          conn,
          execution_node,
          execution_node_hash,
          single_transaction?,
          watchlist_names
        )
      )
      |> Map.put("wrapped", %{
        "type" => wrapped_type,
        "nonce" => wrapped_nonce,
        "to" =>
          APIHelper.address_with_info(
            conn,
            wrapped_to_address,
            wrapped_to_address_hash,
            single_transaction?,
            watchlist_names
          ),
        "gas_limit" => wrapped_gas,
        "gas_price" => wrapped_gas_price,
        "fee" =>
          TransactionView.format_fee(
            Transaction.fee(
              %Transaction{gas: wrapped_gas, gas_price: wrapped_gas_price, gas_used: nil},
              :wei
            )
          ),
        "max_priority_fee_per_gas" => wrapped_max_priority_fee_per_gas,
        "max_fee_per_gas" => wrapped_max_fee_per_gas,
        "value" => wrapped_value,
        "hash" => wrapped_hash,
        "method" =>
          Transaction.method_name(
            %Transaction{to_address: wrapped_to_address, input: wrapped_input},
            wrapped_decoded_input
          ),
        "decoded_input" => TransactionView.decoded_input(wrapped_decoded_input),
        "raw_input" => wrapped_input
      })
    end
  end

  # @spec suave_parse_allowed_peekers(Ecto.Schema.has_many(Log.t())) :: [String.t()]
  defp suave_parse_allowed_peekers(%NotLoaded{}), do: []

  defp suave_parse_allowed_peekers(logs) do
    suave_bid_contracts =
      Application.get_all_env(:explorer)[Transaction][:suave_bid_contracts]
      |> String.split(",")
      |> Enum.map(fn sbc -> String.downcase(String.trim(sbc)) end)

    bid_event =
      Enum.find(logs, fn log ->
        sanitize_log_first_topic(log.first_topic) == @suave_bid_event &&
          Enum.member?(suave_bid_contracts, String.downcase(Hash.to_string(log.address_hash)))
      end)

    if is_nil(bid_event) do
      []
    else
      [_bid_id, _decryption_condition, allowed_peekers] =
        ExplorerHelper.decode_data(bid_event.data, [{:bytes, 16}, {:uint, 64}, {:array, :address}])

      Enum.map(allowed_peekers, fn peeker ->
        Address.checksum(peeker)
      end)
    end
  end

  defp sanitize_log_first_topic(first_topic) do
    if is_nil(first_topic) do
      ""
    else
      sanitized =
        if is_binary(first_topic) do
          first_topic
        else
          Hash.to_string(first_topic)
        end

      String.downcase(sanitized)
    end
  end
end
