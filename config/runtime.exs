import Config

import Bitwise

indexer_memory_limit =
  "INDEXER_MEMORY_LIMIT"
  |> System.get_env("1")
  |> Integer.parse()
  |> case do
    {integer, ""} -> integer
    _ -> 1
  end

config :indexer,
  memory_limit: indexer_memory_limit <<< 32

indexer_empty_blocks_sanitizer_batch_size =
  if System.get_env("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE") do
    case Integer.parse(System.get_env("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE")) do
      {integer, ""} -> integer
      _ -> 100
    end
  else
    100
  end

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer.Supervisor,
  disabled?: System.get_env("INDEXER_DISABLE_EMPTY_BLOCK_SANITIZER", "false") == "true"

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer, batch_size: indexer_empty_blocks_sanitizer_batch_size

config :block_scout_web, :footer,
  chat_link: System.get_env("FOOTER_CHAT_LINK", "http://discord.gg/celo"),
  forum_link: System.get_env("FOOTER_FORUM_LINK", "https://forum.celo.org/"),
  github_link: System.get_env("FOOTER_GITHUB_LINK", "https://github.com/celo-org/blockscout")
