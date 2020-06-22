defmodule Explorer.Chain.ProxyContract do
  @moduledoc """
  The representation of a Proxied Smart Contract.
  "A contract in the sense of Solidity is a collection of code (its functions)
  and data (its state) that resides at a specific address on the Ethereum
  blockchain."
  http://solidity.readthedocs.io/en/v0.4.24/introduction-to-smart-contracts.html
  """

  use Explorer.Schema

  alias Explorer.Chain.{
    Hash,
    SmartContract
  }

  @typedoc """
  * `proxy_address` - address of the proxy contract.
  * `implementation_address` - address of the implementation contract behind the proxy.
  """

  @type t :: %Explorer.Chain.ProxyContract{
          proxy_address: Hash.Address.t(),
          implementation_address: Hash.Address.t()
        }

  schema "proxy_contract" do
    field(:proxy_address, Hash.Address)
    field(:implementation_address, Hash.Address)

    has_one(:smart_contract, SmartContract, foreign_key: :address_hash, references: :implementation_address)
  end

  def changeset(%__MODULE__{} = proxy_contract, attrs) do
    proxy_contract
    |> cast(attrs, [
      :proxy_address,
      :implementation_address
    ])
    |> validate_required([:proxy_address, :implementation_address])
  end
end
