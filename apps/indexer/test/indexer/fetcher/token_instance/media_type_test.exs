# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenInstance.MediaTypeTest do
  use Explorer.DataCase

  alias Explorer.Chain.Token.Instance
  alias Indexer.Fetcher.TokenInstance.MediaType

  describe "child_spec/1" do
    test "wraps the fetcher into a BufferedTask" do
      child_spec = MediaType.child_spec([[max_batch_size: 5], [name: :test_server]])

      assert %{
               id: MediaType,
               start: {Indexer.BufferedTask, :start_link, [{MediaType, init_options}, [name: :test_server]]}
             } = child_spec

      assert init_options[:max_batch_size] == 5
    end

    test "uses a finite flush interval so the next chunk of the backlog gets polled" do
      %{start: {_, _, [{MediaType, init_options}, _]}} = MediaType.child_spec([[], []])

      assert is_integer(init_options[:flush_interval])
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

  describe "polling" do
    setup do
      original = Application.get_env(:indexer, MediaType)
      original_init_delay = Application.get_env(:indexer, :fetcher_init_delay)

      Application.put_env(:indexer, MediaType, Keyword.merge(original, init_limit: 2))
      Application.put_env(:indexer, :fetcher_init_delay, 1)

      on_exit(fn ->
        Application.put_env(:indexer, MediaType, original)
        Application.put_env(:indexer, :fetcher_init_delay, original_init_delay)
      end)

      :ok
    end

    test "keeps loading the next chunk until the whole backlog is processed" do
      token = insert(:token, type: "ERC-721")

      for token_id <- 1..5 do
        insert(:token_instance,
          token_id: token_id,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{"image" => "data:image/png;base64,iVBORw0KGgo="},
          image_type: nil,
          animation_type: nil
        )
      end

      start_supervised!({MediaType.Supervisor, [[flush_interval: 10, max_batch_size: 1, max_concurrency: 1]]})

      wait_until(fn ->
        Instance
        |> where([instance], is_nil(instance.image_type) or is_nil(instance.animation_type))
        |> Repo.aggregate(:count) == 0
      end)

      assert Instance |> Repo.all() |> Enum.all?(&(&1.image_type == "image" and &1.animation_type == ""))
    end

    defp wait_until(condition, retries \\ 100)

    defp wait_until(_condition, 0), do: flunk("media type fetcher did not process the whole backlog")

    defp wait_until(condition, retries) do
      if condition.() do
        :ok
      else
        Process.sleep(50)
        wait_until(condition, retries - 1)
      end
    end
  end
end
