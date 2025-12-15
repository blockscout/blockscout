defmodule BlockScoutWeb.Schemas.Helper do
  @moduledoc false

  alias OpenApiSpex.Schema

  @doc """
  Extends a schema with additional properties and required fields.
  """
  @spec extend_schema(Schema.t() | map(), Keyword.t()) :: Schema.t() | map()
  def extend_schema(schema, options) do
    updated_schema_with_properties =
      if Keyword.has_key?(options, :properties),
        do:
          Map.update!(schema, :properties, fn properties ->
            Map.merge(properties, Keyword.get(options, :properties, %{}))
          end),
        else: schema

    updated_schema_with_required =
      if Keyword.has_key?(options, :required),
        do:
          Map.update!(updated_schema_with_properties, :required, fn required ->
            required ++ Keyword.get(options, :required, [])
          end),
        else: updated_schema_with_properties

    updated_schema_with_title =
      if Keyword.has_key?(options, :title),
        do: Map.put(updated_schema_with_required, :title, Keyword.get(options, :title)),
        else: updated_schema_with_required

    updated_schema_with_description =
      if Keyword.has_key?(options, :description),
        do: Map.put(updated_schema_with_title, :description, Keyword.get(options, :description)),
        else: updated_schema_with_title

    updated_schema_with_nullable =
      if Keyword.has_key?(options, :nullable),
        do: Map.put(updated_schema_with_description, :nullable, Keyword.get(options, :nullable)),
        else: updated_schema_with_description

    updated_schema_with_enum =
      if Keyword.has_key?(options, :enum),
        do: Map.put(updated_schema_with_nullable, :enum, Keyword.get(options, :enum)),
        else: updated_schema_with_nullable

    updated_schema_with_enum
  end
end
