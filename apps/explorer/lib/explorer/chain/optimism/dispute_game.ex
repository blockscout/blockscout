# SPDX-License-Identifier: LicenseRef-Blockscout
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
  @chain_id_megaeth_mainnet 4326
  @chain_id_megaeth_testnet_v2 6343

  # Game types whose root claim is a Super Root rather than an Output Root (introduced by OP Stack Upgrade 20).
  # Mirrors `GameTypes.isSuperGame` from the OP Stack contracts:
  # SUPER_CANNON (4), SUPER_PERMISSIONED (5), SUPER_ASTERISC_KONA (7), SUPER_CANNON_KONA (9), ZK_DISPUTE_GAME (10).
  @super_game_types [4, 5, 7, 9, 10]

  # The only supported version of the Super Root proof encoding stored in the `extraData` of a Super Root game
  @super_root_proof_version 1

  # The size (in bytes) of one output root entry in the Super Root proof: 32 bytes of chain ID + 32 bytes of output root
  @super_root_output_root_size 64

  @typedoc """
    * `index` - A unique index of the dispute game.
    * `game_type` - A number encoding a type of the dispute game.
    * `address_hash` - The dispute game contract address.
    * `extra_data` - An extra data of the dispute game. For the games with Output Root claim it contains L2 block number.
      For the games with Super Root claim (see `super_game_type?/1`) it contains the Super Root proof
      (version byte, L2 timestamp, and the list of output roots with their chain IDs).
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
    Checks whether the given game type is a Super Root game type, i.e. the game's root claim is a Super Root
    (a commitment to the output roots of several chains at the same L2 timestamp) rather than an Output Root
    of a single chain. Such games were introduced by OP Stack Upgrade 20.

    ## Parameters
    - `game_type`: The game type number.

    ## Returns
    - `true` if the game type is a Super Root game type, `false` otherwise.
  """
  @spec super_game_type?(non_neg_integer() | nil) :: boolean()
  def super_game_type?(game_type), do: game_type in @super_game_types

  @doc """
    Retrieves the L2 sequence number of the dispute game from its `extraData` field.

    For the games with Output Root claim the sequence number is the L2 block number.
    For the games with Super Root claim (see `super_game_type?/1`) the sequence number is the L2 timestamp
    of the Super Root.

    ## Parameters
    - `game`: A map (or `t:Explorer.Chain.Optimism.DisputeGame.t/0`) with `game_type` and `extra_data` fields.

    ## Returns
    - `{:block_number, l2_block_number}` tuple for the games with Output Root claim.
    - `{:timestamp, l2_timestamp}` tuple for the games with Super Root claim (the timestamp is in UNIX seconds).
  """
  @spec l2_sequence_number(%{:game_type => non_neg_integer() | nil, :extra_data => Data.t() | nil, any() => any()}) ::
          {:block_number, non_neg_integer()} | {:timestamp, non_neg_integer()}
  def l2_sequence_number(%{game_type: game_type, extra_data: extra_data}) do
    if super_game_type?(game_type) do
      {:timestamp, l2_timestamp_from_extra_data(extra_data)}
    else
      {:block_number, l2_block_number_from_extra_data(extra_data)}
    end
  end

  @doc """
    Retrieves L2 block number from the `extraData` field of the dispute game with Output Root claim.
    The L2 block number can be encoded in different ways depending on the chain.

    ## Parameters
    - `extra_data`: The byte sequence of the extra data to retrieve L2 block number from.

    ## Returns
    - L2 block number of the dispute game. Zero if the extra data is unknown or has unexpected format.
  """
  @spec l2_block_number_from_extra_data(Data.t() | nil) :: non_neg_integer()
  def l2_block_number_from_extra_data(nil), do: 0

  def l2_block_number_from_extra_data(%Data{bytes: extra_data}) do
    first_bits =
      if ChainId.get_id() in [
           @chain_id_bob_mainnet,
           @chain_id_bob_sepolia,
           @chain_id_megaeth_mainnet,
           @chain_id_megaeth_testnet_v2
         ] do
        64
      else
        256
      end

    case extra_data do
      <<l2_block_number::size(first_bits), _::binary>> -> l2_block_number
      _ -> 0
    end
  end

  @doc """
    Retrieves L2 timestamp from the `extraData` field of the dispute game with Super Root claim.

    The extra data of such a game contains the Super Root proof encoded as follows:
    1 byte of version (must be equal to 1), 8 bytes of the L2 timestamp (big-endian uint64),
    and 64 bytes for each output root (32 bytes of chain ID and 32 bytes of the output root).
    See `Encoding.decodeSuperRootProof` in the OP Stack contracts.

    ## Parameters
    - `extra_data`: The byte sequence of the extra data to retrieve L2 timestamp from.

    ## Returns
    - L2 timestamp (in UNIX seconds) of the Super Root. Zero if the extra data is unknown or has unexpected format.
  """
  @spec l2_timestamp_from_extra_data(Data.t() | nil) :: non_neg_integer()
  def l2_timestamp_from_extra_data(nil), do: 0

  def l2_timestamp_from_extra_data(%Data{
        bytes: <<@super_root_proof_version, l2_timestamp::size(64), output_roots::binary>>
      })
      when byte_size(output_roots) > 0 and rem(byte_size(output_roots), @super_root_output_root_size) == 0,
      do: l2_timestamp

  def l2_timestamp_from_extra_data(%Data{}), do: 0

  defp page_dispute_games(query, %PagingOptions{key: nil}), do: query

  defp page_dispute_games(query, %PagingOptions{key: {index}}) do
    from(g in query, where: g.index < ^index)
  end
end
