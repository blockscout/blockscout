defmodule Explorer.Chain.Celo.ElectionReward do
  @moduledoc """
  Represents the rewards distributed in an epoch election.
  """
  use Explorer.Schema

  import Ecto.Query,
    only: [
      from: 2,
      where: 3
    ]

  alias Explorer.Chain.{Address, Block, Hash, Wei}
  alias Explorer.PagingOptions

  @type type :: :voter | :validator | :group | :delegated_payment
  @types_enum ~w(voter validator group delegated_payment)a

  @reward_type_string_to_atom %{
    "voter" => :voter,
    "validator" => :validator,
    "group" => :group,
    "delegated-payment" => :delegated_payment
  }

  @reward_type_atom_to_token_atom %{
    :voter => :celo_token,
    :validator => :usd_token,
    :group => :usd_token,
    :delegated_payment => :usd_token
  }

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @types_enum ~w(voter validator group delegated_payment)a

  @required_attrs ~w(amount type block_hash account_address_hash associated_account_address_hash)a

  @primary_key false
  typed_schema "celo_election_rewards" do
    field(:amount, Wei, null: false)

    field(
      :type,
      Ecto.Enum,
      values: @types_enum,
      null: false,
      primary_key: true
    )

    belongs_to(
      :block,
      Block,
      primary_key: true,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    belongs_to(
      :account_address,
      Address,
      primary_key: true,
      foreign_key: :account_address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(
      :associated_account_address,
      Address,
      primary_key: true,
      foreign_key: :associated_account_address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    field(
      :block_number,
      :integer,
      virtual: true
    ) :: Block.block_number()

    timestamps()
  end

  def changeset(%__MODULE__{} = rewards, attrs) do
    rewards
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> foreign_key_constraint(:account_address_hash)
    |> foreign_key_constraint(:associated_account_address_hash)

    # todo: do I need to set this unique constraint here? or it is redundant?
    # |> unique_constraint(
    #   [:block_hash, :type, :account_address_hash, :associated_account_address_hash],
    #   name: :celo_election_rewards_pkey
    # )
  end

  def types, do: @types_enum

  @spec type_from_string(String.t()) :: {:ok, type} | :error
  def type_from_string(type_string) do
    Map.fetch(@reward_type_string_to_atom, type_string)
  end

  @spec reward_type_atom_to_token_atom() :: %{type => atom()}
  def reward_type_atom_to_token_atom, do: @reward_type_atom_to_token_atom

  def block_hash_to_aggregated_rewards_by_type_query(block_hash) do
    from(
      r in __MODULE__,
      where: r.block_hash == ^block_hash,
      select: {r.type, sum(r.amount), count(r)},
      group_by: r.type
    )
  end

  def block_hash_to_rewards_by_type_query(block_hash, reward_type) do
    from(
      r in __MODULE__,
      where: r.block_hash == ^block_hash and r.type == ^reward_type,
      select: r,
      order_by: [
        desc: :amount,
        asc: :account_address_hash,
        asc: :associated_account_address_hash
      ]
    )
  end

  def address_hash_to_rewards_query(address_hash) do
    from(
      r in __MODULE__,
      join: b in assoc(r, :block),
      where: r.account_address_hash == ^address_hash,
      select: r,
      select_merge: %{
        block_number: b.number
      },
      order_by: [
        desc: b.number,
        desc: r.amount,
        asc: r.associated_account_address_hash,
        asc: r.type
      ]
    )
  end

  def paginate(query, %PagingOptions{key: nil}), do: query

  # Clause to paginate election rewards on block's page
  def paginate(query, %PagingOptions{key: {amount, account_address_hash, associated_account_address_hash}}) do
    where(
      query,
      [reward],
      reward.amount < ^amount or
        (reward.amount == ^amount and
           reward.account_address_hash > ^account_address_hash) or
        (reward.amount == ^amount and
           reward.account_address_hash == ^account_address_hash and
           reward.associated_account_address_hash > ^associated_account_address_hash)
    )
  end

  # Clause to paginate election rewards on a page of address
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def paginate(query, %PagingOptions{key: {block_number, amount, associated_account_address_hash, type}}) do
    where(
      query,
      [reward],
      reward.block_number < ^block_number or
        (reward.block_number == ^block_number and
           reward.amount < ^amount) or
        (reward.block_number == ^block_number and
           reward.amount == ^amount and
           reward.associated_account_address_hash > ^associated_account_address_hash) or
        (reward.block_number == ^block_number and
           reward.amount == ^amount and
           reward.associated_account_address_hash == ^associated_account_address_hash and
           reward.type > ^type)
    )
  end

  def to_block_paging_params(%__MODULE__{
        amount: amount,
        account_address_hash: account_address_hash,
        associated_account_address_hash: associated_account_address_hash
      }) do
    %{
      "amount" => amount,
      "account_address_hash" => account_address_hash,
      "associated_account_address_hash" => associated_account_address_hash
    }
  end

  def to_address_paging_params(%__MODULE__{
        block_number: block_number,
        amount: amount,
        associated_account_address_hash: associated_account_address_hash,
        type: type
      }) do
    %{
      "block_number" => block_number,
      "amount" => amount,
      "associated_account_address_hash" => associated_account_address_hash,
      "type" => type
    }
  end
end
