defmodule Explorer.Chain.BridgedToken do
  @moduledoc """
  Represents a bridged token.

  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.{BridgedToken, Hash, Token}

  @typedoc """
  * `foreign_chain_id` - chain ID of a foreign token
  * `foreign_token_contract_address_hash` - Foreign token's contract hash
  * `home_token_contract_address` - The `t:Address.t/0` of the home token's contract
  * `home_token_contract_address_hash` - Home token's contract hash foreign key
  """
  @type t :: %BridgedToken{
          foreign_chain_id: Decimal.t(),
          foreign_token_contract_address_hash: Hash.Address.t(),
          home_token_contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          home_token_contract_address_hash: Hash.Address.t()
        }

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :home_token_contract_address,
             :inserted_at,
             :updated_at
           ]}

  @primary_key false
  schema "bridged_tokens" do
    field(:foreign_chain_id, :decimal)
    field(:foreign_token_contract_address_hash, Hash.Address)

    belongs_to(
      :home_token_contract_address,
      Token,
      foreign_key: :home_token_contract_address_hash,
      primary_key: true,
      references: :contract_address_hash,
      type: Hash.Address
    )

    timestamps()
  end

  @required_attrs ~w(home_token_contract_address_hash)a
  @optional_attrs ~w(foreign_chain_id foreign_token_contract_address_hash)a

  @doc false
  def changeset(%BridgedToken{} = bridged_token, params \\ %{}) do
    bridged_token
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:home_token_contract_address)
    |> unique_constraint(:home_token_contract_address_hash)
  end
end
