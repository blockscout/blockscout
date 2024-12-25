defmodule Explorer.Chain.Celo.ElectionReward do
  @moduledoc """
  Represents the rewards distributed in an epoch election. Each reward has a
  type, and each type of reward is paid in a specific token. The rewards are
  paid to an account address and are also associated with another account
  address.

  ## Reward Types and Addresses

  Here is the breakdown of what each address means for each type of reward:

  - `voter`:
    - Account address: The voter address.
    - Associated account address: The group address.
  - `validator`:
    - Account address: The validator address.
    - Associated account address: The validator group address.
  - `group`:
    - Account address: The validator group address.
    - Associated account address: The validator address that the reward was paid
      on behalf of.
  - `delegated_payment`:
    - Account address: The beneficiary receiving the part of the reward on
      behalf of the validator.
    - Associated account address: The validator that set the delegation of a
      part of their reward to some external address.
  """

  use Explorer.Schema

  import Explorer.PagingOptions, only: [default_paging_options: 0]
  import Ecto.Query, only: [from: 2, where: 3]
  import Explorer.Helper, only: [safe_parse_non_negative_integer: 1]

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Address, Block, Hash, Token, Wei}

  @type type :: :voter | :validator | :group | :delegated_payment
  @types_enum ~w(voter validator group delegated_payment)a

  @reward_type_url_string_to_atom %{
    "voter" => :voter,
    "validator" => :validator,
    "group" => :group,
    "delegated-payment" => :delegated_payment
  }

  @reward_type_string_to_atom %{
    "voter" => :voter,
    "validator" => :validator,
    "group" => :group,
    "delegated_payment" => :delegated_payment
  }

  @reward_type_atom_to_token_atom %{
    :voter => :celo_token,
    :validator => :usd_token,
    :group => :usd_token,
    :delegated_payment => :usd_token
  }

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

    field(:token, :any, virtual: true) :: Token.t() | nil

    timestamps()
  end

  @spec changeset(
          Explorer.Chain.Celo.ElectionReward.t(),
          map()
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = rewards, attrs) do
    rewards
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> foreign_key_constraint(:account_address_hash)
    |> foreign_key_constraint(:associated_account_address_hash)
  end

  @doc """
  Returns the list of election reward types.
  """
  @spec types() :: [type]
  def types, do: @types_enum

  @doc """
  Converts a reward type url string to its corresponding atom.

  ## Parameters
  - `type_string` (`String.t()`): The string representation of the reward type.

  ## Returns
  - `{:ok, type}` if the string is valid, `:error` otherwise.

  ## Examples

      iex> ElectionReward.type_from_url_string("voter")
      {:ok, :voter}

      iex> ElectionReward.type_from_url_string("invalid")
      :error
  """
  @spec type_from_url_string(String.t()) :: {:ok, type} | :error
  def type_from_url_string(type_string) do
    Map.fetch(@reward_type_url_string_to_atom, type_string)
  end

  @doc """
  Returns a map of reward type atoms to their corresponding token atoms.

  ## Returns
  - A map where the keys are reward type atoms and the values are token atoms.

  ## Examples

      iex> ElectionReward.reward_type_atom_to_token_atom()
      %{voter: :celo_token, validator: :usd_token, group: :usd_token, delegated_payment: :usd_token}
  """
  @spec reward_type_atom_to_token_atom() :: %{type => atom()}
  def reward_type_atom_to_token_atom, do: @reward_type_atom_to_token_atom

  @doc """
  Builds a query to aggregate rewards by type for a given block hash.

  ## Parameters
  - `block_hash` (`Hash.Full.t()`): The block hash to filter rewards.

  ## Returns
  - An Ecto query.
  """
  @spec block_hash_to_aggregated_rewards_by_type_query(Hash.Full.t()) :: Ecto.Query.t()
  def block_hash_to_aggregated_rewards_by_type_query(block_hash) do
    from(
      r in __MODULE__,
      where: r.block_hash == ^block_hash,
      select: {r.type, sum(r.amount), count(r)},
      group_by: r.type
    )
  end

  @doc """
  Builds a query to get rewards by type for a given block hash.

  ## Parameters
  - `block_hash` (`Hash.Full.t()`): The block hash to filter rewards.
  - `reward_type` (`type`): The type of reward to filter.

  ## Returns
  - An Ecto query.
  """
  @spec block_hash_to_rewards_by_type_query(Hash.Full.t(), type) :: Ecto.Query.t()
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

  @doc """
  Builds a query to get rewards by account address hash.
  """
  @spec address_hash_to_rewards_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_hash_to_rewards_query(address_hash) do
    from(
      r in __MODULE__,
      where: r.account_address_hash == ^address_hash,
      select: r
    )
  end

  @doc """
  Builds a query to get ordered rewards by account address hash.

  ## Parameters
  - `address_hash` (`Hash.Address.t()`): The account address hash to filter
    rewards.

  ## Returns
  - An Ecto query.
  """
  @spec address_hash_to_ordered_rewards_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_hash_to_ordered_rewards_query(address_hash) do
    from(
      r in __MODULE__,
      join: b in assoc(r, :block),
      as: :block,
      preload: [block: b],
      where: r.account_address_hash == ^address_hash,
      select: r,
      order_by: [
        desc: b.number,
        desc: r.amount,
        asc: r.associated_account_address_hash,
        asc: r.type
      ]
    )
  end

  @doc """
  Joins the token table to the query based on the reward type.

  ## Parameters
  - `query` (`Ecto.Query.t()`): The query to join the token table.

  ## Returns
  - An Ecto query with the token table joined.
  """
  @spec join_token(Ecto.Query.t()) :: Ecto.Query.t()
  def join_token(query) do
    # This match should never fail
    %{
      voter: [voter_token_address_hash],
      validator: [validator_token_address_hash],
      group: [group_token_address_hash],
      delegated_payment: [delegated_payment_token_address_hash]
    } =
      Map.new(
        @reward_type_atom_to_token_atom,
        fn {type, token_atom} ->
          addresses =
            token_atom
            |> CeloCoreContracts.get_address_updates()
            |> case do
              {:ok, addresses} -> addresses
              _ -> []
            end
            |> Enum.map(fn %{"address" => address_hash_string} ->
              {:ok, address_hash} = Hash.Address.cast(address_hash_string)
              address_hash
            end)

          {type, addresses}
        end
      )

    from(
      r in query,
      join: t in Token,
      on:
        t.contract_address_hash ==
          fragment(
            """
            CASE ?
              WHEN ? THEN ?::bytea
              WHEN ? THEN ?::bytea
              WHEN ? THEN ?::bytea
              WHEN ? THEN ?::bytea
              ELSE NULL
            END
            """,
            r.type,
            ^"voter",
            ^voter_token_address_hash.bytes,
            ^"validator",
            ^validator_token_address_hash.bytes,
            ^"group",
            ^group_token_address_hash.bytes,
            ^"delegated_payment",
            ^delegated_payment_token_address_hash.bytes
          ),
      select_merge: %{token: t}
    )
  end

  @doc """
  Makes Explorer.PagingOptions map for election rewards.
  """
  @spec block_paging_options(map()) :: [Chain.paging_options()]
  def block_paging_options(params) do
    with %{
           "amount" => amount_string,
           "account_address_hash" => account_address_hash_string,
           "associated_account_address_hash" => associated_account_address_hash_string
         }
         when is_binary(amount_string) and
                is_binary(account_address_hash_string) and
                is_binary(associated_account_address_hash_string) <- params,
         {amount, ""} <- Decimal.parse(amount_string),
         {:ok, account_address_hash} <- Hash.Address.cast(account_address_hash_string),
         {:ok, associated_account_address_hash} <-
           Hash.Address.cast(associated_account_address_hash_string) do
      [
        paging_options: %{
          default_paging_options()
          | key: {amount, account_address_hash, associated_account_address_hash}
        }
      ]
    else
      _ ->
        [paging_options: default_paging_options()]
    end
  end

  @doc """
  Makes Explorer.PagingOptions map for election rewards.
  """
  @spec address_paging_options(map()) :: [Chain.paging_options()]
  def address_paging_options(params) do
    with %{
           "block_number" => block_number_string,
           "amount" => amount_string,
           "associated_account_address_hash" => associated_account_address_hash_string,
           "type" => type_string
         }
         when is_binary(block_number_string) and
                is_binary(amount_string) and
                is_binary(associated_account_address_hash_string) and
                is_binary(type_string) <- params,
         {:ok, block_number} <- safe_parse_non_negative_integer(block_number_string),
         {amount, ""} <- Decimal.parse(amount_string),
         {:ok, associated_account_address_hash} <-
           Hash.Address.cast(associated_account_address_hash_string),
         {:ok, type} <- Map.fetch(@reward_type_string_to_atom, type_string) do
      [
        paging_options: %{
          default_paging_options()
          | key: {block_number, amount, associated_account_address_hash, type}
        }
      ]
    else
      _ ->
        [paging_options: default_paging_options()]
    end
  end

  @doc """
  Paginates the given query based on the provided `PagingOptions`.

  ## Parameters
  - `query` (`Ecto.Query.t()`): The query to paginate.
  - `paging_options` (`PagingOptions.t()`): The pagination options.

  ## Returns
  - An Ecto query with pagination applied.
  """
  def paginate(query, %PagingOptions{key: nil}), do: query

  def paginate(query, %PagingOptions{key: {0 = _amount, account_address_hash, associated_account_address_hash}}) do
    where(
      query,
      [reward],
      reward.amount == 0 and
        (reward.account_address_hash > ^account_address_hash or
           (reward.account_address_hash == ^account_address_hash and
              reward.associated_account_address_hash > ^associated_account_address_hash))
    )
  end

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

  def paginate(query, %PagingOptions{key: {0 = _block_number, 0 = _amount, associated_account_address_hash, type}}) do
    where(
      query,
      [reward, block],
      block.number == 0 and reward.amount == 0 and
        (reward.associated_account_address_hash > ^associated_account_address_hash or
           (reward.associated_account_address_hash == ^associated_account_address_hash and
              reward.type > ^type))
    )
  end

  def paginate(query, %PagingOptions{key: {0 = _block_number, amount, associated_account_address_hash, type}}) do
    where(
      query,
      [reward, block],
      block.number == 0 and
        (reward.amount < ^amount or
           (reward.amount == ^amount and
              reward.associated_account_address_hash > ^associated_account_address_hash) or
           (reward.amount == ^amount and
              reward.associated_account_address_hash == ^associated_account_address_hash and
              reward.type > ^type))
    )
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def paginate(query, %PagingOptions{key: {block_number, 0 = _amount, associated_account_address_hash, type}}) do
    where(
      query,
      [reward, block],
      block.number < ^block_number or
        (block.number == ^block_number and
           reward.amount == 0 and
           reward.associated_account_address_hash > ^associated_account_address_hash) or
        (block.number == ^block_number and
           reward.amount == 0 and
           reward.associated_account_address_hash == ^associated_account_address_hash and
           reward.type > ^type)
    )
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def paginate(query, %PagingOptions{key: {block_number, amount, associated_account_address_hash, type}}) do
    where(
      query,
      [reward, block],
      block.number < ^block_number or
        (block.number == ^block_number and
           reward.amount < ^amount) or
        (block.number == ^block_number and
           reward.amount == ^amount and
           reward.associated_account_address_hash > ^associated_account_address_hash) or
        (block.number == ^block_number and
           reward.amount == ^amount and
           reward.associated_account_address_hash == ^associated_account_address_hash and
           reward.type > ^type)
    )
  end

  @doc """
  Converts an `ElectionReward` struct to paging parameters on the block view.

  ## Parameters
  - `reward` (`%__MODULE__{}`): The election reward struct.

  ## Returns
  - A map representing the block paging parameters.

  ## Examples

      iex> ElectionReward.to_block_paging_params(%ElectionReward{amount: 1000, account_address_hash: "0x123", associated_account_address_hash: "0x456"})
      %{"amount" => 1000, "account_address_hash" => "0x123", "associated_account_address_hash" => "0x456"}
  """
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

  @doc """
  Converts an `ElectionReward` struct to paging parameters on the address view.

  ## Parameters
  - `reward` (`%__MODULE__{}`): The election reward struct.

  ## Returns
  - A map representing the address paging parameters.

  ## Examples

      iex> ElectionReward.to_address_paging_params(%ElectionReward{block_number: 1, amount: 1000, associated_account_address_hash: "0x456", type: :voter})
      %{"block_number" => 1, "amount" => 1000, "associated_account_address_hash" => "0x456", "type" => :voter}
  """
  def to_address_paging_params(%__MODULE__{
        block: %Block{number: block_number},
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

  @doc """
  Custom filter for `ElectionReward`, inspired by
  `Chain.where_block_number_in_period/3`.

  TODO: Consider reusing `Chain.where_block_number_in_period/3`. This would
  require storing or making `merge_select` of `block_number`.
  """
  @spec where_block_number_in_period(
          Ecto.Query.t(),
          String.t() | integer() | nil,
          String.t() | integer() | nil
        ) :: Ecto.Query.t()
  def where_block_number_in_period(base_query, from_block, to_block)
      when is_nil(from_block) and not is_nil(to_block),
      do: where(base_query, [_, block], block.number <= ^to_block)

  def where_block_number_in_period(base_query, from_block, to_block)
      when not is_nil(from_block) and is_nil(to_block),
      do: where(base_query, [_, block], block.number > ^from_block)

  def where_block_number_in_period(base_query, from_block, to_block)
      when is_nil(from_block) and is_nil(to_block),
      do: base_query

  def where_block_number_in_period(base_query, from_block, to_block),
    do:
      where(
        base_query,
        [_, block],
        block.number > ^from_block and
          block.number <= ^to_block
      )
end
