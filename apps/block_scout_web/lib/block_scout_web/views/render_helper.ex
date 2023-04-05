defmodule BlockScoutWeb.RenderHelper do
  @moduledoc """
  Helper functions to render partials from view modules
  """
  use BlockScoutWeb, :view

  @doc """
  Renders html using:
  * A list of args including `:view_module` and `:partial` to render a partial with the required keyword list.
  * Text that will pass directly through to the template
  """
  def render_partial(args) when is_list(args) do
    render(
      Keyword.get(args, :view_module),
      Keyword.get(args, :partial),
      args
    )
  end

  def render_partial(text), do: text
end
