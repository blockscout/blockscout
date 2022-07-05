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
  memory_limit: indexer_memory_limit <<< 30

indexer_empty_blocks_sanitizer_batch_size =
  if System.get_env("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE") do
    case Integer.parse(System.get_env("INDEXER_EMPTY_BLOCKS_SANITIZER_BATCH_SIZE")) do
      {integer, ""} -> integer
      _ -> 100
    end
  else
    100
  end

config :indexer, Indexer.Fetcher.EmptyBlocksSanitizer, batch_size: indexer_empty_blocks_sanitizer_batch_size

config :block_scout_web, :footer,
  chat_link: System.get_env("FOOTER_CHAT_LINK", "https://discord.gg/XmNatGKbPS"),
  forum_link: System.get_env("FOOTER_FORUM_LINK", "https://forum.poa.network/c/blockscout"),
  github_link: System.get_env("FOOTER_GITHUB_LINK", "https://github.com/blockscout/blockscout")
