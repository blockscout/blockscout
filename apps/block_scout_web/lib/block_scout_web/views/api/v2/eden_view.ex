# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.EdenView do
  @moduledoc """
  View functions for rendering Eden-related data in JSON format.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :eden do
    alias BlockScoutWeb.API.V2.Helper, as: APIHelper
    alias Explorer.Chain.{Address, Transaction}

    @doc """
    Extends the JSON output with the Eden-specific transaction fields: the sponsor which pays for
    the transaction and the ordered list of the calls batched in a sponsored transaction.

    Both fields are `nil` for the regular (non-sponsored) transactions. As with the token transfers,
    the calls are rendered for a single transaction only to keep the list responses small.

    ## Parameters
    - `out_json`: A map defining the output JSON which will be extended.
    - `transaction`: The transaction structure.
    - `single_transaction?`: A boolean indicating if it is a single transaction.
    - `conn`: A connection to use for the address tags lookup.
    - `watchlist_names`: A map of the cached watchlist names.

    ## Returns
    - A map extended with the data related to Eden.
    """
    @spec extend_transaction_json_response(map(), Transaction.t(), boolean(), Plug.Conn.t() | nil, map() | nil) ::
            map()
    def extend_transaction_json_response(
          out_json,
          %Transaction{} = transaction,
          single_transaction?,
          conn,
          watchlist_names
        ) do
      out_json
      |> Map.put(
        "fee_payer",
        APIHelper.address_with_info(
          single_transaction? && conn,
          transaction.fee_payer_address,
          transaction.fee_payer_address_hash,
          single_transaction?,
          watchlist_names
        )
      )
      |> Map.put("calls", prepare_calls(transaction.calls, single_transaction?))
    end

    @doc """
    Extends the body of the transaction interpretation request with the Eden-specific fields.

    Without the calls the service has no way to tell that the transaction is a batch: its `to` and
    `value` are the compatibility fields derived from the first call and from the sum of all the
    calls, and the batched calls produce no internal transactions.

    ## Parameters
    - `data`: A map defining the `data` part of the request body which will be extended.
    - `transaction`: The transaction structure.

    ## Returns
    - A map extended with the data related to Eden.
    """
    @spec extend_transaction_interpretation_request(map(), Transaction.t()) :: map()
    def extend_transaction_interpretation_request(data, %Transaction{} = transaction) do
      data
      |> Map.put(
        :fee_payer,
        APIHelper.address_with_info(nil, transaction.fee_payer_address, transaction.fee_payer_address_hash, false)
      )
      |> Map.put(:calls, prepare_calls(transaction.calls))
    end

    @spec prepare_calls(term(), boolean()) :: [map()] | nil
    defp prepare_calls(calls, true = _single_transaction?), do: prepare_calls(calls)

    defp prepare_calls(_calls, _single_transaction?), do: nil

    @spec prepare_calls(term()) :: [map()] | nil
    defp prepare_calls(calls) when is_list(calls), do: Enum.map(calls, &prepare_call/1)

    defp prepare_calls(_calls), do: nil

    # A call is stored as it comes from the JSON RPC response: `to` is a plain address string which
    # is `nil` for a contract creation call, `value` is an integer and `input` is a hex string.
    # Renders it the way the rest of the API v2 renders those types: a checksummed address and a
    # stringified value.
    @spec prepare_call(map()) :: map()
    defp prepare_call(call) do
      %{
        "to" => call |> Map.get("to") |> checksum_or_nil(),
        "value" => (Map.get(call, "value") || 0) |> to_string(),
        "input" => Map.get(call, "input") || "0x"
      }
    end

    @spec checksum_or_nil(String.t() | nil) :: String.t() | nil
    defp checksum_or_nil(nil), do: nil
    defp checksum_or_nil(address_hash_string), do: Address.checksum(address_hash_string)
  else
    def extend_transaction_json_response(out_json, _, _, _, _),
      do: out_json

    def extend_transaction_interpretation_request(data, _),
      do: data
  end
end
