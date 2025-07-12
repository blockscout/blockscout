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
      limit: 2,
      join: 5
    ]

  alias ABI.{FunctionSelector, TypeDecoder}
  alias Explorer.{Chain, PagingOptions, Repo, SortingHelper}

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    Hash,
    MethodIdentifier,
    Mud,
    Mud.Schema,
    Mud.Schema.FieldSchema,
    SmartContract
  }

  require Logger

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

  @world_system_registry_table_id Base.decode16!("7462776f726c6400000000000000000053797374656d52656769737472790000",
                                    case: :lower
                                  )

  # https://github.com/latticexyz/mud/blob/5a6c03c6bc02c980ca051dadd8e20560ac25c771/packages/world/src/codegen/tables/SystemRegistry.sol#L24-L32
  @world_system_registry_schema %Schema{
    key_schema: FieldSchema.from("0x0014010061000000000000000000000000000000000000000000000000000000"),
    value_schema: FieldSchema.from("0x002001005f000000000000000000000000000000000000000000000000000000"),
    key_names: ["system"],
    value_names: ["systemId"]
  }

  @world_function_selector_table_id Base.decode16!("7462776f726c6400000000000000000046756e6374696f6e53656c6563746f72",
                                      case: :lower
                                    )

  # https://github.com/latticexyz/mud/blob/5a6c03c6bc02c980ca051dadd8e20560ac25c771/packages/world/src/codegen/tables/FunctionSelectors.sol#L24-L32
  @world_function_selector_schema %Schema{
    key_schema: FieldSchema.from("0x0004010043000000000000000000000000000000000000000000000000000000"),
    value_schema: FieldSchema.from("0x002402005f430000000000000000000000000000000000000000000000000000"),
    key_names: ["worldFunctionSelector"],
    value_names: ["systemId", "systemFunctionSelector"]
  }

  @world_function_signature_table_id Base.decode16!("6f74776f726c6400000000000000000046756e6374696f6e5369676e61747572",
                                       case: :lower
                                     )

  # https://github.com/latticexyz/mud/blob/5a6c03c6bc02c980ca051dadd8e20560ac25c771/packages/world/src/codegen/tables/FunctionSignatures.sol#L21-L29
  @world_function_signature_schema %Schema{
    key_schema: FieldSchema.from("0x0004010043000000000000000000000000000000000000000000000000000000"),
    value_schema: FieldSchema.from("0x00000001c5000000000000000000000000000000000000000000000000000000"),
    key_names: ["functionSelector"],
    value_names: ["functionSignature"]
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
  Returns the list of first 1000 MUD systems registered for the given world.
  """
  @spec world_systems(Hash.Address.t()) :: [{Hash.Full.t(), Hash.Address.t()}]
  def world_systems(world) do
    Mud
    |> where([r], r.address == ^world and r.table_id == ^@world_system_registry_table_id and r.is_deleted == false)
    |> limit(1000)
    |> Repo.Mud.all()
    |> Enum.map(&decode_record(&1, @world_system_registry_schema))
    |> Enum.map(fn s ->
      with {:ok, system_id} <- Hash.Full.cast(s["systemId"]),
           {:ok, system} <- Hash.Address.cast(s["system"]) do
        {system_id, system}
      end
    end)
    |> Enum.reject(&(&1 == :error))
  end

  @doc """
  Returns reconstructed ABI of the MUD system in the given world.
  """
  @spec world_system(Hash.Address.t(), Hash.Address.t(), Keyword.t()) ::
          {:ok, Hash.Full.t(), [FunctionSelector.t()]} | {:error, :not_found}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def world_system(world, system, options \\ []) do
    # pad to 32 bytes
    padded_system_address_hash = %Data{bytes: <<0::size(96)>> <> system.bytes}

    # If we were to access MUD tables in SQL, it would look like:
    # SELECT sr.*, fsl.*, fsg.*
    # FROM tb.world.SystemRegistry sr
    # JOIN tb.world.FunctionSelector fsl ON fsl.systemId = sr.systemId
    # JOIN tb.world.FunctionSignature fsg ON fsg.functionSelector = fsl.worldFunctionSelector
    # WHERE sr.system = $1
    {system_records, function_selector_signature_records} =
      Mud
      |> where(
        [r],
        r.address == ^world and r.table_id == ^@world_system_registry_table_id and r.is_deleted == false and
          r.key_bytes == ^padded_system_address_hash
      )
      |> join(
        :left,
        [r],
        r2 in Mud,
        on:
          r2.address == ^world and r2.table_id == ^@world_function_selector_table_id and r2.is_deleted == false and
            fragment("substring(? FOR 32)", r2.static_data) == r.static_data
      )
      |> join(
        :left,
        [r, r2],
        r3 in Mud,
        on:
          r3.address == ^world and r3.table_id == ^@world_function_signature_table_id and r3.is_deleted == false and
            r3.key_bytes == r2.key_bytes
      )
      |> select([r, r2, r3], {r, {r2, r3}})
      |> limit(1000)
      |> Repo.Mud.all()
      |> Enum.unzip()

    with false <- Enum.empty?(system_records),
         system_record = Enum.at(system_records, 0),
         {:ok, system_id} <- Hash.Full.cast(system_record.static_data.bytes) do
      {:ok, system_id, reconstruct_system_abi(system, function_selector_signature_records, options)}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec reconstruct_system_abi(Hash.Address.t(), [{Mud.t(), Mud.t()}], Keyword.t()) :: [FunctionSelector.t()]
  defp reconstruct_system_abi(system, function_selector_signature_records, options) do
    system_contract = SmartContract.address_hash_to_smart_contract(system, options)

    # fetch verified contract ABI, if any
    verified_system_abi =
      ((system_contract && system_contract.abi) || [])
      |> ABI.parse_specification()
      |> Enum.filter(&(&1.type == :function))
      |> Enum.into(%{}, fn selector ->
        {:ok, method_id} = MethodIdentifier.cast(selector.method_id)
        {to_string(method_id), selector}
      end)

    function_selector_signature_records
    |> Enum.reject(&(&1 == {nil, nil}))
    |> Enum.map(fn {function_selector_record, function_signature_record} ->
      function_selector = function_selector_record |> decode_record(@world_function_selector_schema)

      # if the external world function selector is present in the verified ABI, we use it
      world_function_selector =
        verified_system_abi |> Map.get(function_selector |> Map.get("worldFunctionSelector"))

      if world_function_selector do
        world_function_selector
      else
        abi_method = parse_function_signature(function_signature_record)

        # if the internal system function selector is present in the verified ABI,
        # then it has the same arguments as the external world function, but a different name,
        # so we use it after replacing the function name accordingly.
        # in case neither of the selectors were found in the verified ABI, we use the ABI crafted from the method signature
        verified_system_abi
        |> Map.get(function_selector |> Map.get("systemFunctionSelector"), abi_method)
        |> Map.put(:function, abi_method.function)
      end
    end)
  end

  @spec parse_function_signature(Mud.t()) :: FunctionSelector.t()
  defp parse_function_signature(function_signature_record) do
    raw_abi_method =
      function_signature_record
      |> decode_record(@world_function_signature_schema)
      |> Map.get("functionSignature")
      |> FunctionSelector.decode()

    raw_abi_method
    |> Map.put(:type, :function)
    |> Map.put(:state_mutability, :payable)
    |> Map.put(:input_names, 0..(Enum.count(raw_abi_method.types) - 1) |> Enum.map(&"arg#{&1}"))
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
        %Data{bytes: raw} |> to_string()

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

defimpl Jason.Encoder, for: ABI.FunctionSelector do
  alias Jason.Encode

  def encode(data, opts) do
    function_inputs = encode_arguments(data.types, data.input_names)

    inputs =
      if data.inputs_indexed do
        function_inputs
        |> Enum.zip(data.inputs_indexed)
        |> Enum.map(fn {r, indexed} -> Map.put(r, "indexed", indexed) end)
      else
        function_inputs
      end

    Encode.map(
      %{
        "type" => data.type,
        "name" => data.function,
        "inputs" => inputs,
        "outputs" => encode_arguments(data.returns, data.return_names),
        "stateMutability" => encode_state_mutability(data.state_mutability)
      },
      opts
    )
  end

  defp encode_arguments(types, names) do
    types
    |> Enum.zip(names)
    |> Enum.map(fn {type, name} ->
      %{
        "type" => encode_type(type),
        "name" => name,
        "components" => encode_components(type)
      }
      |> Map.reject(fn {key, value} -> {key, value} == {"components", nil} end)
    end)
  end

  defp encode_type(:bool), do: "bool"
  defp encode_type(:string), do: "string"
  defp encode_type(:bytes), do: "bytes"
  defp encode_type(:address), do: "address"
  defp encode_type(:function), do: "function"
  defp encode_type({:int, size}), do: "int#{size}"
  defp encode_type({:uint, size}), do: "uint#{size}"
  defp encode_type({:fixed, element_count, precision}), do: "fixed#{element_count}x#{precision}"
  defp encode_type({:ufixed, element_count, precision}), do: "ufixed#{element_count}x#{precision}"
  defp encode_type({:bytes, size}), do: "bytes#{size}"
  defp encode_type({:array, type}), do: "#{encode_type(type)}[]"
  defp encode_type({:array, type, element_count}), do: "#{encode_type(type)}[#{element_count}]"
  defp encode_type({:tuple, _types}), do: "tuple"

  defp encode_components({:array, type}), do: encode_components(type)
  defp encode_components({:array, type, _element_count}), do: encode_components(type)

  defp encode_components({:tuple, types}),
    do:
      types
      |> Enum.with_index()
      |> Enum.map(fn {type, index} ->
        %{
          "type" => encode_type(type),
          "name" => "arg#{index}"
        }
      end)

  defp encode_components(_), do: nil

  defp encode_state_mutability(:pure), do: "pure"
  defp encode_state_mutability(:view), do: "view"
  defp encode_state_mutability(:non_payable), do: "nonpayable"
  defp encode_state_mutability(:payable), do: "payable"
  defp encode_state_mutability(_), do: nil
end
