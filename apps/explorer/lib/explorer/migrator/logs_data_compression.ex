defmodule Explorer.Migrator.LogsDataCompression do
  @moduledoc """
  Fills the compressed_data_gzip, compressed_data_lz4, compressed_data_brotli, and compressed_data_zstd
  columns in the logs table for benchmarking different compression algorithms.

  Compression algorithms:
  - Gzip: uses Erlang's :zlib.gzip/1
  - Brotli: uses ExBrotli.compress/1 from ex_brotli library
  - LZ4: uses :lz4.compress/1 from lz4_erl library
  - Zstd: uses :ezstd.compress/1 from ezstd library
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Log
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "logs_data_compression"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([log], {log.block_hash, log.index})
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(log in Log,
      where:
        is_nil(log.compressed_data_gzip) or is_nil(log.compressed_data_lz4) or
          is_nil(log.compressed_data_brotli) or is_nil(log.compressed_data_zstd)
    )
  end

  @impl FillingMigration
  def update_batch(log_identifiers) do
    log_identifiers
    |> Enum.each(fn {block_hash, index} ->
      # Fetch the data for this log
      case Repo.one(
             from(l in Log,
               where: l.block_hash == ^block_hash and l.index == ^index,
               select: l.data
             ),
             timeout: :infinity
           ) do
        nil ->
          :ok

        data when not is_nil(data) ->
          # Compress using all algorithms
          compressed_gzip = compress_gzip(data.bytes)
          compressed_lz4 = compress_lz4(data.bytes)
          compressed_brotli = compress_brotli(data.bytes)
          compressed_zstd = compress_zstd(data.bytes)

          # Update the compressed columns
          from(l in Log,
            where: l.block_hash == ^block_hash and l.index == ^index
          )
          |> Repo.update_all(
            [
              set: [
                compressed_data_gzip: compressed_gzip,
                compressed_data_lz4: compressed_lz4,
                compressed_data_brotli: compressed_brotli,
                compressed_data_zstd: compressed_zstd
              ]
            ],
            timeout: :infinity
          )
      end
    end)
  end

  @impl FillingMigration
  def update_cache do
    # No cache update needed for this benchmark migration
    :ok
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

  defp compress_lz4(_), do: nil

  # Compress data using Zstd (via ezstd)
  defp compress_zstd(data) when is_binary(data) do
    :ezstd.compress(data)
  rescue
    _ -> nil
  end

  defp compress_zstd(_), do: nil
end
