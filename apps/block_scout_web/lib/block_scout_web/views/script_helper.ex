defmodule BlockScoutWeb.Views.ScriptHelper do
  @moduledoc """
  Helper for rendering view specific script tags.
  """

  import Phoenix.HTML, only: [sigil_E: 2]
  import BlockScoutWeb.Router.Helpers, only: [static_path: 2]

  def render_scripts(conn, file_names) do
    conn
    |> files(file_names)
    |> Enum.map(fn file ->
      ~E"""
        <script src="<%= file %>"> </script>
      """
    end)
  end

  defp files(conn, file_names) do
    file_names
    |> List.wrap()
    |> Enum.map(fn file ->
      path = "/" <> Path.join("js", file)

      static_path(conn, path)
    end)
  end
end
