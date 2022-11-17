defmodule Explorer.Export.CSV do
  @moduledoc "Runs csv export operations from the database for a given account and parameters"

  alias Explorer.Chain.Address
  alias Explorer.Repo
  alias NimbleCSV.RFC4180
  alias Plug.Conn
  alias Explorer.Export.CSV.{EpochTransactionExporter, TokenTransferExporter, TransactionExporter}

  @transaction_timeout :timer.minutes(5) + :timer.seconds(10)
  @query_timeout :timer.minutes(5)
  # how long to wait for connection from pool
  @pool_timeout :timer.seconds(20)
  # how many records to stream from db before resolving associations
  @preload_chunks 500

  @doc "creates a stream with a given exporter module for the given address and date parameters"
  def stream(module, %Address{} = address, from, to) do
    query = Repo.stream(module.query(address, from, to), timeout: @query_timeout)
    headers = module.row_names()

    query
    |> Stream.chunk_every(@preload_chunks)
    |> Stream.flat_map(fn chunk ->
      # associations can't be directly preloaded in combination with Repo.stream
      # here we explicitly preload associations for every `@preload_chunks` records
      Repo.preload(chunk, module.associations())
    end)
    |> Stream.map(&module.transform(&1, address))
    |> then(&Stream.concat([headers], &1))
    |> RFC4180.dump_to_stream()
  end

  @doc """
  Creates and runs a streaming operation for given exporter module and parameters,
  will chunk output to a Plug.Conn instance for streaming
  """
  def export(module, address, from, to, %Conn{} = conn) do
    Repo.transaction(
      fn ->
        module
        |> stream(address, from, to)
        |> Enum.reduce(conn, fn v, c ->
          {:ok, conn} = Conn.chunk(c, v)
          conn
        end)
      end,
      timeout: @transaction_timeout,
      pool_timeout: @pool_timeout
    )
  end

  def export(module, address, from, to, destination) do
    Repo.transaction(
      fn ->
        module
        |> stream(address, from, to)
        |> Enum.into(destination)
      end,
      timeout: @transaction_timeout,
      pool_timeout: @pool_timeout
    )
  end

  # helper methods to export stuff directly

  def export_transactions(address, from, to, destination) do
    export(TransactionExporter, address, from, to, destination)
  end

  def export_token_transfers(address, from, to, destination) do
    export(TokenTransferExporter, address, from, to, destination)
  end

  def export_epoch_transactions(address, from, to, destination) do
    export(EpochTransactionExporter, address, from, to, destination)
  end
end
