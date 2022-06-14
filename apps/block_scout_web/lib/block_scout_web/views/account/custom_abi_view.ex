defmodule BlockScoutWeb.Account.CustomABIView do
  use BlockScoutWeb, :view

  alias Ecto.Changeset

  def format_abi(custom_abi) do
    with {_type, abi} <- Changeset.fetch_field(custom_abi, :abi),
         false <- is_nil(abi),
         {:binary, false} <- {:binary, is_binary(abi)},
         {:ok, encoded_abi} <- Poison.encode(abi) do
      encoded_abi
    else
      {:binary, true} ->
        {_type, abi} = Changeset.fetch_field(custom_abi, :abi)
        abi

      _ ->
        ""
    end
  end
end
