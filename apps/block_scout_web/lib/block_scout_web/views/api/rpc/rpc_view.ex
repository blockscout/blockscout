# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.RPC.RPCView do
  use BlockScoutWeb, :view

  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  def render("show.json", %{data: data}) do
    %{
      "status" => "1",
      "message" => "OK",
      "result" => data
    }
  end

  def render("pending_internal_transaction.json", %{data: data, message: message}) do
    %{
      "status" => "2",
      "message" => message,
      "result" => data
    }
  end

  def render("error.json", %{error: message} = assigns) do
    %{
      "status" => "0",
      "message" => message,
      "result" => Map.get(assigns, :data)
    }
  end

  @doc """
  Rollup L1 data fee fields, named as in Etherscan's API, to merge into a transaction-like response.

  `entity` is a transaction (a full or partial `Explorer.Chain.Transaction` struct, or a select map) or an
  internal transaction map carrying the parent transaction's L1 fee columns (see
  `Explorer.Etherscan.l1_fee_transaction_fields/0`). Fields are emitted only on chain types storing an L1
  fee: `L1FeesPaid` on Optimism and Scroll, plus `L1GasUsed`, `L1GasPrice` and `L1FeeScalar` on Optimism.
  `L1FeesPaid` is `"0"` when the fee is unknown (e.g. deposit transactions); the Optimism breakdown fields
  are `""` when absent, like `gasPrice`. Returns an empty map on other chain types.
  """
  @spec l1_fee_fields(map()) :: %{optional(String.t()) => String.t()}
  case @chain_type do
    :optimism ->
      def l1_fee_fields(entity) do
        %{
          "L1FeesPaid" => l1_fee_to_string(Map.get(entity, :l1_fee)),
          "L1GasUsed" => optional_decimal_to_string(Map.get(entity, :l1_gas_used)),
          "L1GasPrice" => optional_wei_to_string(Map.get(entity, :l1_gas_price)),
          "L1FeeScalar" => optional_decimal_to_string(Map.get(entity, :l1_fee_scalar))
        }
      end

      defp optional_wei_to_string(nil), do: ""
      defp optional_wei_to_string(%Explorer.Chain.Wei{value: value}), do: Decimal.to_string(value, :normal)

      defp optional_decimal_to_string(nil), do: ""
      defp optional_decimal_to_string(%Decimal{} = value), do: Decimal.to_string(value, :normal)

    :scroll ->
      def l1_fee_fields(entity) do
        %{"L1FeesPaid" => l1_fee_to_string(Map.get(entity, :l1_fee))}
      end

    _ ->
      def l1_fee_fields(_entity), do: %{}
  end

  if @chain_type in [:optimism, :scroll] do
    defp l1_fee_to_string(nil), do: "0"
    defp l1_fee_to_string(%Explorer.Chain.Wei{value: value}), do: Decimal.to_string(value, :normal)
  end
end
