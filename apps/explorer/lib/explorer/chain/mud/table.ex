defmodule Explorer.Chain.Mud.Table do
  @moduledoc """
    Represents a MUD framework database table.
  """

  alias Explorer.Chain.Hash

  @enforce_keys [:table_id, :table_full_name, :table_type, :table_namespace, :table_name]
  @derive Jason.Encoder
  defstruct [:table_id, :table_full_name, :table_type, :table_namespace, :table_name]

  def from(%Hash{byte_count: 32, bytes: raw} = table_id) do
    <<prefix::binary-size(2), namespace::binary-size(14), table_name::binary-size(16)>> = raw

    trimmed_namespace = String.trim_trailing(namespace, "\u0000")
    trimmed_table_name = String.trim_trailing(table_name, "\u0000")

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
end
