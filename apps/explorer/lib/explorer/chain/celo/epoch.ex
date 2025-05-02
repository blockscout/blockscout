defmodule Explorer.Chain.Celo.Epoch do
  @moduledoc """
  TODO
  """

  use Explorer.Schema

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]

  alias Explorer.Chain

  alias Explorer.Chain.{
    Block,
    Hash,
    Celo.ElectionReward,
    Celo.EpochReward,
    TokenTransfer
  }

  alias Explorer.Repo

  @required_attrs ~w(number)a
  @optional_attrs ~w(fetched? start_block_number end_block_number start_processing_block_hash end_processing_block_hash)a

  @typedoc """
  TODO
  """
  @primary_key false
  typed_schema "celo_epochs" do
    field(:number, :integer, primary_key: true)
    field(:fetched?, :boolean, source: :is_fetched, default: false)

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

  @spec from_number(integer(), Keyword.t()) ::
          {:ok, __MODULE__.t()} | {:error, :not_found}
  def from_number(number, options \\ []) when is_integer(number) and is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    __MODULE__
    |> where(number: ^number)
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
  @spec with_loaded_distribution_token_transfers(__MODULE__.t(), api?: boolean()) :: __MODULE__.t()
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
end
