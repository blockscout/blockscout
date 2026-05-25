# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Token.InstanceTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Token.Instance
  alias Explorer.PagingOptions

  describe "stream_not_inserted_token_instances/2" do
    test "reduces with given reducer and accumulator for ERC-721 token" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      token_transfer =
        insert(
          :token_transfer,
          block_number: 1000,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_ids: [11]
        )

      assert [result] = 5 |> Instance.not_inserted_token_instances_query() |> Repo.all()
      assert result.token_id == List.first(token_transfer.token_ids)
      assert result.contract_address_hash == token_transfer.token_contract_address_hash
    end

    test "does not fetch token transfers without token_ids" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      insert(
        :token_transfer,
        block_number: 1000,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token,
        token_ids: nil
      )

      assert [] = 5 |> Instance.not_inserted_token_instances_query() |> Repo.all()
    end

    test "do not fetch records with token instances" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      token_transfer =
        insert(
          :token_transfer,
          block_number: 1000,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_ids: [11]
        )

      insert(:token_instance,
        token_id: List.first(token_transfer.token_ids),
        token_contract_address_hash: token_transfer.token_contract_address_hash
      )

      assert [] = 5 |> Instance.not_inserted_token_instances_query() |> Repo.all()
    end
  end

  describe "address_to_unique_tokens/2" do
    test "unique tokens can be paginated through token_id" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      insert(
        :token_instance,
        token_contract_address_hash: token_contract_address.hash,
        token_id: 11
      )

      insert(
        :token_instance,
        token_contract_address_hash: token_contract_address.hash,
        token_id: 29
      )

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      first_page =
        insert(
          :token_transfer,
          block_number: 1000,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_ids: [29]
        )

      second_page =
        insert(
          :token_transfer,
          block_number: 999,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_ids: [11]
        )

      paging_options = %PagingOptions{key: {List.first(first_page.token_ids)}, page_size: 1}

      unique_tokens_ids_paginated =
        token_contract_address.hash
        |> Instance.address_to_unique_tokens(token, paging_options: paging_options)
        |> Enum.map(& &1.token_id)

      assert unique_tokens_ids_paginated == [List.first(second_page.token_ids)]
    end
  end

  describe "nft_instance_by_token_id_and_token_address/2" do
    test "return NFT instance" do
      token = insert(:token)

      token_id = 10

      insert(:token_instance,
        token_contract_address_hash: token.contract_address_hash,
        token_id: token_id
      )

      assert {:ok, result} =
               Instance.nft_instance_by_token_id_and_token_address(
                 token_id,
                 token.contract_address_hash
               )

      assert result.token_id == Decimal.new(token_id)
    end
  end

  describe "batch_upsert_token_instances/1" do
    test "insert a new token instance with valid params" do
      token = insert(:token)

      params = %{
        token_id: 1,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{uri: "http://example.com"}
      }

      [result] = Instance.batch_upsert_token_instances([params])

      assert result.token_id == Decimal.new(1)
      assert result.metadata == %{"uri" => "http://example.com"}
      assert result.token_contract_address_hash == token.contract_address_hash
    end

    test "inserts just an error without metadata" do
      token = insert(:token)
      error = "no uri"

      params = %{
        token_id: 1,
        token_contract_address_hash: token.contract_address_hash,
        error: error
      }

      [result] = Instance.batch_upsert_token_instances([params])

      assert result.error == error
    end

    test "nillifies error" do
      token = insert(:token)

      insert(:token_instance,
        token_id: 1,
        token_contract_address_hash: token.contract_address_hash,
        error: "no uri",
        metadata: nil
      )

      params = %{
        token_id: 1,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{uri: "http://example1.com"}
      }

      [result] = Instance.batch_upsert_token_instances([params])

      assert is_nil(result.error)
      assert result.metadata == %{"uri" => "http://example1.com"}
    end
  end

  describe "mime_to_media_category/1" do
    test "returns nil for nil" do
      assert Instance.mime_to_media_category(nil) == nil
    end

    test "returns nil for empty string" do
      assert Instance.mime_to_media_category("") == nil
    end

    test "returns \"image\" for image MIME types" do
      assert Instance.mime_to_media_category("image/png") == "image"
      assert Instance.mime_to_media_category("image/jpeg") == "image"
      assert Instance.mime_to_media_category("image/svg+xml") == "image"
      assert Instance.mime_to_media_category("image") == "image"
    end

    test "returns \"video\" for video MIME types" do
      assert Instance.mime_to_media_category("video/mp4") == "video"
      assert Instance.mime_to_media_category("video/webm") == "video"
      assert Instance.mime_to_media_category("video") == "video"
    end

    test "returns \"html\" for text/html" do
      assert Instance.mime_to_media_category("text/html") == "html"
    end

    test "returns nil for unsupported MIME types" do
      assert Instance.mime_to_media_category("application/json") == nil
      assert Instance.mime_to_media_category("text/plain") == nil
      assert Instance.mime_to_media_category("audio/mpeg") == nil
    end
  end

  describe "get_image_url_from_metadata/1" do
    test "returns nil for nil metadata" do
      assert Instance.get_image_url_from_metadata(nil) == nil
    end

    test "extracts image_url field" do
      assert Instance.get_image_url_from_metadata(%{"image_url" => "https://example.com/img.png"}) ==
               "https://example.com/img.png"
    end

    test "extracts image field" do
      assert Instance.get_image_url_from_metadata(%{"image" => "ipfs://Qm123"}) == "ipfs://Qm123"
    end

    test "extracts from properties.image" do
      assert Instance.get_image_url_from_metadata(%{"properties" => %{"image" => "https://example.com/img.png"}}) ==
               "https://example.com/img.png"
    end

    test "prefers image_url over image" do
      metadata = %{"image_url" => "https://primary.com/img.png", "image" => "https://fallback.com/img.png"}
      assert Instance.get_image_url_from_metadata(metadata) == "https://primary.com/img.png"
    end

    test "returns nil when no image fields present" do
      assert Instance.get_image_url_from_metadata(%{"name" => "Token"}) == nil
    end

    test "returns nil for blank image_url" do
      assert Instance.get_image_url_from_metadata(%{"image_url" => "  "}) == nil
    end
  end

  describe "get_animation_url_from_metadata/1" do
    test "returns nil for nil metadata" do
      assert Instance.get_animation_url_from_metadata(nil) == nil
    end

    test "extracts animation_url" do
      assert Instance.get_animation_url_from_metadata(%{"animation_url" => "https://example.com/anim.mp4"}) ==
               "https://example.com/anim.mp4"
    end

    test "returns nil when no animation_url" do
      assert Instance.get_animation_url_from_metadata(%{"image" => "https://example.com/img.png"}) == nil
    end

    test "returns nil for blank animation_url" do
      assert Instance.get_animation_url_from_metadata(%{"animation_url" => "  "}) == nil
    end
  end

  describe "batch_update_media_types/1" do
    test "returns {0, nil} for empty list" do
      assert Instance.batch_update_media_types([]) == {0, nil}
    end

    test "updates media types for existing token instances" do
      instance = insert(:token_instance)

      assert {1, nil} =
               Instance.batch_update_media_types([
                 %{
                   token_contract_address_hash: instance.token_contract_address_hash,
                   token_id: instance.token_id,
                   image_type: "image/png",
                   animation_type: ""
                 }
               ])

      updated =
        Repo.get_by!(Instance,
          token_id: instance.token_id,
          token_contract_address_hash: instance.token_contract_address_hash
        )

      assert updated.image_type == "image/png"
      assert updated.animation_type == ""
    end

    test "updates multiple instances in a single batch" do
      instance1 = insert(:token_instance)
      instance2 = insert(:token_instance)

      assert {2, nil} =
               Instance.batch_update_media_types([
                 %{
                   token_contract_address_hash: instance1.token_contract_address_hash,
                   token_id: instance1.token_id,
                   image_type: "image/png",
                   animation_type: "video/mp4"
                 },
                 %{
                   token_contract_address_hash: instance2.token_contract_address_hash,
                   token_id: instance2.token_id,
                   image_type: "image/svg+xml",
                   animation_type: ""
                 }
               ])

      updated1 =
        Repo.get_by!(Instance,
          token_id: instance1.token_id,
          token_contract_address_hash: instance1.token_contract_address_hash
        )

      assert updated1.image_type == "image/png"
      assert updated1.animation_type == "video/mp4"

      updated2 =
        Repo.get_by!(Instance,
          token_id: instance2.token_id,
          token_contract_address_hash: instance2.token_contract_address_hash
        )

      assert updated2.image_type == "image/svg+xml"
      assert updated2.animation_type == ""
    end
  end

  describe "stream_token_instances_with_unfetched_media_type/2" do
    test "streams instances with metadata but nil image_type" do
      instance =
        insert(:token_instance,
          metadata: %{"image" => "https://example.com/img.png"},
          image_type: nil,
          animation_type: nil
        )

      {:ok, results} =
        Instance.stream_token_instances_with_unfetched_media_type([], fn data, acc -> [data | acc] end)

      assert length(results) == 1
      assert hd(results).contract_address_hash == instance.token_contract_address_hash
      assert hd(results).token_id == instance.token_id
    end

    test "does not stream instances with both types already set" do
      _instance =
        insert(:token_instance,
          metadata: %{"image" => "https://example.com/img.png"},
          image_type: "image/png",
          animation_type: ""
        )

      {:ok, results} =
        Instance.stream_token_instances_with_unfetched_media_type([], fn data, acc -> [data | acc] end)

      assert results == []
    end

    test "does not stream instances without metadata" do
      _instance = insert(:token_instance, metadata: nil, image_type: nil, animation_type: nil)

      {:ok, results} =
        Instance.stream_token_instances_with_unfetched_media_type([], fn data, acc -> [data | acc] end)

      assert results == []
    end

    test "streams instances where only one type is nil" do
      instance =
        insert(:token_instance,
          metadata: %{"image" => "https://example.com/img.png"},
          image_type: "image/png",
          animation_type: nil
        )

      {:ok, results} =
        Instance.stream_token_instances_with_unfetched_media_type([], fn data, acc -> [data | acc] end)

      assert length(results) == 1
      assert hd(results).token_id == instance.token_id
    end
  end
end
