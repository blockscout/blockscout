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
          attestations_requested: non_neg_integer(),
          attestations_fulfilled: non_neg_integer()
        }

  @attrs ~w(
        address name url account_type nonvoting_locked_gold locked_gold attestations_requested attestations_fulfilled
    )a

  @required_attrs ~w(
        address
    )a

  # Event topics that are used to find out when accounts, validators or validator groups have changed
  # Validator events
  @validator_registered "0x4e35530e670c639b101af7074b9abce98a1bb1ebff1f7e21c83fc0a553775074"

  @validator_group_registered "0xbf4b45570f1907a94775f8449817051a492a676918e38108bb762e991e6b58dc"
  @validator_group_deregistered "0xae7e034b0748a10a219b46074b20977a9170bf4027b156c797093773619a8669"

  @validator_affiliated "0x91ef92227057e201e406c3451698dd780fe7672ad74328591c88d281af31581d"
  @validator_deaffiliated "0x71815121f0622b31a3e7270eb28acb9fd10825ff418c9a18591f617bb8a31a6c"

  @validator_signer_authorized "0x16e382723fb40543364faf68863212ba253a099607bf6d3a5b47e50a8bf94943"

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

  @validator_group_member_added "0xbdf7e616a6943f81e07a7984c9d4c00197dc2f481486ce4ffa6af52a113974ad"
  @validator_group_member_removed "0xc7666a52a66ff601ff7c0d4d6efddc9ac20a34792f6aa003d1804c9d4d5baa57"
  @validator_group_member_reordered "0x38819cc49a343985b478d72f531a35b15384c398dd80fd191a14662170f895c6"

  @validator_epoch_payment_distributed "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975"

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
      @validator_deaffiliated,
      @validator_signer_authorized,
      @validator_epoch_payment_distributed
    ]

  def membership_events,
    do: [
      @validator_group_member_added,
      @validator_group_member_removed,
      @validator_group_member_reordered
    ]

  # Events for updating validator group
  def validator_group_events,
    do: [
      @validator_group_registered,
      @validator_group_deregistered
    ]

  def vote_events,
    do: [
      @validator_group_vote_revoked,
      @validator_group_vote_cast
    ]

  # Events for notifications
  def withdrawal_events,
    do: [
      @gold_withdrawn,
      @gold_unlocked,
      @gold_locked
    ]

  @attestation_issuer_selected "0xaf7f470b643316cf44c1f2898328a075e7602945b4f8584f48ba4ad2d8a2ea9d"
  @attestation_completed "0x414ff2c18c092697c4b8de49f515ac44f8bebc19b24553cf58ace913a6ac639d"

  @median_updated "0x01f3db74cdcb3b158f2144fb78c5ab54e9e8a8c09d3d3b7713050cdb6b6bcb97"
  @oracle_reported "0xdbf09271932e018b9c31e9988e4fbe3109fdd79d78f5d19a764dfb56035ed775"

  def attestation_issuer_selected_event,
    do: @attestation_issuer_selected

  def attestation_completed_event,
    do: @attestation_completed

  def median_updated_event,
    do: @median_updated

  def oracle_reported_event,
    do: @oracle_reported

  def account_name_event,
    do: @account_name_set

  schema "celo_account" do
    field(:account_type, :string)
    field(:name, :string)
    field(:url, :string)
    field(:nonvoting_locked_gold, Wei)
    field(:locked_gold, Wei)

    field(:attestations_requested, :integer)
    field(:attestations_fulfilled, :integer)

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
