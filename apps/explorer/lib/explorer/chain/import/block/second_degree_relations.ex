defmodule Explorer.Chain.Import.Block.SecondDegreeRelations do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Block, Hash, Import}

  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout
        }
  @type imported :: [
          %{required(:nephew_hash) => Hash.Full.t(), required(:uncle_hash) => Hash.Full.t()}
        ]

  def run(multi, ecto_schema_module_to_changes_list, options)
      when is_map(ecto_schema_module_to_changes_list) and is_map(options) do
    case ecto_schema_module_to_changes_list do
      %{Block.SecondDegreeRelation => block_second_degree_relations_changes} ->
        Multi.run(multi, :block_second_degree_relations, fn _ ->
          insert(
            block_second_degree_relations_changes,
            %{
              timeout: options[:block_second_degree_relations][:timeout] || @timeout
            }
          )
        end)

      _ ->
        multi
    end
  end

  def timeout, do: @timeout

  @spec insert([map()], %{required(:timeout) => timeout}) ::
          {:ok, %{nephew_hash: Hash.Full.t(), uncle_hash: Hash.Full.t()}} | {:error, [Changeset.t()]}
  defp insert(changes_list, %{timeout: timeout}) when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.nephew_hash, &1.uncle_hash})

    Import.insert_changes_list(ordered_changes_list,
      conflict_target: [:nephew_hash, :uncle_hash],
      on_conflict:
        from(
          block_second_degree_relation in Block.SecondDegreeRelation,
          update: [
            set: [
              uncle_fetched_at:
                fragment("LEAST(?, EXCLUDED.uncle_fetched_at)", block_second_degree_relation.uncle_fetched_at)
            ]
          ]
        ),
      for: Block.SecondDegreeRelation,
      returning: [:nephew_hash, :uncle_hash],
      timeout: timeout,
      # block_second_degree_relations doesn't have timestamps
      timestamps: %{}
    )
  end
end
