defmodule BlockScoutWeb.ViewHelpers do
  @moduledoc """
  Helper functions for views
  """
  use BlockScoutWeb, :view

  def render_partial(args) when is_list(args) do
    render(
      Keyword.get(args, :view_module),
      Keyword.get(args, :partial),
      args
    )
  end

  def render_partial(text), do: text
end
