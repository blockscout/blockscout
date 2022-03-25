defmodule BlockScoutWeb.ChangesetView do
  use BlockScoutWeb, :view

  def render("error.json", %{changeset: changeset}) do
    errors =
      Enum.map(changeset.errors, fn {field, error} ->
        %{
          field: field,
          message: render_error(error)
        }
      end)

    %{errors: errors}
  end

  def render_error({message, values}) do
    Enum.reduce(values, message, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", to_string(v))
    end)
  end

  def render_error(message) do
    message
  end
end
