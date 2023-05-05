defmodule BlockScoutWeb.Plug.Timing do
  @moduledoc """
   Safe version of https://github.com/scoutapp/elixir_plug_server_timing
  """

  @behaviour Plug
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send_headers(conn)
  end

  def register_before_send_headers(conn) do
    register_before_send(conn, fn conn ->
      conn
      |> put_resp_header("server-timing", "#{metrics_header()}")
    end)
  end

  defp metrics_header do
    payload = ScoutApm.DirectAnalysisStore.payload()

    if Map.get(payload, :total_call_time) do
      total_time =
        Map.get(payload, :total_call_time)
        |> Kernel.*(1000)

      inner_metrics =
        payload
        |> Map.get(:metrics)
        |> Enum.filter(fn metric ->
          get_in(metric, [:key, :name]) == "all"
        end)
        |> Enum.reduce("", fn metric, acc ->
          bucket = get_in(metric, [:key, :bucket])

          total_call_time =
            Map.get(metric, :total_exclusive_time)
            |> Kernel.*(1000)

          "#{acc}#{metric_to_header_value({bucket, nil, total_call_time})},"
        end)

      "#{inner_metrics}total;dur=#{total_time}"
    end
  end

  defp metric_to_header_value({name, nil, time}), do: ~s/#{name};dur=#{time}/
  defp metric_to_header_value({name, "", time}), do: ~s/#{name};dur=#{time}/

  defp metric_to_header_value({name, _description, time}) do
    # Skip showing description for now, as Chrome doesn't handle name and description, or long text well: https://github.com/ChromeDevTools/devtools-frontend/issues/64
    # ~s/#{name};desc="#{description}";dur=#{time}/
    ~s/#{name};dur=#{time}/
  end
end
