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
  import Ecto.Query, only: [from: 2, where: 3, group_by: 3, select: 3]

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.{Chain, SortingHelper}
  alias Explorer.Chain.{Address, Celo.Epoch, Hash, Token, Wei}

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

  @required_attrs ~w(amount type epoch_number account_address_hash associated_account_address_hash)a

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

    belongs_to(:epoch, Epoch,
      primary_key: true,
      foreign_key: :epoch_number,
      references: :number,
      type: :integer
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
  Converts a reward type string to its corresponding atom.

  ## Parameters
  - `type_string` (`String.t()`): The string representation of the reward type.

  ## Returns
  - `{:ok, type}` if the string is valid, `:error` otherwise.

  ## Examples

      iex> ElectionReward.type_from_string("voter")
      {:ok, :voter}

      iex> ElectionReward.type_from_string("invalid")
      :error
  """
  @spec type_from_string(String.t()) :: {:ok, type} | :error
  def type_from_string(type_string) do
    Map.fetch(@reward_type_string_to_atom, type_string)
  end

  @doc """
  Retrieves aggregated election rewards by block hash.

  ## Parameters
  - `block_hash` (`Hash.Full.t()`): The block hash to aggregate election
    rewards.
  - `options` (`Keyword.t()`): Optional parameters for fetching data.

  ## Returns
  - `%{atom() => Wei.t() | nil}`: A map of aggregated election rewards by type.

  ## Examples

      iex> block_hash = %Hash.Full{
      ...>   byte_count: 32,
      ...>   bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
      ...> }
      iex> Explorer.Chain.Celo.Reader.epoch_number_to_rewards_aggregated_by_type(block_hash)
      %{voter_reward: %{total: %Decimal{}, count: 2}, ...}
  """
  @spec epoch_number_to_rewards_aggregated_by_type(integer(), Keyword.t()) ::
          %{atom() => %{total: Decimal.t(), count: integer(), token: map() | nil}}
  def epoch_number_to_rewards_aggregated_by_type(epoch_number, options \\ []) do
    reward_type_to_aggregated_rewards =
      __MODULE__
      |> where([r], r.epoch_number == ^epoch_number)
      |> group_by([r], r.type)
      |> select([r], {r.type, sum(r.amount), count(r)})
      |> Chain.select_repo(options).all()
      |> Map.new(fn {type, total, count} ->
        {type, %{total: total, count: count}}
      end)

    reward_type_to_token = election_reward_tokens_by_type(options)

    @types_enum
    |> Map.new(&{&1, %{total: Decimal.new(0), count: 0}})
    |> Map.merge(reward_type_to_aggregated_rewards)
    |> Map.new(fn {type, aggregated_reward} ->
      token = reward_type_to_token[type]
      aggregated_reward_with_token = Map.put(aggregated_reward, :token, token)
      {type, aggregated_reward_with_token}
    end)
  end

  # Retrieves the token for each type of election reward.
  #
  # ## Parameters
  # - `options` (`Keyword.t()`): Optional parameters for fetching data.
  #
  # ## Returns
  # - `%{atom() => Token.t() | nil}`: A map of reward types to token.
  #
  # ## Examples
  #
  #     iex> epoch_number = %Hash.Full{
  #     ...>   byte_count: 32,
  #     ...>   bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
  #     ...> }
  #     iex> Explorer.Chain.Celo.ElectionReward.election_reward_token_addresses_by_type(epoch_number)
  #     %{voter_reward: %Token{}, ...}
  @spec election_reward_tokens_by_type(Keyword.t()) :: %{atom() => Token.t() | nil}
  defp election_reward_tokens_by_type(options) do
    reward_type_to_token_address_hash = reward_type_to_token_address_hash()

    tokens =
      reward_type_to_token_address_hash
      |> Map.values()
      |> Token.get_by_contract_address_hashes(options)

    reward_type_to_token_address_hash
    |> Map.new(fn {type, address_hash} ->
      token = Enum.find(tokens, &(&1.contract_address_hash == address_hash))
      {type, token}
    end)
  end

  @doc """
  Retrieves election rewards by epoch number and reward type.

  ## Parameters
  - `epoch_number` (`Hash.t()`): The epoch number to search for election rewards.
  - `reward_type` (`ElectionReward.type()`): The type of reward to filter.
  - `options` (`Keyword.t()`): Optional parameters for fetching data.

  ## Returns
  - `[ElectionReward.t()]`: A list of election rewards filtered by epoch number
    and reward type.

  """
  @spec epoch_number_and_type_to_rewards(integer(), type(), Keyword.t()) :: [__MODULE__.t()]
  def epoch_number_and_type_to_rewards(epoch_number, reward_type, options \\ [])
      when reward_type in @types_enum do
    default_sorting = [
      desc: :amount,
      asc: :account_address_hash,
      asc: :associated_account_address_hash
    ]

    paging_options = Keyword.get(options, :paging_options, default_paging_options())
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    sorting_options = Keyword.get(options, :sorting, [])

    __MODULE__
    |> where([r], r.epoch_number == ^epoch_number)
    |> where([r], r.type == ^reward_type)
    |> SortingHelper.apply_sorting(sorting_options, default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting_options, default_sorting)
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).all()
  end

  def address_hash_to_rewards_query(address_hash) do
    __MODULE__
    |> where([r], r.account_address_hash == ^address_hash)
  end

  @doc """
  Retrieves election rewards associated with a given address hash.

  ## Parameters
  - `address_hash` (`Hash.Address.t()`): The address hash to search for election
    rewards.
  - `options` (`Keyword.t()`): Optional parameters for fetching data.

  ## Returns
  - `[ElectionReward.t()]`: A list of election rewards associated with the
    address hash.

  ## Examples

      iex> address_hash = %Hash.Address{
      ...>   byte_count: 20,
      ...>   bytes: <<0x1d1f7f0e1441c37e28b89e0b5e1edbbd34d77649 :: size(160)>>
      ...> }
      iex> Explorer.Chain.Celo.ElectionReward.address_hash_to_rewards(address_hash)
      [%ElectionReward{}, ...]
  """
  @spec address_hash_to_rewards(Hash.Address.t(), Keyword.t()) :: [__MODULE__.t()]
  def address_hash_to_rewards(address_hash, options \\ []) do
    default_sorting = [
      desc: :epoch_number,
      asc: :type,
      desc: :amount,
      asc: :associated_account_address_hash
    ]

    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, default_paging_options())
    sorting_options = Keyword.get(options, :sorting, [])

    address_hash
    |> address_hash_to_rewards_query()
    |> join_token()
    |> SortingHelper.apply_sorting(sorting_options, default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting_options, default_sorting)
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).all()
  end

  defp reward_type_to_token_address_hash do
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

        # This match should never fail
        [address] = addresses
        {type, address}
      end
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
    reward_type_to_token_address_hash = reward_type_to_token_address_hash()

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
            ^reward_type_to_token_address_hash.voter.bytes,
            ^"validator",
            ^reward_type_to_token_address_hash.validator.bytes,
            ^"group",
            ^reward_type_to_token_address_hash.group.bytes,
            ^"delegated_payment",
            ^reward_type_to_token_address_hash.delegated_payment.bytes
          ),
      select_merge: %{token: t}
    )
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
