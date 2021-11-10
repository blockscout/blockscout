defmodule Explorer.Chain.Import.Runner.Block.SecondDegreeRelations do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`.
  """

  require Ecto.Query
  require Logger

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Block, Hash, Import}

  @behaviour Import.Runner

  @timeout 60_000

  @type imported :: [
          %{
            required(:nephew_hash) => Hash.Full.t(),
            required(:uncle_hash) => Hash.Full.t(),
            required(:index) => non_neg_integer()
          }
        ]

  @impl Import.Runner
  def ecto_schema_module, do: Block.SecondDegreeRelation

  @impl Import.Runner
  def option_key, do: :block_second_degree_relations

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type:
        "[%{uncle_hash: Explorer.Chain.Hash.t(), nephew_hash: Explorer.Chain.Hash.t(), index: non_neg_integer()]",
      value_description: "List of maps of the `t:#{ecto_schema_module()}.t/0` `uncle_hash`, `nephew_hash` and `index`"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, options) when is_map(options) do
    Logger.info("### Second degree relations run STARTED ###")

    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)

    Multi.run(multi, :block_second_degree_relations, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout
        }) ::
          {:ok, %{nephew_hash: Hash.Full.t(), uncle_hash: Hash.Full.t(), index: non_neg_integer()}}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout} = options) when is_atom(repo) and is_list(changes_list) do
    Logger.info(["### Second degree relations insert started ###"])
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce SeconDegreeRelation ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.nephew_hash, &1.uncle_hash})

    {:ok, second_degree_relations} =
      Import.insert_changes_list(repo, ordered_changes_list,
        conflict_target: [:nephew_hash, :uncle_hash],
        on_conflict: on_conflict,
        for: Block.SecondDegreeRelation,
        returning: [:nephew_hash, :uncle_hash, :index],
        timeout: timeout,
        # block_second_degree_relations doesn't have timestamps
        timestamps: %{}
      )

    Logger.info(["### Second degree relations insert FINISHED ###"])

    {:ok, second_degree_relations}
  end

  defp default_on_conflict do
    from(
      block_second_degree_relation in Block.SecondDegreeRelation,
      update: [
        set: [
          uncle_fetched_at:
            fragment("LEAST(?, EXCLUDED.uncle_fetched_at)", block_second_degree_relation.uncle_fetched_at),
          index: fragment("EXCLUDED.index")
        ]
      ],
      where:
        fragment(
          "(LEAST(?, EXCLUDED.uncle_fetched_at), EXCLUDED.index) IS DISTINCT FROM (?, ?)",
          block_second_degree_relation.uncle_fetched_at,
          block_second_degree_relation.uncle_fetched_at,
          block_second_degree_relation.index
        )
    )
  end
end
