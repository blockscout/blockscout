defmodule Explorer.BloomFilter do
  @moduledoc """
  Eth Bloom filter realization. Reference: https://github.com/NethermindEth/nethermind/blob/d61c78af6de2d0a89bd4efd6bfed62cb6b774f59/src/Nethermind/Nethermind.Core/Bloom.cs
  """
  import Bitwise

  alias Explorer.BloomFilter
  alias Explorer.Chain.Log

  @bloom_byte_length 256
  @bloom_bit_length 8 * @bloom_byte_length

  defstruct filter: <<0::2048>>

  @doc """
  Computes bloom filter from list of logs
  """
  @spec logs_bloom([Log.t()]) :: <<_::2048>>
  def logs_bloom(logs) do
    logs
    |> Enum.reduce(%BloomFilter{}, fn log, acc ->
      topics =
        Enum.reject(
          [log.first_topic, log.second_topic, log.third_topic, log.fourth_topic],
          &is_nil/1
        )

      acc_new =
        acc
        |> add(log.address_hash.bytes)

      Enum.reduce(topics, acc_new, fn topic, acc -> add(acc, topic.bytes) end)
    end)
    |> Map.get(:filter)
  end

  defp add(%BloomFilter{filter: filter} = bloom, element) do
    {i1, i2, i3} = get_extract(element)

    new_filter =
      filter
      |> set_index(i1)
      |> set_index(i2)
      |> set_index(i3)

    %BloomFilter{bloom | filter: new_filter}
  end

  defp hash_function(data), do: ExKeccak.hash_256(data)

  defp set_index(filter, index) do
    byte_position = div(index, 8)
    shift = rem(index, 8)

    byte = :binary.at(filter, byte_position)
    value = set_bit(byte, shift)

    <<head::binary-size(byte_position), _byte::binary-size(1), tail::binary>> = filter

    <<head::binary, value, tail::binary>>
  end

  defp set_bit(byte, bit) do
    mask = 1 <<< (7 - bit)

    bor(byte, mask)
  end

  defp get_extract(bytes) do
    hash = hash_function(bytes)

    {get_index(hash, 0, 1), get_index(hash, 2, 3), get_index(hash, 4, 5)}
  end

  defp get_index(bytes, index_1, index_2) do
    @bloom_bit_length - 1 - rem((:binary.at(bytes, index_1) <<< 8) + :binary.at(bytes, index_2), 2048)
  end
end
