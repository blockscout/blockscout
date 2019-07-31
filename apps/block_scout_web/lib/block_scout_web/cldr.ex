defmodule BlockScoutWeb.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en"],
    gettext: BlockScoutWeb.Gettext,
    generate_docs: false,
    providers: [Cldr.Number, Cldr.Unit]
end
