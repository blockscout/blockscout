defmodule BlockScoutWeb.FormView do
  use BlockScoutWeb, :view

  alias Phoenix.HTML.Form

  @type text_input_type :: :email | :hidden | :password | :text
  @type text_field_option ::
          {:default_value, String.t()}
          | {:id, String.t()}
          | {:label, String.t()}
          | {:placeholder, String.t()}
          | {:required, boolean()}
  defguard is_text_input(type) when type in ~w(email hidden password text)a

  @doc """
  Renders a text input field with certain properties.

  ## Supported Options

  * `:label` - Label for the input field

  ## Options as HTML 5 Attributes

  The following options will be applied as HTML 5 attributes on the
  `<input>` element:

  * `:default_value` - Default value to attach to the input field
  * `:id` - ID to attach to the input field
  * `:placeholder` - Placeholder text for the input field
  * `:required` - Mark the input field as required
  * `:type` - Input field type
  """
  @spec text_field(Form.t(), atom(), text_input_type(), [text_field_option()]) :: Phoenix.HTML.safe()
  def text_field(%Form{} = form, form_key, input_type, opts \\ [])
      when is_text_input(input_type) and is_atom(form_key) do
    errors = errors_for_field(form, form_key)
    label = Keyword.get(opts, :label)
    id = Keyword.get(opts, :id)

    supported_input_field_attrs = ~w(default_value id placeholder required)a
    base_input_field_opts = Keyword.take(opts, supported_input_field_attrs)

    input_field_class =
      case errors do
        [_ | _] -> "form-control is-invalid"
        _ -> "form-control"
      end

    input_field_opts = Keyword.put(base_input_field_opts, :class, input_field_class)
    input_field = input_for_type(input_type).(form, form_key, input_field_opts)

    render_opts = [
      errors: errors,
      id: id,
      input_field: input_field,
      label: label
    ]

    render("text_field.html", render_opts)
  end

  defp input_for_type(:email), do: &email_input/3
  defp input_for_type(:text), do: &text_input/3
  defp input_for_type(:hidden), do: &hidden_input/3
  defp input_for_type(:password), do: &password_input/3
end
