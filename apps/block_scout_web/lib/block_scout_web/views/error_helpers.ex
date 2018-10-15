defmodule BlockScoutWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  alias Ecto.Changeset
  alias Phoenix.HTML.Form
  alias Plug.Conn

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, opts \\ []) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error), Keyword.merge([class: "has-error"], opts))
    end)
  end

  @doc """
  Gets the errors for a form's input.
  """
  def errors_for_field(%Form{source: %Conn{}}, _), do: []

  def errors_for_field(%Form{source: %Changeset{action: nil}}, _), do: []

  def errors_for_field(%Form{source: %Changeset{action: :ignore}}, _), do: []

  def errors_for_field(%Form{source: %Changeset{errors: errors}}, field) do
    for error <- Keyword.get_values(errors, field) do
      translate_error(error)
    end
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # Because error messages were defined within Ecto, we must
    # call the Gettext module passing our Gettext backend. We
    # also use the "errors" domain as translations are placed
    # in the errors.po file.
    # Ecto will pass the :count keyword if the error message is
    # meant to be pluralized.
    # On your own code and templates, depending on whether you
    # need the message to be pluralized or not, this could be
    # written simply as:
    #
    #     dngettext "errors", "1 file", "%{count} files", count
    #     dgettext "errors", "is invalid"
    #
    if count = opts[:count] do
      Gettext.dngettext(BlockScoutWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(BlockScoutWeb.Gettext, "errors", msg, opts)
    end
  end
end
