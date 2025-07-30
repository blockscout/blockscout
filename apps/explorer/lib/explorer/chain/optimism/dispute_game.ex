defmodule Explorer.Chain.Optimism.DisputeGame do
  @moduledoc "Models a dispute game for Optimism."

  use Explorer.Schema

  import Ecto.Query
  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.{Data, Hash}
  alias Explorer.{PagingOptions, Repo}

  @required_attrs ~w(index game_type address_hash created_at)a
  @optional_attrs ~w(extra_data resolved_at status)a

  @chain_id_bob_mainnet 60_808
  @chain_id_bob_sepolia 808_813

  @typedoc """
    * `index` - A unique index of the dispute game.
    * `game_type` - A number encoding a type of the dispute game.
    * `address_hash` - The dispute game contract address.
    * `extra_data` - An extra data of the dispute game (contains L2 block number).
      Equals to `nil` when the game is written to database but the rest data is not known yet.
    * `created_at` - UTC timestamp of when the dispute game was created.
    * `resolved_at` - UTC timestamp of when the dispute game was resolved.
      Equals to `nil` if the game is not resolved yet.
    * `status` - 0 means the game is in progress (not resolved yet), 1 means a challenger wins, 2 means a defender wins.
      Equals to `nil` when the game is written to database but the rest data is not known yet.
  """
  @primary_key false
  typed_schema "op_dispute_games" do
    field(:index, :integer, primary_key: true)
    field(:game_type, :integer)
    field(:address_hash, Hash.Address)
    field(:extra_data, Data)
    field(:created_at, :utc_datetime_usec)
    field(:resolved_at, :utc_datetime_usec)
    field(:status, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = games, attrs \\ %{}) do
    games
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:index)
  end

  @doc """
    Returns the last index written to op_dispute_games table. If there is no one, returns -1.
  """
  @spec get_last_known_index() :: integer()
  def get_last_known_index do
    query =
      from(game in __MODULE__,
        select: game.index,
        order_by: [desc: game.index],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(-1)
  end

  @doc """
  Lists `t:Explorer.Chain.Optimism.DisputeGame.t/0`'s' in descending order based on a game index.

  """
  @spec list :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    base_query =
      from(g in __MODULE__,
        order_by: [desc: g.index],
        select: g
      )

    base_query
    |> page_dispute_games(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all(timeout: :infinity)
  end

  @doc """
    Retrieves L2 block number from the `extraData` field of the dispute game. The L2 block number can be encoded in
    different ways depending on the chain.

    ## Parameters
    - `extra_data`: The byte sequence of the extra data to retrieve L2 block number from.

    ## Returns
    - L2 block number of the dispute game.
  """
  @spec l2_block_number_from_extra_data(Data.t() | nil) :: non_neg_integer()
  def l2_block_number_from_extra_data(nil), do: 0

  def l2_block_number_from_extra_data(%Data{bytes: extra_data}) do
    current_chain_id =
      case ChainId.get_id() do
        nil -> Application.get_env(:block_scout_web, :chain_id)
        chain_id -> chain_id
      end

    first_bits =
      if current_chain_id in [@chain_id_bob_mainnet, @chain_id_bob_sepolia] do
        64
      else
        256
      end

    <<l2_block_number::size(first_bits), _::binary>> = extra_data
    l2_block_number
  end

  defp page_dispute_games(query, %PagingOptions{key: nil}), do: query

  defp page_dispute_games(query, %PagingOptions{key: {index}}) do
    from(g in query, where: g.index < ^index)
  end
end
