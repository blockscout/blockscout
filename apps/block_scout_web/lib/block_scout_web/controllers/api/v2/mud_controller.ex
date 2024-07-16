defmodule BlockScoutWeb.API.V2.MudController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 4,
      split_list_by_page: 1,
      default_paging_options: 0
    ]

  import BlockScoutWeb.PagingHelper, only: [mud_records_sorting: 1]

  alias Explorer.Chain.{Data, Hash, Mud, Mud.Schema.FieldSchema, Mud.Table}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET requests to `/api/v2/mud/worlds` endpoint.
  """
  @spec worlds(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worlds(conn, params) do
    {worlds, next_page} =
      params
      |> mud_paging_options(["world"], [Hash.Address])
      |> Mud.worlds_list()
      |> split_list_by_page()

    next_page_params =
      next_page_params(next_page, worlds, conn.query_params, fn item ->
        %{"world" => item}
      end)

    conn
    |> put_status(200)
    |> render(:worlds, %{worlds: worlds, next_page_params: next_page_params})
  end

  @doc """
    Function to handle GET requests to `/api/v2/mud/worlds/count` endpoint.
  """
  @spec worlds_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worlds_count(conn, _params) do
    count = Mud.worlds_count()

    conn
    |> put_status(200)
    |> render(:count, %{count: count})
  end

  @doc """
    Function to handle GET requests to `/api/v2/mud/worlds/:world/tables` endpoint.
  """
  @spec world_tables(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def world_tables(conn, %{"world" => world_param} = params) do
    with {:format, {:ok, world}} <- {:format, Hash.Address.cast(world_param)} do
      options = params |> mud_paging_options(["table_id"], [Hash.Full]) |> Keyword.merge(mud_tables_filter(params))

      {tables, next_page} =
        world
        |> Mud.world_tables(options)
        |> split_list_by_page()

      next_page_params =
        next_page_params(next_page, tables, conn.query_params, fn item ->
          %{"table_id" => item |> elem(0)}
        end)

      conn
      |> put_status(200)
      |> render(:tables, %{tables: tables, next_page_params: next_page_params})
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/mud/worlds/:world/tables/count` endpoint.
  """
  @spec world_tables_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def world_tables_count(conn, %{"world" => world_param} = params) do
    with {:format, {:ok, world}} <- {:format, Hash.Address.cast(world_param)} do
      options = params |> mud_tables_filter()

      count = Mud.world_tables_count(world, options)

      conn
      |> put_status(200)
      |> render(:count, %{count: count})
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/mud/worlds/:world/tables/:table_id/records` endpoint.
  """
  @spec world_table_records(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def world_table_records(conn, %{"world" => world_param, "table_id" => table_id_param} = params) do
    with {:format, {:ok, world}} <- {:format, Hash.Address.cast(world_param)},
         {:format, {:ok, table_id}} <- {:format, Hash.Full.cast(table_id_param)},
         {:ok, schema} <- Mud.world_table_schema(world, table_id) do
      options =
        params
        |> mud_paging_options(["key_bytes", "key0", "key1"], [Data, Hash.Full, Hash.Full])
        |> Keyword.merge(mud_records_filter(params, schema))
        |> Keyword.merge(mud_records_sorting(params))

      {records, next_page} = world |> Mud.world_table_records(table_id, options) |> split_list_by_page()

      blocks = Mud.preload_records_timestamps(records)

      next_page_params =
        next_page_params(next_page, records, conn.query_params, fn item ->
          keys = [item.key_bytes, item.key0, item.key1] |> Enum.filter(&(!is_nil(&1)))
          ["key_bytes", "key0", "key1"] |> Enum.zip(keys) |> Enum.into(%{})
        end)

      conn
      |> put_status(200)
      |> render(:records, %{
        records: records,
        table_id: table_id,
        schema: schema,
        blocks: blocks,
        next_page_params: next_page_params
      })
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/mud/worlds/:world/tables/:table_id/records/count` endpoint.
  """
  @spec world_table_records_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def world_table_records_count(conn, %{"world" => world_param, "table_id" => table_id_param} = params) do
    with {:format, {:ok, world}} <- {:format, Hash.Address.cast(world_param)},
         {:format, {:ok, table_id}} <- {:format, Hash.Full.cast(table_id_param)},
         {:ok, schema} <- Mud.world_table_schema(world, table_id) do
      options = params |> mud_records_filter(schema)

      count = Mud.world_table_records_count(world, table_id, options)

      conn
      |> put_status(200)
      |> render(:count, %{count: count})
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/mud/worlds/:world/tables/:table_id/records/:record_id` endpoint.
  """
  @spec world_table_record(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def world_table_record(
        conn,
        %{"world" => world_param, "table_id" => table_id_param, "record_id" => record_id_param} = _params
      ) do
    with {:format, {:ok, world}} <- {:format, Hash.Address.cast(world_param)},
         {:format, {:ok, table_id}} <- {:format, Hash.Full.cast(table_id_param)},
         {:format, {:ok, record_id}} <- {:format, Data.cast(record_id_param)},
         {:ok, schema} <- Mud.world_table_schema(world, table_id),
         {:ok, record} <- Mud.world_table_record(world, table_id, record_id) do
      blocks = Mud.preload_records_timestamps([record])

      conn
      |> put_status(200)
      |> render(:record, %{record: record, table_id: table_id, schema: schema, blocks: blocks})
    end
  end

  defp mud_tables_filter(params) do
    Enum.reduce(params, [], fn {key, value}, acc ->
      case key do
        "filter_namespace" ->
          Keyword.put(acc, :filter_namespace, parse_namespace_string(value))

        "q" ->
          Keyword.put(acc, :filter_search, parse_search_string(value))

        _ ->
          acc
      end
    end)
  end

  defp parse_namespace_string(namespace) do
    filter =
      case namespace do
        nil -> {:ok, nil}
        "0x" <> hex -> Base.decode16(hex, case: :mixed)
        str -> {:ok, str}
      end

    case filter do
      {:ok, ns} when is_binary(ns) and byte_size(ns) <= 14 ->
        ns |> String.pad_trailing(14, <<0>>)

      _ ->
        nil
    end
  end

  defp parse_search_string(q) do
    # If the search string looks like hex-encoded table id or table full name,
    # we try to parse and filter by that table id directly.
    # Otherwise we do a full-text search of given string inside table id.
    with :error <- Hash.Full.cast(q),
         :error <- Table.table_full_name_to_table_id(q) do
      q
    else
      {:ok, table_id} -> table_id
    end
  end

  defp mud_records_filter(params, schema) do
    Enum.reduce(params, [], fn {key, value}, acc ->
      case key do
        "filter_key0" -> Keyword.put(acc, :filter_key0, encode_filter(value, schema, 0))
        "filter_key1" -> Keyword.put(acc, :filter_key1, encode_filter(value, schema, 1))
        _ -> acc
      end
    end)
  end

  defp encode_filter(value, schema, field_idx) do
    case value do
      "false" ->
        <<0::256>>

      "true" ->
        <<1::256>>

      "0x" <> hex ->
        bin = Base.decode16!(hex, case: :mixed)
        # addresses are padded to 32 bytes with zeros on the right
        if FieldSchema.type_of(schema.key_schema, field_idx) == 97 do
          <<0::size(256 - byte_size(bin) * 8), bin::binary>>
        else
          <<bin::binary, 0::size(256 - byte_size(bin) * 8)>>
        end

      dec ->
        num = dec |> Integer.parse() |> elem(0)
        <<num::256>>
    end
  end

  defp mud_paging_options(params, keys, types) do
    page_key =
      keys
      |> Enum.zip(types)
      |> Enum.reduce(%{}, fn {key, type}, acc ->
        with param when param != nil <- Map.get(params, key),
             {:ok, val} <- type.cast(param) do
          acc |> Map.put(String.to_existing_atom(key), val)
        else
          _ -> acc
        end
      end)

    if page_key == %{} do
      [paging_options: default_paging_options()]
    else
      [paging_options: %{default_paging_options() | key: page_key}]
    end
  end
end
