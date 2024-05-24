defmodule BlockScoutWeb.API.V2.MudView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Mud, Mud.Table}

  @doc """
    Function to render GET requests to `/api/v2/mud/worlds` endpoint.
  """
  @spec render(String.t(), map()) :: map()
  def render("worlds.json", %{worlds: worlds, next_page_params: next_page_params}) do
    %{
      items: worlds,
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/mud/worlds/count` endpoint.
  """
  def render("count.json", %{count: count}) do
    %{
      count: count
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/mud/worlds/:world/tables` endpoint.
  """
  def render("tables.json", %{tables: tables, next_page_params: next_page_params}) do
    %{
      items: tables |> Enum.map(&%{table: Table.from(&1 |> elem(0)), schema: &1 |> elem(1)}),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/mud/worlds/:world/tables/:table_id/records` endpoint.
  """
  def render("records.json", %{
        records: records,
        table_id: table_id,
        schema: schema,
        blocks: blocks,
        next_page_params: next_page_params
      }) do
    %{
      items: records |> Enum.map(&format_record(&1, schema, blocks)),
      table: table_id |> Table.from(),
      schema: schema,
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/mud/worlds/:world/tables/:table_id/records/:record_id` endpoint.
  """
  def render("record.json", %{record: record, table_id: table_id, blocks: blocks, schema: schema}) do
    %{
      record: record |> format_record(schema, blocks),
      table: table_id |> Table.from(),
      schema: schema
    }
  end

  defp format_record(nil, _schema, _blocks), do: nil

  defp format_record(record, schema, blocks) do
    %{
      id: record.key_bytes,
      raw: %{
        key_bytes: record.key_bytes,
        key0: record.key0,
        key1: record.key1,
        static_data: record.static_data,
        encoded_lengths: record.encoded_lengths,
        dynamic_data: record.dynamic_data,
        block_number: record.block_number,
        log_index: record.log_index
      },
      is_deleted: record.is_deleted,
      decoded: Mud.decode_record(record, schema),
      timestamp: blocks |> Map.get(Decimal.to_integer(record.block_number), nil)
    }
  end
end
