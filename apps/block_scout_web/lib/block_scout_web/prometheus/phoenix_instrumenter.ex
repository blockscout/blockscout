defmodule BlockScoutWeb.Prometheus.PhoenixInstrumenter do
  @moduledoc """
  Phoenix request metrics for `Prometheus`.
  """

  @dialyzer {:no_match,
             [
               phoenix_channel_join: 3,
               phoenix_channel_receive: 3,
               phoenix_controller_call: 3,
               phoenix_controller_render: 3,
               setup: 0
             ]}

  use Prometheus.PhoenixInstrumenter
end
