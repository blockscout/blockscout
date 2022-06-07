defmodule BlockScoutWeb.Account.PublicTagsRequestView do
  use BlockScoutWeb, :view
  use Phoenix.HTML
  alias Phoenix.HTML.Form

  def array_input(form, field, attrs \\ []) do
    values = Form.input_value(form, field) || [""]
    id = Form.input_id(form, field)

    content_tag :ul,
      id: container_id(id),
      data: [index: Enum.count(values), multiple_input_field_container: ""],
      class: "multiple-input-fields-container" do
      values
      |> Enum.map(fn v ->
        form_elements(form, field, v, attrs)
      end)
    end
  end

  def array_add_button(form, field, attrs \\ []) do
    id = Form.input_id(form, field)

    content =
      form
      |> form_elements(field, "", attrs)
      |> safe_to_string

    data = [
      prototype: content,
      container: container_id(id)
    ]

    content_tag(:button, render(BlockScoutWeb.CommonComponentsView, "_svg_plus.html"),
      data: data,
      class: "add-form-field"
    )
  end

  defp form_elements(form, field, k, attrs) do
    type = Form.input_type(form, field)
    id = Form.input_id(form, field)

    input_opts =
      [
        name: new_field_name(form, field),
        value: k,
        id: id,
        class: "form-control public-tags-address"
      ] ++ attrs

    content_tag :li, class: "public-tags-address form-group" do
      [
        apply(Form, type, [form, field, input_opts]),
        content_tag(:button, render(BlockScoutWeb.CommonComponentsView, "_svg_minus.html"),
          data: [container: container_id(id)],
          class: "remove-form-field"
        )
      ]
    end
  end

  defp container_id(id), do: id <> "_container"

  defp new_field_name(form, field) do
    Form.input_name(form, field) <> "[]"
  end
end
