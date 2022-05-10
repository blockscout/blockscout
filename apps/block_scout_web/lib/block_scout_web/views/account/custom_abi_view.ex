defmodule BlockScoutWeb.Account.CustomABIView do
  use BlockScoutWeb, :view

  alias Ecto.Changeset

  def format_abi(custom_abi) do
    with {_type, abi} <- Changeset.fetch_field(custom_abi, :abi),
         false <- is_nil(abi),
         {:ok, encoded_abi} <- Poison.encode(abi) do
      encoded_abi || ""
    else
      _ ->
        ""
    end
  end
end
