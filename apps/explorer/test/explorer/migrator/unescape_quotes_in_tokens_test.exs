defmodule Explorer.Migrator.UnescapeQuotesInTokensTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.{UnescapeQuotesInTokens, MigrationStatus}
  alias Explorer.Repo

  test "Unescapes quotes in tokens" do
    escaped_name_token = insert(:token, name: "Smth&#39;s")
    escaped_symbol_token = insert(:token, symbol: "&quot;Double quoted&quot;")
    escaped_both_token = insert(:token, name: "Smth&#39;s", symbol: "&quot;Double quoted&quot;")
    common_token = :token |> insert() |> Repo.reload()

    assert MigrationStatus.get_status("unescape_quotes_in_tokens") == nil
    UnescapeQuotesInTokens.start_link([])

    Process.sleep(100)

    assert Repo.reload(escaped_name_token).name == "Smth's"
    assert Repo.reload(escaped_symbol_token).symbol == "\"Double quoted\""
    assert %{name: "Smth's", symbol: "\"Double quoted\""} = Repo.reload(escaped_both_token)
    assert ^common_token = Repo.reload(common_token)

    assert MigrationStatus.get_status("unescape_quotes_in_tokens") == "completed"
  end
end
