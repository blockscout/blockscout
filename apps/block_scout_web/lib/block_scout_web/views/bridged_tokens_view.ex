defmodule BlockScoutWeb.BridgedTokensView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{BridgedToken, CurrencyHelper, Token}

  @doc """
  Calculates capitalization of the bridged token in USD.
  """
  @spec bridged_token_usd_cap(BridgedToken.t(), Token.t()) :: String.t()
  def bridged_token_usd_cap(bridged_token, token) do
    usd_cap =
      if bridged_token.custom_cap do
        bridged_token.custom_cap
      else
        if bridged_token.exchange_rate && token.total_supply do
          Decimal.mult(bridged_token.exchange_rate, CurrencyHelper.divide_decimals(token.total_supply, token.decimals))
        else
          Decimal.new(0)
        end
      end

    usd_cap |> Decimal.to_float() |> :erlang.float_to_binary([:compact, decimals: 20])
  end
end
