defmodule Explorer.Account.Api.AccessToken do
  @moduledoc """
    Module is responsible for schema for AccessTokens, they are used to get access for account data from API 
  """
  use Explorer.Schema

  alias Explorer.Accounts.Identity
  alias Ecto.Changeset
  alias Explorer.Repo

  import Ecto.Changeset

  @primary_key false
  schema "account_api_access_tokens" do
    field(:token_hash, :string, primary_key: true)
    belongs_to(:identity, Identity)

    timestamps()
  end

  def changeset(%__MODULE__{} = token, params \\ %{}) do
  end
end
