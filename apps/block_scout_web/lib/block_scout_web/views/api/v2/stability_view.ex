defmodule BlockScoutWeb.API.V2.StabilityView do
  alias BlockScoutWeb.API.V2.{Helper, TokenView}
  alias Explorer.Chain.{Log, Token, Transaction}

  @api_true [api?: true]
  @transaction_fee_event_signature "0x99e7b0ba56da2819c37c047f0511fd2bf6c9b4e27b4a979a19d6da0f74be8155"
  @transaction_fee_event_abi [
    %{
      "anonymous" => false,
      "inputs" => [
        %{
          "indexed" => false,
          "internalType" => "address",
          "name" => "token",
          "type" => "address"
        },
        %{
          "indexed" => false,
          "internalType" => "uint256",
          "name" => "totalFee",
          "type" => "uint256"
        },
        %{
          "indexed" => false,
          "internalType" => "address",
          "name" => "validator",
          "type" => "address"
        },
        %{
          "indexed" => false,
          "internalType" => "uint256",
          "name" => "validatorFee",
          "type" => "uint256"
        },
        %{
          "indexed" => false,
          "internalType" => "address",
          "name" => "dapp",
          "type" => "address"
        },
        %{
          "indexed" => false,
          "internalType" => "uint256",
          "name" => "dappFee",
          "type" => "uint256"
        }
      ],
      "name" => "TransactionFee",
      "type" => "event"
    }
  ]

  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    case transaction.transaction_fee_log do
      [
        {"token", "address", false, token_address_hash},
        {"totalFee", "uint256", false, total_fee},
        {"validator", "address", false, validator_address_hash},
        {"validatorFee", "uint256", false, validator_fee},
        {"dapp", "address", false, dapp_address_hash},
        {"dappFee", "uint256", false, dapp_fee}
      ] ->
        stability_fee = %{
          "token" =>
            TokenView.render("token.json", %{
              token: transaction.transaction_fee_token,
              contract_address_hash: Transaction.bytes_to_address_hash(token_address_hash)
            }),
          "validator_address" =>
            Helper.address_with_info(nil, nil, Transaction.bytes_to_address_hash(validator_address_hash), false),
          "dapp_address" =>
            Helper.address_with_info(nil, nil, Transaction.bytes_to_address_hash(dapp_address_hash), false),
          "total_fee" => to_string(total_fee),
          "dapp_fee" => to_string(dapp_fee),
          "validator_fee" => to_string(validator_fee)
        }

        out_json
        |> Map.put("stability_fee", stability_fee)

      _ ->
        out_json
    end
  end

  def transform_transactions(transactions) do
    do_extend_with_stability_fees_info(transactions)
  end

  defp do_extend_with_stability_fees_info(transactions) when is_list(transactions) do
    {transactions, _tokens_acc} =
      Enum.map_reduce(transactions, %{}, fn transaction, tokens_acc ->
        case Log.fetch_log_by_transaction_hash_and_first_topic(
               transaction.hash,
               @transaction_fee_event_signature,
               @api_true
             ) do
          fee_log when not is_nil(fee_log) ->
            {:ok, _selector, mapping} = Log.find_and_decode(@transaction_fee_event_abi, fee_log, transaction.hash)

            [{"token", "address", false, token_address_hash}, _, _, _, _, _] = mapping

            {token, new_tokens_acc} =
              check_tokens_acc(Transaction.bytes_to_address_hash(token_address_hash), tokens_acc)

            {%Transaction{transaction | transaction_fee_log: mapping, transaction_fee_token: token}, new_tokens_acc}

          _ ->
            {transaction, tokens_acc}
        end
      end)

    transactions
  end

  defp do_extend_with_stability_fees_info(transaction) do
    [transaction] = do_extend_with_stability_fees_info([transaction])
    transaction
  end

  defp check_tokens_acc(token_address_hash, tokens_acc) do
    if Map.has_key?(tokens_acc, token_address_hash) do
      {tokens_acc[token_address_hash], tokens_acc}
    else
      token = Token.get_by_contract_address_hash(token_address_hash, @api_true)

      {token, Map.put(tokens_acc, token_address_hash, token)}
    end
  end
end
