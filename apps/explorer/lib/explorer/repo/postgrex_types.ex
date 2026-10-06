# SPDX-License-Identifier: LicenseRef-Blockscout
# Defines a custom Postgrex type module that encodes/decodes JSON columns
# using Elixir's built-in JSON library instead of Jason.
Postgrex.Types.define(Explorer.Repo.PostgrexTypes, [], json: Utils.JSON)
