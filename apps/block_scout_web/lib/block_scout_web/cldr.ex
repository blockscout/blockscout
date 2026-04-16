defmodule BlockScoutWeb.Cldr do
  @moduledoc """
  Cldr global configuration.

  Note: The `gettext` option is intentionally omitted here to avoid a circular
  compile-time dependency. When `gettext: BlockScoutWeb.Gettext` is specified,
  ex_cldr's code generation triggers loading of modules that use the Gettext
  backend (including view modules via `use BlockScoutWeb, :view`). Those view
  modules attempt `use Phoenix.View` before it is available, causing a
  compilation error. Since the application only uses the "en" locale, the
  Gettext integration for plural rules is not required.
  """

  use Cldr,
    default_locale: "en",
    locales: ["en"],
    generate_docs: false,
    precompile_number_formats: ["#,###", "#,##0.##################", "#.#%", "#,##0"],
    providers: [Cldr.Number, Cldr.Unit]
end
