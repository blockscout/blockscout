defmodule Indexer.Fetcher.Arbitrum.Utils.Helper do
  @moduledoc """
    TBD
  """

  def increase_duration(data, cur_duration) do
    if Map.has_key?(data, :duration) do
      data.duration + cur_duration
    else
      cur_duration
    end
  end

  def list_to_chunks(l, chunk_size) do
    {chunks, cur_chunk, cur_chunk_size} =
      l
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce({[], [], 0}, fn chunk, {chunks, cur_chunk, cur_chunk_size} ->
        new_cur_chunk = [chunk | cur_chunk]

        if cur_chunk_size + 1 == chunk_size do
          {[new_cur_chunk | chunks], [], 0}
        else
          {chunks, new_cur_chunk, cur_chunk_size + 1}
        end
      end)

    if cur_chunk_size != 0 do
      [cur_chunk | chunks]
    else
      chunks
    end
  end

  def extend_lifecycle_txs_with_ts_and_status(lifecycle_txs, blocks_to_ts, track_finalization?) do
    lifecycle_txs
    |> Map.keys()
    |> Enum.reduce(%{}, fn tx_key, updated_txs ->
      Map.put(
        updated_txs,
        tx_key,
        Map.merge(lifecycle_txs[tx_key], %{
          timestamp: blocks_to_ts[lifecycle_txs[tx_key].block],
          status:
            if track_finalization? do
              :unfinalized
            else
              :finalized
            end
        })
      )
    end)
  end
end
