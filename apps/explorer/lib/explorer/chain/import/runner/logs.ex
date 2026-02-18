defmodule Explorer.Chain.Import.Runner.Logs do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Log.t/0`.
  """

  use Utils.RuntimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, Log}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Log.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Log

  @impl Import.Runner
  def option_key, do: :logs

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :logs, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :logs,
        :logs
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [Log.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Add compressed data fields to changes
    changes_list_with_compression =
      Enum.map(changes_list, fn changes ->
        case Map.get(changes, :data) do
          %{bytes: data_bytes} when is_binary(data_bytes) ->
            changes
            |> Map.put(:compressed_data_gzip, compress_gzip(data_bytes))
            |> Map.put(:compressed_data_lz4, compress_lz4(data_bytes))
            |> Map.put(:compressed_data_brotli, compress_brotli(data_bytes))
            |> Map.put(:compressed_data_zstd, compress_zstd(data_bytes))

          _ ->
            changes
        end
      end)

    # Enforce Log ShareLocks order (see docs: sharelocks.md)
    {ordered_changes_list, conflict_target} =
      case chain_identity() do
        {:optimism, :celo} ->
          {
            Enum.sort_by(changes_list_with_compression, &{&1.block_hash, &1.index}),
            [:index, :block_hash]
          }

        _ ->
          {
            Enum.sort_by(changes_list_with_compression, &{&1.transaction_hash, &1.block_hash, &1.index}),
            [:transaction_hash, :index, :block_hash]
          }
      end

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: conflict_target,
        on_conflict: on_conflict,
        for: Log,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    case chain_identity() do
      {:optimism, :celo} ->
        from(
          log in Log,
          update: [
            set: [
              address_hash: fragment("EXCLUDED.address_hash"),
              data: fragment("EXCLUDED.data"),
              first_topic: fragment("EXCLUDED.first_topic"),
              second_topic: fragment("EXCLUDED.second_topic"),
              third_topic: fragment("EXCLUDED.third_topic"),
              fourth_topic: fragment("EXCLUDED.fourth_topic"),
              compressed_data_gzip: fragment("EXCLUDED.compressed_data_gzip"),
              compressed_data_lz4: fragment("EXCLUDED.compressed_data_lz4"),
              compressed_data_brotli: fragment("EXCLUDED.compressed_data_brotli"),
              compressed_data_zstd: fragment("EXCLUDED.compressed_data_zstd"),
              # Don't update `index` as it is part of the composite primary key and used for the conflict target
              transaction_hash: fragment("EXCLUDED.transaction_hash"),
              inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", log.inserted_at),
              updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", log.updated_at)
            ]
          ],
          where:
            fragment(
              "(EXCLUDED.address_hash, EXCLUDED.data, EXCLUDED.first_topic, EXCLUDED.second_topic, EXCLUDED.third_topic, EXCLUDED.fourth_topic, EXCLUDED.transaction_hash) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?)",
              log.address_hash,
              log.data,
              log.first_topic,
              log.second_topic,
              log.third_topic,
              log.fourth_topic,
              log.transaction_hash
            )
        )

      _ ->
        from(
          log in Log,
          update: [
            set: [
              address_hash: fragment("EXCLUDED.address_hash"),
              data: fragment("EXCLUDED.data"),
              first_topic: fragment("EXCLUDED.first_topic"),
              second_topic: fragment("EXCLUDED.second_topic"),
              third_topic: fragment("EXCLUDED.third_topic"),
              fourth_topic: fragment("EXCLUDED.fourth_topic"),
              compressed_data_gzip: fragment("EXCLUDED.compressed_data_gzip"),
              compressed_data_lz4: fragment("EXCLUDED.compressed_data_lz4"),
              compressed_data_brotli: fragment("EXCLUDED.compressed_data_brotli"),
              compressed_data_zstd: fragment("EXCLUDED.compressed_data_zstd"),
              # Don't update `index` as it is part of the composite primary key and used for the conflict target
              # Don't update `transaction_hash` as it is part of the composite primary key and used for the conflict target
              inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", log.inserted_at),
              updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", log.updated_at)
            ]
          ],
          where:
            fragment(
              "(EXCLUDED.address_hash, EXCLUDED.data, EXCLUDED.first_topic, EXCLUDED.second_topic, EXCLUDED.third_topic, EXCLUDED.fourth_topic) IS DISTINCT FROM (?, ?, ?, ?, ?, ?)",
              log.address_hash,
              log.data,
              log.first_topic,
              log.second_topic,
              log.third_topic,
              log.fourth_topic
            )
        )
    end
  end

  # Compress data using gzip
  defp compress_gzip(data) when is_binary(data) do
    :zlib.gzip(data)
  end

  defp compress_gzip(_), do: nil

  # Compress data using Brotli
  defp compress_brotli(data) when is_binary(data) do
    case ExBrotli.compress(data) do
      {:ok, compressed} -> compressed
      {:error, _} -> nil
    end
  end

  defp compress_brotli(_), do: nil

  # Compress data using LZ4 (via lz4_erl)
  defp compress_lz4(data) when is_binary(data) do
    case :lz4.compress(data) do
      {:ok, compressed} -> compressed
      {:error, _} -> nil
      compressed when is_binary(compressed) -> compressed
    end
  end

  # Compress data using Zstd (via ezstd)
  defp compress_zstd(data) when is_binary(data) do
    :ezstd.compress(data)
  rescue
    _ -> nil
  end

  defp compress_zstd(_), do: nil
end
