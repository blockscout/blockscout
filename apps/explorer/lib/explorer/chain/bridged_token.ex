defmodule Explorer.Chain.BridgedToken do
  @moduledoc """
  Represents a bridged token.

  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Chain.{Address, BridgedToken, Hash, Token}
  alias Explorer.Repo

  @typedoc """
  * `foreign_chain_id` - chain ID of a foreign token
  * `foreign_token_contract_address_hash` - Foreign token's contract hash
  * `home_token_contract_address` - The `t:Address.t/0` of the home token's contract
  * `home_token_contract_address_hash` - Home token's contract hash foreign key
  * `custom_metadata` - Arbitrary string with custom metadata. For instance, tokens/weights for Balance tokens
  * `custom_cap` - Custom capitalization for this token
  * `lp_token` - Boolean flag: LP token or not
  * `type` - omni/amb
  """
  @type t :: %BridgedToken{
          foreign_chain_id: Decimal.t(),
          foreign_token_contract_address_hash: Hash.Address.t(),
          home_token_contract_address: %Ecto.Association.NotLoaded{} | Address.t(),
          home_token_contract_address_hash: Hash.Address.t(),
          custom_metadata: String.t(),
          custom_cap: Decimal.t(),
          lp_token: boolean(),
          type: String.t(),
          exchange_rate: Decimal.t()
        }

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :home_token_contract_address,
             :inserted_at,
             :updated_at
           ]}

  @derive {Jason.Encoder,
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
    field(:custom_metadata, :string)
    field(:custom_cap, :decimal)
    field(:lp_token, :boolean)
    field(:type, :string)
    field(:exchange_rate, :decimal)

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
  @optional_attrs ~w(foreign_chain_id foreign_token_contract_address_hash custom_metadata custom_cap boolean type exchange_rate)a

  @doc false
  def changeset(%BridgedToken{} = bridged_token, params \\ %{}) do
    bridged_token
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:home_token_contract_address)
    |> unique_constraint(:home_token_contract_address_hash)
  end

  def get_unprocessed_mainnet_lp_tokens_list do
    query =
      from(bt in BridgedToken,
        where: bt.foreign_chain_id == ^1,
        where: is_nil(bt.lp_token) or bt.lp_token == true,
        select: bt
      )

    query
    |> Repo.all()
  end
end
