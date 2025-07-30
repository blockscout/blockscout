defmodule Explorer.Chain.Celo.Epoch do
  @moduledoc """
  Schema for Celo blockchain epochs.
  """

  use Explorer.Schema

  import Ecto.Query, only: [from: 2, where: 2]

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation,
    only: [proxy_implementations_association: 0]

  alias Explorer.{Chain, Repo, SortingHelper}

  alias Explorer.Chain.{
    Block,
    Celo.ElectionReward,
    Celo.EpochReward,
    Hash,
    TokenTransfer
  }

  @required_attrs ~w(number)a
  @optional_attrs ~w(fetched? start_block_number end_block_number start_processing_block_hash end_processing_block_hash)a

  @default_paging_options Chain.default_paging_options()

  @typedoc """
  * `number` - The epoch number.
  * `fetched?` - Indicates whether the epoch has been fetched.
  * `start_block_number` - The starting block number of the epoch.
  * `end_block_number` - The ending block number of the epoch.
  * `start_processing_block_hash` - The hash of the block where the epoch
    processing starts.
  * `end_processing_block_hash` - The hash of the block where the epoch
    processing ends.
  """
  @primary_key false
  typed_schema "celo_epochs" do
    field(:number, :integer, primary_key: true)

    field(:fetched?, :boolean,
      source: :is_fetched,
      default: false,
      null: false
    )

    field(:start_block_number, :integer)
    field(:end_block_number, :integer)

    belongs_to(:start_processing_block, Block,
      foreign_key: :start_processing_block_hash,
      references: :hash,
      type: Hash.Full
    )

    belongs_to(:end_processing_block, Block,
      foreign_key: :end_processing_block_hash,
      references: :hash,
      type: Hash.Full
    )

    has_one(:distribution, EpochReward,
      foreign_key: :epoch_number,
      references: :number
    )

    has_many(:election_reward, ElectionReward,
      foreign_key: :epoch_number,
      references: :number
    )

    timestamps()
  end

  @spec changeset(
          __MODULE__.t(),
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = vote, attrs \\ %{}) do
    vote
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:start_processing_block_hash)
    |> foreign_key_constraint(:end_processing_block_hash)
  end

  @doc """
  Returns a stream of epochs with unfetched rewards.
  """
  @spec stream_unfetched_epochs(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_epochs(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    query =
      from(
        epoch in __MODULE__,
        join: start_processing_block in assoc(epoch, :start_processing_block),
        join: end_processing_block in assoc(epoch, :end_processing_block),
        where:
          epoch.fetched? == false and
            start_processing_block.consensus == true and
            end_processing_block.consensus == true,
        order_by: [desc: epoch.number]
      )

    query
    |> Chain.add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Retrieves all epochs that have been marked as fetched.

  ## Parameters
    - `options` (`Keyword.t()`): Options for filtering and ordering the epochs.
      - `:paging_options` - pagination parameters
      - `:necessity_by_association` - associations that need to be loaded
      - `:sorting` - sorting parameters

  ## Returns
    - `list(__MODULE__.t())`: A list of fetched epochs.

  ## Examples

      iex> Explorer.Chain.Celo.Epoch.fetched_epochs([])
      [%Explorer.Chain.Celo.Epoch{number: 42, fetched?: true, ...}, ...]

      iex> Explorer.Chain.Celo.Epoch.fetched_epochs(sorting: [asc: :number], paging_options: %{page_size: 10})
      [%Explorer.Chain.Celo.Epoch{number: 1, fetched?: true, ...}, ...]
  """
  @spec all(Keyword.t()) :: [__MODULE__.t()]
  def all(options) do
    default_sorting = [desc: :number]

    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    sorting_options = Keyword.get(options, :sorting, [])

    __MODULE__
    |> SortingHelper.apply_sorting(sorting_options, default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting_options, default_sorting)
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).all()
    |> Enum.map(&with_loaded_distribution_token_transfers(&1, options))
  end

  @doc """
  Returns a query to find an epoch by its number.

  ## Parameters
    - `number` (`integer()`): The epoch number to search for.

  ## Returns
    - `Ecto.Query.t()`: The query to find the epoch.

  ## Examples

      iex> Repo.one(epoch_by_number_query(42))
      %Epoch{number: 42, start_block_number: 123400, end_block_number: 123799}

      iex> Repo.one(epoch_by_number_query(999999))
      nil
  """
  @spec epoch_by_number_query(integer()) :: Ecto.Query.t()
  def epoch_by_number_query(number) do
    __MODULE__
    |> where(number: ^number)
  end

  @doc """
  Retrieves an epoch by its number. This function fetches the epoch from the
  database and preloads its associated data based on the provided options. It
  always preloads distribution token transfers.

  ## Parameters
    - `number` (`integer()`): The epoch number to search for.
    - `options` (`Keyword.t()`): Options for filtering and ordering the epochs.
      - `:necessity_by_association` - associations that need to be loaded
      - `:sorting` - sorting parameters
  ## Returns
    - `{:ok, __MODULE__.t()}`: The epoch struct if found.
    - `{:error, :not_found}`: If the epoch is not found.

  ## Examples
      iex> Explorer.Chain.Celo.Epoch.from_number(42, [])
      {:ok, %Epoch{number: 42, start_block_number: 123400, end_block_number: 123799}}

      iex> Explorer.Chain.Celo.Epoch.from_number(999999, [])
      {:error, :not_found}
  """
  @spec from_number(integer(), Keyword.t()) ::
          {:ok, __MODULE__.t()} | {:error, :not_found}
  def from_number(number, options) when is_integer(number) and is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    number
    |> epoch_by_number_query()
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).one()
    |> with_loaded_distribution_token_transfers(options)
    |> case do
      nil ->
        {:error, :not_found}

      epoch ->
        {:ok, epoch}
    end
  end

  # Loads the token transfers for the epoch with preloaded epoch reward.
  #
  # This function retrieves token transfers related to the specified epoch reward
  # by knowing the index of the log of the token transfer and populates the
  # virtual fields in the `EpochReward` struct. We manually preload token
  # transfers since Ecto does not support automatically preloading objects by
  # composite key (i.e., `log_index` and `block_hash`).
  #
  # ## Parameters
  # - `epoch_reward` (`EpochReward.t()`): The epoch reward struct.
  # - `options` (`Keyword.t()`): Optional parameters for selecting the repository.
  #
  # ## Returns
  # - `EpochReward.t()`: The epoch reward struct with the token transfers loaded.
  #
  # ## Example
  #
  #     iex> epoch_reward = %Explorer.Chain.Celo.EpochReward{block_hash: "some_hash", reserve_bolster_transfer_log_index: 1}
  #     iex> Explorer.Chain.Celo.EpochReward.load_token_transfers(epoch_reward)
  #     %Explorer.Chain.Celo.EpochReward{
  #       block_hash: "some_hash",
  #       reserve_bolster_transfer_log_index: 1,
  #       reserve_bolster_transfer: %Explorer.Chain.TokenTransfer{log_index: 1, ...}
  #     }
  #
  @spec with_loaded_distribution_token_transfers(__MODULE__.t() | nil, api?: boolean()) ::
          __MODULE__.t() | nil
  defp with_loaded_distribution_token_transfers(
         %__MODULE__{
           end_processing_block_hash: block_hash,
           distribution: %EpochReward{
             reserve_bolster_transfer_log_index: reserve_bolster_transfer_log_index,
             community_transfer_log_index: community_transfer_log_index,
             carbon_offsetting_transfer_log_index: carbon_offsetting_transfer_log_index
           }
         } = epoch,
         options
       ) do
    virtual_field_to_log_index = [
      reserve_bolster_transfer: reserve_bolster_transfer_log_index,
      community_transfer: community_transfer_log_index,
      carbon_offsetting_transfer: carbon_offsetting_transfer_log_index
    ]

    log_indexes =
      virtual_field_to_log_index
      |> Enum.map(fn {_, index} -> index end)
      |> Enum.reject(&is_nil/1)

    query =
      from(
        tt in TokenTransfer.only_consensus_transfers_query(),
        where: tt.log_index in ^log_indexes and tt.block_hash == ^block_hash,
        select: {tt.log_index, tt},
        preload: [
          :token,
          [from_address: [:scam_badge, :names, :smart_contract, ^proxy_implementations_association()]],
          [to_address: [:scam_badge, :names, :smart_contract, ^proxy_implementations_association()]]
        ]
      )

    log_index_to_token_transfer =
      query
      |> Chain.select_repo(options).all()
      |> Map.new()

    with_token_transfers =
      Enum.reduce(virtual_field_to_log_index, epoch.distribution, fn
        {field, log_index}, acc ->
          token_transfer = Map.get(log_index_to_token_transfer, log_index)
          Map.put(acc, field, token_transfer)
      end)

    %__MODULE__{epoch | distribution: with_token_transfers}
  end

  defp with_loaded_distribution_token_transfers(epoch, _options), do: epoch

  @doc """
  Returns a query to find an epoch containing the given block number.

  When multiple epochs with nil end_block_number match the block number, the one
  with the maximum start_block_number is selected.

  ## Parameters
    - `block_number` (`non_neg_integer()`): The block number to search for.

  ## Returns
    - `Ecto.Query.t()`: The query to find the epoch.

  ## Examples

      iex> Repo.one(block_number_to_epoch_query(123456))
      %Epoch{number: 42, start_block_number: 123400, end_block_number: 123799}

      iex> Repo.one(block_number_to_epoch_query(123800))
      %Epoch{number: 43, start_block_number: 123800, end_block_number: nil}

      iex> Repo.one(block_number_to_epoch_query(999999))
      nil
  """
  @spec block_number_to_epoch_query(non_neg_integer()) :: Ecto.Query.t()
  def block_number_to_epoch_query(block_number) do
    from(e in __MODULE__,
      # First, find epochs where the block_number falls within a defined range
      # OR it's an open-ended epoch with start_block_number <= block_number
      where:
        e.start_block_number <= ^block_number and
          (is_nil(e.end_block_number) or
             e.end_block_number >= ^block_number),
      # Order by end_block_number nulls last (closed epochs first)
      # Then by start_block_number descending (most recent open epoch)
      order_by: [asc_nulls_last: e.end_block_number, desc: e.start_block_number],
      # Limit to just one result
      limit: 1
    )
  end
end
