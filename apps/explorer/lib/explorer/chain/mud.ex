defmodule Explorer.Chain.Mud do
  @moduledoc """
    Represents a MUD framework database record.
  """
  use Explorer.Schema

  import Ecto.Query,
    only: [
      distinct: 2,
      order_by: 3,
      select: 3,
      where: 3,
      limit: 2
    ]

  alias ABI.TypeDecoder
  alias Explorer.{Chain, PagingOptions, Repo, SortingHelper}

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    Hash,
    Mud,
    Mud.Schema,
    Mud.Schema.FieldSchema
  }

  require Logger

  @schema_prefix "mud"

  @store_tables_table_id Base.decode16!("746273746f72650000000000000000005461626c657300000000000000000000",
                           case: :lower
                         )

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

  @doc """
  Returns the paginated list of registered MUD world addresses.
  """
  @spec worlds_list(Keyword.t()) :: [Mud.t()]
  def worlds_list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    Mud
    |> distinct(true)
    |> select([r], r.address)
    |> where([r], r.table_id == ^@store_tables_table_id)
    |> page_worlds(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.Mud.all()
  end

  defp page_worlds(query, %PagingOptions{key: %{world: world}}) do
    query |> where([item], item.address > ^world)
  end

  defp page_worlds(query, _), do: query

  @doc """
  Returns the total number of registered MUD worlds.
  """
  @spec worlds_count() :: non_neg_integer()
  def worlds_count do
    Mud
    |> select([r], r.address)
    |> distinct(true)
    |> Repo.Mud.aggregate(:count)
  end

  @doc """
  Returns the decoded MUD table schema by world address and table ID.
  """
  @spec world_table_schema(Hash.Address.t(), Hash.Full.t()) :: {:ok, Schema.t()} | {:error, :not_found}
  def world_table_schema(world, table_id) do
    Mud
    |> where([r], r.address == ^world and r.table_id == ^@store_tables_table_id and r.key0 == ^table_id)
    |> Repo.Mud.one()
    |> case do
      nil ->
        {:error, :not_found}

      r ->
        {:ok, decode_schema(r)}
    end
  end

  @doc """
  Returns the paginated list of registered MUD tables in the given world, optionally filtered by namespace or table name.
  Each returned table in the resulting list is represented as a tuple of its ID and decoded schema.
  """
  @spec world_tables(Hash.Address.t(), Keyword.t()) :: [{Hash.Full.t(), Schema.t()}]
  def world_tables(world, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    filter_namespace = Keyword.get(options, :filter_namespace, nil)
    filter_search = Keyword.get(options, :filter_search, nil)

    Mud
    |> where([r], r.address == ^world and r.table_id == ^@store_tables_table_id)
    |> filter_tables_by_namespace(filter_namespace)
    |> filter_tables_by_search(filter_search)
    |> page_tables(paging_options)
    |> order_by([r], asc: r.key0)
    |> limit(^paging_options.page_size)
    |> Repo.Mud.all()
    |> Enum.map(&{&1.key0, decode_schema(&1)})
  end

  defp page_tables(query, %PagingOptions{key: %{table_id: table_id}}) do
    query |> where([item], item.key0 > ^table_id)
  end

  defp page_tables(query, _), do: query

  @doc """
  Returns the number of registered MUD tables in the given world.
  """
  @spec world_tables_count(Hash.Address.t(), Keyword.t()) :: non_neg_integer()
  def world_tables_count(world, options \\ []) do
    filter_namespace = Keyword.get(options, :filter_namespace, nil)
    filter_search = Keyword.get(options, :filter_search, nil)

    Mud
    |> where([r], r.address == ^world and r.table_id == ^@store_tables_table_id)
    |> filter_tables_by_namespace(filter_namespace)
    |> filter_tables_by_search(filter_search)
    |> Repo.Mud.aggregate(:count)
  end

  defp filter_tables_by_namespace(query, nil), do: query

  defp filter_tables_by_namespace(query, :error), do: query |> where([tb], false)

  defp filter_tables_by_namespace(query, namespace) do
    query |> where([tb], fragment("substring(? FROM 3 FOR 14)", tb.key0) == ^namespace)
  end

  defp filter_tables_by_search(query, %Hash{} = table_id) do
    query |> where([tb], tb.key0 == ^table_id)
  end

  defp filter_tables_by_search(query, search_string) when is_binary(search_string) do
    query |> where([tb], ilike(fragment("encode(?, 'escape')", tb.key0), ^"%#{search_string}%"))
  end

  defp filter_tables_by_search(query, _), do: query

  @default_sorting [
    asc: :key_bytes
  ]

  @doc """
  Returns the paginated list of raw MUD records in the given world table.
  Resulting records can be sorted or filtered by any of the first 2 key columns.
  """
  @spec world_table_records(Hash.Address.t(), Hash.Full.t(), Keyword.t()) :: [Mud.t()]
  def world_table_records(world, table_id, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    sorting = Keyword.get(options, :sorting, [])

    Mud
    |> where([r], r.address == ^world and r.table_id == ^table_id and r.is_deleted == false)
    |> filter_records(:key0, Keyword.get(options, :filter_key0))
    |> filter_records(:key1, Keyword.get(options, :filter_key1))
    |> SortingHelper.apply_sorting(sorting, @default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)
    |> Repo.Mud.all()
  end

  @doc """
  Preloads last modification timestamps for the list of raw MUD records.

  Returns a map of block numbers to timestamps.
  """
  @spec preload_records_timestamps([Mud.t()]) :: %{non_neg_integer() => DateTime.t()}
  def preload_records_timestamps(records) do
    block_numbers = records |> Enum.map(&(&1.block_number |> Decimal.to_integer())) |> Enum.uniq()

    Block
    |> where([b], b.number in ^block_numbers)
    |> select([b], {b.number, b.timestamp})
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Returns the number of MUD records in the given world table.
  """
  @spec world_table_records_count(Hash.Address.t(), Hash.Full.t(), Keyword.t()) :: non_neg_integer()
  def world_table_records_count(world, table_id, options \\ []) do
    Mud
    |> where([r], r.address == ^world and r.table_id == ^table_id and r.is_deleted == false)
    |> filter_records(:key0, Keyword.get(options, :filter_key0))
    |> filter_records(:key1, Keyword.get(options, :filter_key1))
    |> Repo.Mud.aggregate(:count)
  end

  defp filter_records(query, _key_name, nil), do: query

  defp filter_records(query, _key_name, :error), do: query |> where([r], false)

  defp filter_records(query, :key0, key), do: query |> where([r], r.key0 == ^key)

  defp filter_records(query, :key1, key), do: query |> where([r], r.key1 == ^key)

  @doc """
  Returns the raw MUD record from the given world table by its ID.
  """
  @spec world_table_record(Hash.Address.t(), Hash.Full.t(), Data.t()) :: {:ok, Mud.t()} | {:error, :not_found}
  def world_table_record(world, table_id, record_id) do
    Mud
    |> where([r], r.address == ^world and r.table_id == ^table_id and r.key_bytes == ^record_id)
    |> Repo.Mud.one()
    |> case do
      nil ->
        {:error, :not_found}

      r ->
        {:ok, r}
    end
  end

  defp decode_schema(nil), do: nil

  defp decode_schema(record) do
    schema_record = decode_record(record, @store_tables_table_schema)

    %Schema{
      key_schema: schema_record["keySchema"] |> FieldSchema.from(),
      value_schema: schema_record["valueSchema"] |> FieldSchema.from(),
      key_names: schema_record["abiEncodedKeyNames"] |> decode_abi_encoded_strings(),
      value_names: schema_record["abiEncodedValueNames"] |> decode_abi_encoded_strings()
    }
  end

  defp decode_abi_encoded_strings("0x" <> hex_encoded) do
    hex_encoded
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw([{:array, :string}])
    |> Enum.at(0)
  end

  @doc """
  Decodes a given raw MUD record according to table schema.

  Returns a JSON-like map with decoded field names and values.
  """
  @spec decode_record(Mud.t() | nil, Schema.t() | nil) :: map() | nil
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

  defp decode_key_tuple(key_bytes, fields, layout_schema) do
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

  defp decode_fields(static_data, encoded_lengths, dynamic_data, fields, layout_schema) do
    {static_fields_count, types} = Schema.decode_types(layout_schema)

    {static_types, dynamic_types} = Enum.split(types, static_fields_count)

    {static_fields, dynamic_fields} = Enum.split(fields, static_fields_count)

    res =
      static_fields
      |> Enum.zip(static_types)
      |> Enum.reduce({%{}, (static_data && static_data.bytes) || <<>>}, fn {field, type}, {acc, data} ->
        type_size = static_type_size(type)
        {enc, rest} = split_binary(data, type_size)

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
        {enc, rest} = split_binary(data, length)
        decoded = decode_type(type, enc)

        {Map.put(acc, field, decoded), rest}
      end)
      |> elem(0)
    end
  end

  defp static_type_size(type) do
    case type do
      _ when type < 97 -> rem(type, 32) + 1
      97 -> 20
      _ -> 0
    end
  end

  defp split_binary(binary, size) do
    if byte_size(binary) >= size,
      do: :erlang.split_binary(binary, size),
      else: {<<0::size(size * 8)>>, <<>>}
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp decode_type(type, raw) do
    case type do
      _ when type < 32 ->
        raw |> :binary.decode_unsigned() |> Integer.to_string()

      _ when type < 64 ->
        size = static_type_size(type)
        <<int::signed-integer-size(size * 8)>> = raw
        int |> Integer.to_string()

      _ when type < 96 or type == 196 ->
        "0x" <> Base.encode16(raw, case: :lower)

      96 ->
        raw == <<1>>

      97 ->
        Address.checksum(raw)

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
