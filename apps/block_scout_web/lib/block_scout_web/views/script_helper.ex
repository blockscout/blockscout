defmodule BlockScoutWeb.Views.ScriptHelper do
  @moduledoc """
  Helper for rendering view specific script tags.
  """

  import Phoenix.LiveView.Helpers, only: [sigil_H: 2]
  import BlockScoutWeb.Router.Helpers, only: [static_path: 2]

  alias Phoenix.HTML.Safe

  def render_scripts(conn, file_names) do
    conn
    |> files(file_names)
    |> Enum.map(fn file ->
      assigns = %{file: file}

      ~H"""
        <script src="{@file}"> </script>
      """
      |> Safe.to_iodata()
      |> List.to_string()
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
