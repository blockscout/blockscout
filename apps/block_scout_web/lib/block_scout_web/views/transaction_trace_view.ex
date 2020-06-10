defmodule BlockScoutWeb.TransactionTraceView do
  use BlockScoutWeb, :view
  @dialyzer :no_match

  alias Explorer.Chain.InternalTransaction

  def render("scripts.html", %{conn: conn}) do
    render_scripts(conn, "raw_trace/code_highlighting.js")
  end

  def raw_traces_with_lines(internal_transactions) do
    internal_transactions
    |> InternalTransaction.internal_transactions_to_raw()
    |> Jason.encode!(pretty: true)
    |> String.split("\n")
    |> Enum.with_index(1)
  end

  def raw_traces(internal_transactions) do
    internal_transactions
    |> InternalTransaction.internal_transactions_to_raw()
  end

  defp camelcase_key_to_normal_key(key) do
    key
    |> Macro.underscore()
    |> String.split("_")
    |> Enum.map(&String.capitalize(&1))
    |> Enum.join(" ")
  end
end
