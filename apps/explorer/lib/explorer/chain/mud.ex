defmodule Explorer.Chain.Mud do
  @moduledoc """
    Represents a MUD framework database record.
  """
  use Explorer.Schema

  import Ecto.Query,
    only: [
      distinct: 2,
      select: 3,
      where: 3,
      limit: 2
    ]

  alias ABI.{TypeDecoder, TypeEncoder}
  alias Explorer.{Chain, PagingOptions, Repo, SortingHelper}

  alias Explorer.Chain.{
    Block,
    Data,
    Hash,
    Mud,
    Mud.Schema,
    Mud.Schema.FieldSchema
  }

  require Logger

  @schema_prefix "mud"

  @store_tables_table_id Base.decode16!("746273746f72650000000000000000005461626c657300000000000000000000", case: :lower)

  # https://github.com/latticexyz/mud/blob/cc4f4246e52982354e398113c46442910f9b04bb/packages/store/src/codegen/tables/Tables.sol#L34-L42
  @store_tables_table_schema %Schema{
    key_schema: FieldSchema.from("0x002001005f000000000000000000000000000000000000000000000000000000"),
    value_schema: FieldSchema.from("0x006003025f5f5fc4c40000000000000000000000000000000000000000000000"),
    key_names: ["tableId"],
    value_names: ["fieldLayout", "keySchema", "valueSchema", "abiEncodedKeyNames", "abiEncodedValueNames"]
  }

  @primary_key false
  typed_schema "records" do
    field(:address, Hash.Address, null: false)
    field(:table_id, Hash.Full, null: false)
    field(:key_bytes, Data)
    field(:key0, Hash.Full)
    field(:key1, Hash.Full)
    field(:static_data, Data)
    field(:encoded_lengths, Data)
    field(:dynamic_data, Data)
    field(:is_deleted, :boolean, null: false)
    field(:block_number, :decimal, null: false)
    field(:log_index, :decimal, null: false)
  end

  def enabled? do
    Application.get_env(:explorer, __MODULE__)[:enabled]
  end

  def worlds_list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    Mud
    |> select([r], r.address)
    |> distinct(true)
    |> page_worlds(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.Mud.all()
  end

  defp page_worlds(query, %PagingOptions{key: %{world: world}}) do
    query |> where([item], item.address > ^world)
  end

  defp page_worlds(query, _), do: query

  def worlds_count do
    Mud
    |> select([r], r.address)
    |> distinct(true)
    |> Repo.Mud.aggregate(:count)
  end

  def world_table_schema(world, table_id) do
    world_table_schemas(world, [table_id])[table_id]
  end

  def world_tables(world, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    filter_namespace = Keyword.get(options, :filter_namespace, nil)

    Mud
    |> select([r], r.table_id)
    |> distinct(true)
    |> where([r], r.address == ^world)
    |> filter_tables(filter_namespace)
    |> page_tables(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.Mud.all()
  end

  defp page_tables(query, %PagingOptions{key: %{table_id: table_id}}) do
    query |> where([item], item.table_id > ^table_id)
  end

  defp page_tables(query, _), do: query

  def world_tables_count(world, options \\ []) do
    filter_namespace = Keyword.get(options, :filter_namespace, nil)

    Mud
    |> select([r], r.table_id)
    |> distinct(true)
    |> where([r], r.address == ^world)
    |> filter_tables(filter_namespace)
    |> Repo.Mud.aggregate(:count)
  end

  defp filter_tables(query, nil), do: query

  defp filter_tables(query, namespace) do
    query |> where([tb], fragment("substring(? FROM 3 FOR 14)", tb.table_id) == ^namespace)
  end

  @default_sorting [
    asc: :key_bytes
  ]

  def world_table_records(world, table_id, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    sorting = Keyword.get(options, :sorting, [])

    Mud
    |> where([r], r.address == ^world and r.table_id == ^table_id)
    |> filter_records(:key0, Keyword.get(options, :filter_key0))
    |> filter_records(:key1, Keyword.get(options, :filter_key1))
    |> SortingHelper.apply_sorting(sorting, @default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)
    |> Repo.Mud.all()
  end

  def preload_records_timestamps(records) do
    block_numbers = records |> Enum.map(& &1.block_number |> Decimal.to_integer()) |> Enum.uniq()

    Block
    |> where([b], b.number in ^block_numbers)
    |> select([b], {b.number, b.timestamp})
    |> Repo.all()
    |> Enum.into(%{})
  end

  def world_table_records_count(world, table_id, options \\ []) do
    Mud
    |> where([r], r.address == ^world and r.table_id == ^table_id)
    |> filter_records(:key0, Keyword.get(options, :filter_key0))
    |> filter_records(:key1, Keyword.get(options, :filter_key1))
    |> Repo.Mud.aggregate(:count)
  end

  defp filter_records(query, _key_name, nil), do: query

  defp filter_records(query, :key0, key), do: query |> where([r], r.key0 == ^key)

  defp filter_records(query, :key1, key), do: query |> where([r], r.key1 == ^key)

  def world_table_record(world, table_id, record_id) do
    Mud
    |> where([r], r.address == ^world and r.table_id == ^table_id and r.key_bytes == ^record_id)
    |> Repo.Mud.one()
  end

  def world_table_schemas(world, table_ids) do
    Mud
    |> where([r], r.address == ^world and r.table_id == ^@store_tables_table_id and r.key0 in ^table_ids)
    |> Repo.Mud.all()
    |> Enum.into(%{}, fn r ->
      schema_record = decode_record(r, @store_tables_table_schema)

      schema = %Schema{
        key_schema: schema_record["keySchema"] |> FieldSchema.from(),
        value_schema: schema_record["valueSchema"] |> FieldSchema.from(),
        key_names: schema_record["abiEncodedKeyNames"] |> decode_abi_encoded_strings(),
        value_names: schema_record["abiEncodedValueNames"] |> decode_abi_encoded_strings()
      }

      {r.key0, schema}
    end)
  end

  defp decode_abi_encoded_strings("0x" <> hex_encoded) do
    hex_encoded
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw([{:array, :string}])
    |> Enum.at(0)
  end

  def decode_record(nil, _schema), do: nil

  def decode_record(_record, nil), do: nil

  def decode_record(record, schema) do
    key = decode_key_tuple(record.key_bytes.bytes, schema.key_names, schema.key_schema)

    value =
      if record.is_deleted do
        schema.value_names |> Enum.into(%{}, &{&1, nil})
      else
        decode_fields(
          record.static_data,
          record.encoded_lengths,
          record.dynamic_data,
          schema.value_names,
          schema.value_schema
        )
      end

    key |> Map.merge(value)
  end

  def decode_key_tuple(key_bytes, fields, layout_schema) do
    {_, types} = Schema.decode_types(layout_schema)

    fields
    |> Enum.zip(types)
    |> Enum.reduce({%{}, key_bytes}, fn {field, type}, {acc, data} ->
      type_size = static_type_size(type)
      <<word::binary-size(32), rest::binary>> = data

      enc =
        if type < 64 or type >= 96 do
          :binary.part(word, 32 - type_size, type_size)
        else
          :binary.part(word, 0, type_size)
        end

      decoded = decode_type(type, enc)

      {Map.put(acc, field, decoded), rest}
    end)
    |> elem(0)
  end

  def decode_fields(static_data, encoded_lengths, dynamic_data, fields, layout_schema) do
    {static_fields_count, types} = Schema.decode_types(layout_schema)

    {static_types, dynamic_types} = Enum.split(types, static_fields_count)

    {static_fields, dynamic_fields} = Enum.split(fields, static_fields_count)

    res =
      static_fields
      |> Enum.zip(static_types)
      |> Enum.reduce({%{}, (static_data && static_data.bytes) || <<>>}, fn {field, type}, {acc, data} ->
        type_size = static_type_size(type)
        <<enc::binary-size(type_size), rest::binary>> = data
        decoded = decode_type(type, enc)
        {Map.put(acc, field, decoded), rest}
      end)
      |> elem(0)

    if encoded_lengths == nil or byte_size(encoded_lengths.bytes) == 0 do
      res
    else
      dynamic_type_lengths =
        encoded_lengths.bytes
        |> :binary.bin_to_list(0, 25)
        |> Enum.chunk_every(5)
        |> Enum.reverse()
        |> Enum.map(&(&1 |> :binary.list_to_bin() |> :binary.decode_unsigned()))

      [dynamic_fields, dynamic_types, dynamic_type_lengths]
      |> Enum.zip()
      |> Enum.reduce({res, (dynamic_data && dynamic_data.bytes) || <<>>}, fn {field, type, length}, {acc, data} ->
        <<enc::binary-size(length), rest::binary>> = data
        decoded = decode_type(type, enc)

        {Map.put(acc, field, decoded), rest}
      end)
      |> elem(0)
    end
  end

  def static_type_size(type) do
    case type do
      _ when type < 97 -> rem(type, 32) + 1
      97 -> 20
      _ -> 0
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def decode_type(type, raw) do
    case type do
      _ when type < 32 ->
        raw |> :binary.decode_unsigned() |> Integer.to_string()

      _ when type < 64 ->
        size = static_type_size(type)
        <<int::signed-integer-size(size * 8)>> = raw
        int |> Integer.to_string()

      _ when type < 96 or type == 97 or type == 196 ->
        "0x" <> Base.encode16(raw, case: :lower)

      96 ->
        raw == <<1>>

      _ when type < 196 ->
        raw
        |> :binary.bin_to_list()
        |> Enum.chunk_every(static_type_size(type - 98))
        |> Enum.map(&decode_type(type - 98, :binary.list_to_bin(&1)))

      197 ->
        raw

      _ ->
        raise "Unknown type: #{type}"
    end
  end
end
