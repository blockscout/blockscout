defmodule BlockScoutWeb.API.V2.UtilsController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.Chain
  alias Explorer.Chain.{Data, SmartContract, Transaction}

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET and POST requests to `/api/v2/utils/decode-calldata`
  """
  @spec decode_calldata(Plug.Conn.t(), map()) :: {:format, :error} | Plug.Conn.t()
  def decode_calldata(conn, params) do
    with {:format, {:ok, data}} <- {:format, Data.cast(params["calldata"])},
         address_hash <- params["address_hash"] && Chain.string_to_address_hash(params["address_hash"]),
         {:format, true} <- {:format, match?({:ok, _hash}, address_hash) || is_nil(address_hash)} do
      smart_contract =
        if address_hash, do: SmartContract.address_hash_to_smart_contract(elem(address_hash, 1), @api_true)

      {decoded_input, _abi_acc, _methods_acc} =
        Transaction.decoded_input_data(
          %Transaction{input: data, to_address: %{contract_code: "", smart_contract: smart_contract}},
          @api_true
        )

      decoded_input_data = decoded_input |> TransactionView.format_decoded_input() |> TransactionView.decoded_input()

      conn
      |> json(%{result: decoded_input_data})
    end
  end
end
