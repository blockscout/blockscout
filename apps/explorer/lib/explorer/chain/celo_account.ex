
defmodule Explorer.Chain.CeloAccount do
    @moduledoc """

    """
  
    require Logger
  
    use Explorer.Schema
  
    alias Explorer.Chain.{Hash, Wei}
  
#    @type account_type :: %__MODULE__{ :regular | :validator | :group }

    @typedoc """
    * `address` - address of the account.
    * `account_type` - regular, validator or validator group
    * `gold` - cGLD balance
    * `usd` - cUSD balance
    * `locked_gold` - voting weight
    * `notice_period` - 
    * `rewards` - rewards in cGLD
    """

    @type t :: %__MODULE__{
        address: Hash.Address.t(),
        account_type: String.t(),
        gold: Wei.t(),
        usd: Wei.t(),
        locked_gold: Wei.t(),
        notice_period: integer,
        rewards: Wei.t()
    }

    @attrs ~w(
        address account_type gold usd locked_gold notive_period rewards
    )a

    @validator_registered_event "0x4e35530e670c639b101af7074b9abce98a1bb1ebff1f7e21c83fc0a553775074"
    def validator_registered_event, do: @validator_registered_event

    schema "celo_account" do
        field(:address, Hash.Address)
        field(:account_type, :string)
        field(:gold, Wei)
        field(:usd, Wei)
        field(:locked_gold, Wei)
        field(:notice_period, :integer)
        field(:rewards, Wei)
    end

    def changeset(%__MODULE__{} = celo_account, attrs) do
      celo_account
      |> cast(attrs, @attrs)
      |> validate_required(@attrs)
    end

end

