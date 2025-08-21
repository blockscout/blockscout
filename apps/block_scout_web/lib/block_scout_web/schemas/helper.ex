defmodule BlockScoutWeb.Schemas.Helper do
  @moduledoc false

  alias OpenApiSpex.Schema

  @doc """
  Extends a schema with additional properties and required fields.
  """
  @spec extend_schema(Schema.t() | map(), Keyword.t()) :: Schema.t() | map()
  def extend_schema(schema, options) do
    updated_schema =
      schema
      |> Map.update!(:properties, &Map.merge(&1, Keyword.get(options, :properties, %{})))
      |> Map.update!(:required, &(&1 ++ Keyword.get(options, :required, [])))

    updated_schema_with_title =
      if Keyword.has_key?(options, :title),
        do: Map.put(updated_schema, :title, Keyword.get(options, :title)),
        else: updated_schema

    updated_schema_with_description =
      if Keyword.has_key?(options, :description),
        do: Map.put(updated_schema_with_title, :description, Keyword.get(options, :description)),
        else: updated_schema_with_title

    updated_schema_with_description
  end
end
