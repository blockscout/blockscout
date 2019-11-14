defmodule Explorer.Chain.CeloAccount do
  @moduledoc """
  Datatype for storing Celo accounts
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Wei}

  #    @type account_type :: %__MODULE__{ :regular | :validator | :group }

  @typedoc """
  * `address` - address of the account.
  * `account_type` - regular, validator or validator group
  * `locked_gold` - total locked gold
  * `nonvoting_locked_gold` - non-voting locked gold
  * `rewards` - rewards in cGLD
  """

  @type t :: %__MODULE__{
          address: Hash.Address.t(),
          account_type: String.t(),
          locked_gold: Wei.t(),
          nonvoting_locked_gold: Wei.t(),
          rewards: Wei.t()
        }

  @attrs ~w(
        address name url account_type nonvoting_locked_gold locked_gold rewards
    )a

  @required_attrs ~w(
        address name
    )a

  # Event topics that are used to find out when accounts, validators or validator groups have changed
  # Validator events
  @validator_registered "0x4e35530e670c639b101af7074b9abce98a1bb1ebff1f7e21c83fc0a553775074"

  @validator_group_registered "0xbf4b45570f1907a94775f8449817051a492a676918e38108bb762e991e6b58dc"
  @validator_group_deregistered "0xae7e034b0748a10a219b46074b20977a9170bf4027b156c797093773619a8669"

  @validator_affiliated "0x91ef92227057e201e406c3451698dd780fe7672ad74328591c88d281af31581d"
  @validator_deaffiliated "0x71815121f0622b31a3e7270eb28acb9fd10825ff418c9a18591f617bb8a31a6c"

  # Account events
  @account_created "0x805996f252884581e2f74cf3d2b03564d5ec26ccc90850ae12653dc1b72d1fa2"
  @account_wallet_address_set "0xf81d74398fd47e35c36b714019df15f200f623dde569b5b531d6a0b4da5c5f26"
  @account_url_set "0x0b5629fec5b6b5a1c2cfe0de7495111627a8cf297dced72e0669527425d3f01b"
  @account_name_set "0xa6e2c5a23bb917ba0a584c4b250257ddad698685829b66a8813c004b39934fe4"
  @account_data_encryption_key_set "0x43fdefe0a824cb0e3bbaf9c4bc97669187996136fe9282382baf10787f0d808d"

  # Locked gold events
  @gold_withdrawn "0x292d39ba701489b7f640c83806d3eeabe0a32c9f0a61b49e95612ebad42211cd"
  @gold_unlocked "0xb1a3aef2a332070da206ad1868a5e327f5aa5144e00e9a7b40717c153158a588"
  @gold_locked "0x0f0f2fc5b4c987a49e1663ce2c2d65de12f3b701ff02b4d09461421e63e609e7"

  # Election events
  @validator_group_vote_revoked "0xa06c722f7d446349fdd811f3d539bc91c7b11df8a2f4e012685712a30068f668"
  @validator_group_vote_activated "0x50363f7a646042bcb294d6afdef2d53f4122379845e67627b6db367f31934f16"
  @validator_group_vote_cast "0xd3532f70444893db82221041edb4dc26c94593aeb364b0b14dfc77d5ee905152"

  # Events for updating account
  def account_events,
    do: [
      @gold_withdrawn,
      @gold_unlocked,
      @gold_locked,
      @account_created,
      @account_wallet_address_set,
      @account_url_set,
      @account_name_set,
      @account_data_encryption_key_set,
      @validator_group_vote_revoked,
      @validator_group_vote_activated,
      @validator_group_vote_cast,
      @validator_registered,
      @validator_group_registered
    ]

  # Events for updating validator
  def validator_events,
    do: [
      @validator_registered,
      @validator_affiliated,
      @validator_deaffiliated
    ]

  # Events for updating validator group
  def validator_group_events,
    do: [
      @validator_group_registered,
      @validator_group_deregistered
    ]

  # Events for notifications
  def withdrawal_events,
    do: [
      @gold_withdrawn,
      @gold_unlocked,
      @gold_locked
    ]

  schema "celo_account" do
    field(:account_type, :string)
    field(:name, :string)
    field(:url, :string)
    field(:nonvoting_locked_gold, Wei)
    field(:locked_gold, Wei)
    field(:rewards, Wei)

    belongs_to(
      :account_address,
      Address,
      foreign_key: :address,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = celo_account, attrs) do
    celo_account
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address)
  end
end
