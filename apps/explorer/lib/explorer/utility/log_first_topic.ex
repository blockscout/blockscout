# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.LogFirstTopic do
  @moduledoc """
  Module is responsible for keeping the log first_topic value to id correspondence.
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Repo

  typed_schema "log_first_topics" do
    field(:value, Hash.Full)

    timestamps(updated_at: false)
  end

  @doc false
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(log_first_topic \\ %__MODULE__{}, params) do
    cast(log_first_topic, params, [:value])
  end

  @doc """
  Retrieves the first_topic id for a given first_topic value.

  ## Parameters
  - `value`: The value to look up

  ## Returns
  - The first_topic id if found, nil otherwise
  """
  @spec value_to_id(Hash.Full.t() | binary()) :: integer() | nil
  def value_to_id(nil), do: nil

  def value_to_id(value) do
    [value]
    |> values_to_ids()
    |> List.first()
  end

  @doc """
  Retrieves all first_topic ids for the given first_topic values.

  ## Parameters
  - `values`: A list of first_topic values to look up

  ## Returns
  - A list of first_topic ids for the matching mappings
  """
  @spec values_to_ids([Hash.Full.t() | binary()]) :: [integer()]
  def values_to_ids(values) do
    __MODULE__
    |> where([t], t.value in ^values)
    |> select([t], t.id)
    |> Repo.all()
  end

  @doc """
  Retrieves first topic mappings by their ids.

  ## Parameters
  - `ids`: A list of first topic mapping ids to look up

  ## Returns
  - A list of `%Explorer.Utility.LogFirstTopic{}` structs for the matching ids
  """
  @spec fetch_by_ids([integer()]) :: [__MODULE__.t()]
  def fetch_by_ids(ids) do
    __MODULE__
    |> where([t], t.id in ^ids)
    |> Repo.all()
  end

  @doc """
  Finds the mapping for the given first topic or creates it if it does not yet
  exist.

  This function is a convenience wrapper around `find_or_create_multiple/2`
  for a single first topic.

  ## Parameters
  - `first_topic`: The first topic to look up or create a mapping for

  ## Returns
  - An `%Explorer.Utility.LogFirstTopic{}` struct for the given topic
  - `nil` if `first_topic` is `nil`
  """
  @spec find_or_create(Hash.Full.t() | nil) :: __MODULE__.t() | nil
  def find_or_create(first_topic) do
    [first_topic]
    |> find_or_create_multiple(false)
    |> List.first()
  end

  @doc """
  Finds or creates mappings for the given first topics in bulk.

  The input is normalized by removing `nil` values, deduplicating hashes, and
  casting each topic to `Hash.Full`. Missing mappings are inserted with
  `on_conflict: :nothing`, so existing mappings are preserved.

  ## Parameters
  - `first_topics`: A list of first topics to resolve
  - `to_map?`: When `true`, returns a map of `%{first_topic => first_topic_id}`.
    When `false`, returns the list of `%Explorer.Utility.LogFirstTopic{}`
    records

  ## Returns
  - A map of first topics to first topic ids when `to_map?` is `true`
  - A list of `%Explorer.Utility.LogFirstTopic{}` structs when
    `to_map?` is `false`
  """
  @spec find_or_create_multiple([Hash.Full.t() | nil], true) :: %{optional(Hash.Full.t()) => integer()}
  @spec find_or_create_multiple([Hash.Full.t() | nil], false) :: [__MODULE__.t()]
  def find_or_create_multiple(first_topics, to_map? \\ true) do
    filtered_first_topics =
      first_topics
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.map(fn first_topic ->
        {:ok, casted} = Hash.Full.cast(first_topic)
        casted
      end)
      |> Enum.sort()

    Repo.safe_insert_all(
      __MODULE__,
      Enum.map(filtered_first_topics, &%{value: &1, inserted_at: DateTime.utc_now()}),
      on_conflict: :nothing
    )

    __MODULE__
    |> where([t], t.value in ^filtered_first_topics)
    |> Repo.all()
    |> then(fn records ->
      if to_map?, do: Map.new(records, &{to_string(&1.value), &1.id}), else: records
    end)
  end
end
