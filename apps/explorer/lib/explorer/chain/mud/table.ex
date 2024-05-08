defmodule Explorer.Chain.Mud.Table do
  @moduledoc """
    Represents a decoded MUD framework database table ID.
  """

  alias Explorer.Chain.Hash

  @enforce_keys [:table_id, :table_full_name, :table_type, :table_namespace, :table_name]
  @derive Jason.Encoder
  defstruct [:table_id, :table_full_name, :table_type, :table_namespace, :table_name]

  def from(%Hash{byte_count: 32, bytes: raw} = table_id) do
    <<prefix::binary-size(2), namespace::binary-size(14), table_name::binary-size(16)>> = raw

    trimmed_namespace = String.trim_trailing(namespace, <<0>>)
    trimmed_table_name = String.trim_trailing(table_name, <<0>>)

    table_full_name =
      if String.length(trimmed_namespace) > 0 do
        prefix <> "." <> trimmed_namespace <> "." <> trimmed_table_name
      else
        prefix <> "." <> trimmed_table_name
      end

    table_type =
      case prefix do
        "ot" -> "offchain"
        "tb" -> "onchain"
        _ -> "unknown"
      end

    %__MODULE__{
      table_id: table_id,
      table_full_name: table_full_name,
      table_type: table_type,
      table_namespace: trimmed_namespace,
      table_name: trimmed_table_name
    }
  end

  def table_full_name_to_table_id(full_name) do
    parts =
      case String.split(full_name, ".") do
        [prefix, name] -> [prefix, "", name]
        [prefix, namespace, name] -> [prefix, namespace, name]
        _ -> :error
      end

    with [prefix, namespace, name] <- parts,
         {:ok, prefix} <- normalize_length(prefix, 2),
         {:ok, namespace} <- normalize_length(namespace, 14),
         {:ok, name} <- normalize_length(name, 16) do
      Hash.Full.cast(prefix <> namespace <> name)
    end
  end

  defp normalize_length(str, len) do
    if String.length(str) <= len do
      {:ok, String.pad_trailing(str, len, <<0>>)}
    else
      :error
    end
  end
end
