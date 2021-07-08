defmodule BlockScoutWeb.AddressTokenView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Address

  def max_token_balance_by_latest_block_number(items) do
    items
    |> Enum.group_by(fn %{token: token} ->
      token.contract_address_hash
    end)
    |> Enum.map(fn {_, grouped_tokens} ->
      %{token: token} = Enum.max_by(grouped_tokens, fn %{block_number: block_number} -> block_number end)
      token
    end)
  end
end
