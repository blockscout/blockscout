# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.MetadataURIValidator do
  @moduledoc """
  Validates metadata URI.

  Thin wrapper around `Utils.UrlValidator`, which holds the actual validation logic in
  the `:utils` app so it can be shared by every app that fetches attacker-controlled
  URLs (see `Utils.HttpClient.SafeFetch`).
  """

  defdelegate validate_uri(uri), to: Utils.UrlValidator
end
