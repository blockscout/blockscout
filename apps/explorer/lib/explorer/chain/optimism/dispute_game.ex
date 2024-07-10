defmodule Explorer.Chain.Optimism.DisputeGame do
  @moduledoc "Models a dispute game for Optimism."

  use Explorer.Schema

  import Ecto.Query
  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.{Data, Hash}
  alias Explorer.{PagingOptions, Repo}

  @required_attrs ~w(index game_type address created_at)a
  @optional_attrs ~w(extra_data resolved_at status)a

  @default_paging_options %PagingOptions{page_size: 50}

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          game_type: non_neg_integer(),
          address: Hash.t(),
          extra_data: Data.t() | nil,
          created_at: DateTime.t(),
          resolved_at: DateTime.t() | nil,
          status: non_neg_integer() | nil
        }

  @primary_key false
  schema "op_dispute_games" do
    field(:index, :integer, primary_key: true)
    field(:game_type, :integer)
    field(:address, Hash.Address)
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
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    base_query =
      from(g in __MODULE__,
        order_by: [desc: g.index],
        select: g
      )

    base_query
    |> page_dispute_games(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  defp page_dispute_games(query, %PagingOptions{key: nil}), do: query

  defp page_dispute_games(query, %PagingOptions{key: {index}}) do
    from(g in query, where: g.index < ^index)
  end
end
