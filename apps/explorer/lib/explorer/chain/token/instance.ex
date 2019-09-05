defmodule Explorer.Chain.Token.Instance do
  @moduledoc """
  Represents an ERC 721 token instance and stores metadata defined in https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Chain.Token.Instance

  @typedoc """
  * `token_id` - ID of the token
  * `token_contract_address_hash` - Address hash foreign key
  * `metadata` - Token instance metadata
  """

  @type t :: %Instance{
          token_id: non_neg_integer(),
          token_contract_address_hash: Hash.Address.t(),
          metadata: Map.t()
        }

  schema "token_instances" do
    field(:token_id, :decimal, primary_key: true)
    field(:metadata, :map)

    belongs_to(
      :token,
      Token,
      foreign_key: :token_contract_address_hash,
      references: :contract_address_hash,
      type: Hash.Address,
      primary_key: true
    )
  end

  # def changeset(%Instance{} = instance, params \\ %{}) do
  #   instance
  #   |> cast([:token_id, :metadata, :token_contract_address_hash])
  #   |> validate_required([:token_id, :token_contract_address_hash])
  #   |> foreign_key_constraint(:token_contract_address_hash)
  # end
end
