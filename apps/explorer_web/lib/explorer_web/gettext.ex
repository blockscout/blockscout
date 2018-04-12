defmodule ExplorerWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

  By using [Gettext](https://hexdocs.pm/gettext),
  your module gains a set of macros for translations, for example:

      import ExplorerWeb.Gettext

      # Simple translation
      gettext "Here is the string to translate"

      # Plural translation
      ngettext "Here is the string to translate",
               "Here are the strings to translate",
               3

      # Domain-based translation
      dgettext "errors", "Here is the error message to translate"

  See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
  """
  use Gettext, otp_app: :explorer_web

  @dialyzer [
    {:nowarn_function, "MACRO-dgettext": 3},
    {:nowarn_function, "MACRO-dgettext": 4},
    {:nowarn_function, "MACRO-dngettext": 5},
    {:nowarn_function, "MACRO-dngettext": 6}
  ]
end
