defmodule BlockScoutWeb.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en"],
    gettext: BlockScoutWeb.Gettext,
    generate_docs: false
end
