# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.Helper do
  @moduledoc false

  alias OpenApiSpex.Schema

  @doc """
  Extends a schema with additional properties and required fields.

  Designed for use **inside an outer `OpenApiSpex.schema(…)` macro** that
  re-establishes a new component identity (a fresh `:title` and `x-struct`)
  for the extended result — for example, when defining
  `AddressNullable` by extending `Address.schema()` with `nullable: true`.

  Do **not** use this helper at a property position to overlay attributes
  (`description:`, `nullable:`, `pattern:`, …) on a leaf primitive such as
  `General.Timestamp`, `General.IntegerString`, or `General.HexData`. The
  returned struct retains the leaf's `:title` and `x-struct`, so
  `OpenApiSpex.resolve_schema_modules/1` registers it as
  `components.schemas.<Title>` on a last-encounter-wins basis. The overlay
  leaks onto the global component and every `$ref` pointing at it across
  the spec inherits the property-specific value.

  For per-property description overlays on a leaf primitive, use
  `describe_inline/2` instead — it strips `:title` and `x-struct` so the
  result is rendered inline at the call site and the global component
  stays pristine. For other per-property overrides (different `pattern:`,
  flipped `nullable:`, etc.), define a new primitive in
  `schemas/api/v2/general/` and reference that.
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

  @doc """
  Attaches a per-property description to a leaf schema for use at a property position.

  The result is rendered inline at the call site: `x-struct` and `title` are
  stripped from the input so `OpenApiSpex.resolve_schema_modules/1` does not
  register the result as the named OpenAPI component. The global
  `components.schemas.<Title>` entry stays untouched.

  This function is intentionally narrow — it only attaches a description. If
  a property needs a different `pattern:`, `nullable:`, or other constraint
  than the leaf provides, define a new primitive in
  `schemas/api/v2/general/` and describe that. This pushes the codebase
  toward a clean library of reusable primitives.
  """
  @spec describe_inline(Schema.t() | map(), String.t()) :: Schema.t() | map()
  def describe_inline(schema, description) do
    schema
    |> Map.put(:description, description)
    |> Map.put(:"x-struct", nil)
    |> Map.put(:title, nil)
  end
end
