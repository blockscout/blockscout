defmodule Explorer.Chain.Mud.Schema do
  @moduledoc """
    Represents a MUD framework database record schema.
  """

  defmodule FieldSchema do
    @moduledoc """
      Represents a MUD framework database record field schema.
    """

    defstruct [:word]

    @type t :: %__MODULE__{
            word: <<_::256>>
          }

    @spec from(binary()) :: :error | t()
    def from(<<bin::binary-size(32)>>), do: %__MODULE__{word: bin}

    def from("0x" <> <<hex::binary-size(64)>>) do
      with {:ok, bin} <- Base.decode16(hex, case: :mixed) do
        %__MODULE__{word: bin}
      end
    end

    def from(_), do: :error

    def type_of(%FieldSchema{word: word}, index), do: :binary.at(word, index + 4)
  end

  @enforce_keys [:key_schema, :value_schema, :key_names, :value_names]
  defstruct [:key_schema, :value_schema, :key_names, :value_names]

  defimpl Jason.Encoder, for: Explorer.Chain.Mud.Schema do
    alias Explorer.Chain.Mud.Schema
    alias Jason.Encode

    def encode(data, opts) do
      Encode.map(
        %{
          "key_types" => data.key_schema |> Schema.decode_type_names(),
          "value_types" => data.value_schema |> Schema.decode_type_names(),
          "key_names" => data.key_names,
          "value_names" => data.value_names
        },
        opts
      )
    end
  end

  def decode_types(layout_schema) do
    static_fields_count = :binary.at(layout_schema.word, 2)
    dynamic_fields_count = :binary.at(layout_schema.word, 3)

    {static_fields_count, :binary.bin_to_list(layout_schema.word, 4, static_fields_count + dynamic_fields_count)}
  end

  def decode_type_names(layout_schema) do
    {_, types} = decode_types(layout_schema)
    types |> Enum.map(&encode_type_name/1)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp encode_type_name(type) do
    case type do
      _ when type < 32 -> "uint" <> Integer.to_string((type + 1) * 8)
      _ when type < 64 -> "int" <> Integer.to_string((type - 31) * 8)
      _ when type < 96 -> "bytes" <> Integer.to_string(type - 63)
      96 -> "bool"
      97 -> "address"
      _ when type < 196 -> encode_type_name(type - 98) <> "[]"
      196 -> "bytes"
      197 -> "string"
      _ -> "unknown_type_" <> Integer.to_string(type)
    end
  end
end
