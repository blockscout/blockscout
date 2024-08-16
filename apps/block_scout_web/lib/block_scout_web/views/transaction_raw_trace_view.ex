defmodule BlockScoutWeb.TransactionRawTraceView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  def render("scripts.html", %{conn: conn}) do
    render_scripts(conn, "raw-trace/code_highlighting.js")
  end

  def raw_traces_with_lines(raw_traces) do
    raw_traces
    |> Jason.encode!(pretty: true)
    |> String.split("\n")
    |> Enum.with_index(1)
  end
end
