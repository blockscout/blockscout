defmodule Explorer.Chain.CeloAccountEpoch do
  @moduledoc """
  Datatype for storing Celo epoch data per account
  """

  require Logger

  use Explorer.Schema

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.{Address, Block, Hash, Wei}
  alias Explorer.Repo

  @typedoc """
  * `account_hash` - account for which we're tracking the data
  * `block_hash` - epoch block for which we're tracking the data
  * `total_locked_gold` - amount of locked gold
  * `nonvoting_locked_gold` - amount of non-voting locked gold
  """

  @type t :: %__MODULE__{
          account_hash: Hash.Address.t(),
          block_hash: Hash.Full.t(),
          total_locked_gold: Wei.t(),
          nonvoting_locked_gold: Wei.t()
        }

  @attrs ~w( account_hash block_hash total_locked_gold nonvoting_locked_gold )a

  @required_attrs ~w( account_hash block_hash total_locked_gold nonvoting_locked_gold )a

  @primary_key false
  schema "celo_accounts_epochs" do
    field(:total_locked_gold, Wei)
    field(:nonvoting_locked_gold, Wei)

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    belongs_to(:account, Address.Hash,
      foreign_key: :account_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
  end

  def last_for_address(address) do
    query =
      from(account_epoch in __MODULE__,
        join: block in Block,
        on: block.hash == account_epoch.block_hash,
        where: account_epoch.account_hash == ^address,
        order_by: [desc: block.number],
        limit: 1
      )

    query
    |> Repo.one()
  end
end
