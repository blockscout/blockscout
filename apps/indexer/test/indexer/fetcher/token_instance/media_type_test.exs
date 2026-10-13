# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenInstance.MediaTypeTest do
  use Explorer.DataCase

  alias Indexer.Fetcher.TokenInstance.MediaType

  describe "child_spec/1" do
    test "wraps the fetcher into a BufferedTask" do
      child_spec = MediaType.child_spec([[max_batch_size: 5], [name: :test_server]])

      assert %{
               id: MediaType,
               start: {Indexer.BufferedTask, :start_link, _}
             } = child_spec
    end
  end

  describe "init/3" do
    setup do
      original = Application.get_env(:indexer, MediaType)

      on_exit(fn -> Application.put_env(:indexer, MediaType, original) end)

      :ok
    end

    test "streams only instances with metadata and a missing media type" do
      token = insert(:token, type: "ERC-721")

      pending =
        insert(:token_instance,
          token_id: 1,
          token_contract_address_hash: token.contract_address_hash,
          image_type: nil,
          animation_type: nil
        )

      insert(:token_instance,
        token_id: 2,
        token_contract_address_hash: token.contract_address_hash,
        image_type: "image/png",
        animation_type: ""
      )

      insert(:token_instance,
        token_id: 3,
        token_contract_address_hash: token.contract_address_hash,
        metadata: nil,
        image_type: nil,
        animation_type: nil
      )

      assert MediaType.init([], fn data, acc -> [data | acc] end, []) == [
               %{token_id: pending.token_id, contract_address_hash: pending.token_contract_address_hash}
             ]
    end

    test "loads at most init_limit instances per pass" do
      Application.put_env(:indexer, MediaType, Keyword.put(Application.get_env(:indexer, MediaType), :init_limit, 2))

      token = insert(:token, type: "ERC-721")

      for token_id <- 1..5 do
        insert(:token_instance,
          token_id: token_id,
          token_contract_address_hash: token.contract_address_hash,
          image_type: nil,
          animation_type: nil
        )
      end

      assert MediaType.init([], fn data, acc -> [data | acc] end, []) |> length() == 2
    end
  end
end
