defmodule Indexer.Prometheus.Setup do
  @moduledoc """
  Set up instrumenters and exporter here to keep application.ex clean
  """

  alias Indexer.Prometheus.{
    BlockInstrumenter,
    CeloInstrumenter,
    DBInstrumenter,
    Exporter,
    GenericInstrumenter,
    RPCInstrumenter,
    TokenInstrumenter,
    TransactionInstrumenter
  }

  def setup do
    BlockInstrumenter.setup()
    DBInstrumenter.setup()
    GenericInstrumenter.setup()
    RPCInstrumenter.setup()
    TokenInstrumenter.setup()
    TransactionInstrumenter.setup()
    CeloInstrumenter.setup()
    Exporter.setup()
  end
end
