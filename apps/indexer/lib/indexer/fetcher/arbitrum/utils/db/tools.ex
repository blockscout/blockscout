defmodule Indexer.Fetcher.Arbitrum.Utils.Db.Tools do
  @moduledoc """
    Internal database utility functions for Arbitrum-related data processing.

    This module is designed to be used exclusively within the
    `Indexer.Fetcher.Arbitrum.Utils.Db` namespace.
  """

  alias Explorer.Chain.{Data, Hash}

  @doc """
    Converts an Arbitrum-related database record to a map with specified keys and optional encoding.

    This function is used to transform various Arbitrum-specific database records
    (such as LifecycleTransaction, BatchBlock, or Message) into maps containing
    only the specified keys. It's particularly useful for preparing data for
    import or further processing of Arbitrum blockchain data.

    Parameters:
      - `required_keys`: A list of atoms representing the keys to include in the
        output map.
      - `record`: The database record or struct to be converted.
      - `encode`: Boolean flag to determine if Hash and Data types should be
        encoded to strings (default: false). When true, Hash and Data are
        converted to string representations; otherwise, their raw bytes are used.

    Returns:
      - A map containing only the required keys from the input record. Hash and
        Data types are either encoded to strings or left as raw bytes based on
        the `encode` parameter.
  """
  @spec db_record_to_map([atom()], map(), boolean()) :: map()
  def db_record_to_map(required_keys, record, encode \\ false) do
    required_keys
    |> Enum.reduce(%{}, fn key, record_as_map ->
      raw_value = Map.get(record, key)

      # credo:disable-for-lines:5 Credo.Check.Refactor.Nesting
      value =
        case raw_value do
          %Hash{} -> if(encode, do: Hash.to_string(raw_value), else: raw_value.bytes)
          %Data{} -> if(encode, do: Data.to_string(raw_value), else: raw_value.bytes)
          _ -> raw_value
        end

      Map.put(record_as_map, key, value)
    end)
  end
end
