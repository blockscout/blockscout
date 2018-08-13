defmodule ExplorerWeb.APIDocsView do
  use ExplorerWeb, :view

  def action_tile_id(module, action) do
    "#{module}-#{action}"
  end

  def query_params(module, action) do
    module_and_action(module, action) <> Enum.join(required_params(action))
  end

  def input_placeholder(param) do
    "#{param.key} - #{param.description}"
  end

  def model_type_definition(definition) when is_binary(definition) do
    definition
  end

  def model_type_definition(definition_func) when is_function(definition_func, 1) do
    coin = Application.get_env(:explorer, :coin)
    definition_func.(coin)
  end

  defp module_and_action(module, action) do
    "?module=<strong>#{module}</strong>&action=<strong>#{action.name}</strong>"
  end

  defp required_params(action) do
    Enum.map(action.required_params, fn param ->
      "&#{param.key}=" <>
        "<span class='text-primary'>{</span>" <>
        "<strong>#{param.placeholder}</strong><span class='text-primary'>}</span>"
    end)
  end
end
