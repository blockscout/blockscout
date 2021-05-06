defmodule BlockScoutWeb.ABIEncodedValueView do
  @moduledoc """
  Renders a decoded value that is encoded according to an ABI.

  Does not leverage an eex template because it renders formatted
  values via `<pre>` tags, and that is hard to do in an eex template.
  """
  use BlockScoutWeb, :view

  alias ABI.FunctionSelector
  alias Phoenix.HTML

  require Logger

  def value_html(type, value) do
    decoded_type = FunctionSelector.decode_type(type)

    do_value_html(decoded_type, value)
  rescue
    exception ->
      Logger.warn(fn ->
        ["Error determining value html for #{inspect(type)}: ", Exception.format(:error, exception)]
      end)

      :error
  end

  def copy_text(type, value) do
    decoded_type = FunctionSelector.decode_type(type)

    do_copy_text(decoded_type, value)
  rescue
    exception ->
      Logger.warn(fn ->
        ["Error determining copy text for #{inspect(type)}: ", Exception.format(:error, exception)]
      end)

      :error
  end

  defp do_copy_text({:bytes, _type}, value) do
    hex(value)
  end

  defp do_copy_text({:array, type, _}, value) do
    do_copy_text({:array, type}, value)
  end

  defp do_copy_text({:array, type}, value) do
    values =
      value
      |> Enum.map(&do_copy_text(type, &1))
      |> Enum.intersperse(", ")

    ~E|[<%= values %>]|
  end

  defp do_copy_text(_, {:dynamic, value}) do
    hex(value)
  end

  defp do_copy_text(type, value) when type in [:bytes, :address] do
    hex(value)
  end

  defp do_copy_text(_type, value) do
    to_string(value)
  end

  defp do_value_html(type, value, depth \\ 0)

  defp do_value_html({:bytes, _}, value, depth) do
    do_value_html(:bytes, value, depth)
  end

  defp do_value_html({:array, type, _}, value, depth) do
    do_value_html({:array, type}, value, depth)
  end

  defp do_value_html({:array, type}, value, depth) do
    values =
      Enum.map(value, fn inner_value ->
        do_value_html(type, inner_value, depth + 1)
      end)

    spacing = String.duplicate(" ", depth * 2)
    delimited = Enum.intersperse(values, ",\n")

    ~E|<%= spacing %>[<%= "\n" %><%= delimited %><%= "\n" %><%= spacing %>]|
  end

  defp do_value_html({:tuple, types}, values, _) do
    values_list =
      values
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.map(fn {value, i} ->
        type = Enum.at(types, i)

        case type do
          {:tuple, types} ->
            do_value_html_from_tuple(types, value)

          _ ->
            res = do_value_html(type, value)
            [_, {:safe, html_val}] = res
            html_val
        end
      end)

    "(" <> Enum.join(values_list, ",") <> ")"
  end

  defp do_value_html(type, value, depth) do
    spacing = String.duplicate(" ", depth * 2)
    ~E|<%= spacing %><%=base_value_html(type, value)%>|
    [spacing, base_value_html(type, value)]
  end

  defp do_value_html_from_tuple(types, values) do
    values_list =
      values
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.map(fn {value, i} ->
        type = Enum.at(types, i)

        case type do
          :address ->
            [_, {:safe, html_val}] = do_value_html(:address_text, value)
            html_val

          _ ->
            [_, {:safe, html_val}] = do_value_html(type, value)
            html_val
        end
      end)

    Enum.join(values_list, ",")
  end

  defp base_value_html(_, {:dynamic, value}) do
    ~E|<%= hex(value) %>|
  end

  defp base_value_html(:address, value) do
    address = hex(value)

    ~E|<a href="<%= address_path(BlockScoutWeb.Endpoint, :show, address) %>" target="_blank"><%= address %></a>|
  end

  defp base_value_html(:address_text, value) do
    ~E|<%= hex(value) %>|
  end

  defp base_value_html(:bytes, value) do
    ~E|<%= hex(value) %>|
  end

  defp base_value_html(_, value), do: HTML.html_escape(value)

  defp hex(value), do: "0x" <> Base.encode16(value, case: :lower)
end
