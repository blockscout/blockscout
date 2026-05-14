# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Token.MetadataRetriever.NftUrlTest do
  use ExUnit.Case, async: true

  alias Explorer.Token.MetadataRetriever

  describe "classify_nft_url/1" do
    test "classifies ipfs:// URL" do
      assert {:ipfs, "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"} =
               MetadataRetriever.classify_nft_url("ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
    end

    test "classifies ipfs://ipfs/ URL" do
      assert {:ipfs, "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"} =
               MetadataRetriever.classify_nft_url("ipfs://ipfs/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
    end

    test "classifies ipfs:// URL with path" do
      assert {:ipfs, "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG/metadata.json"} =
               MetadataRetriever.classify_nft_url("ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG/metadata.json")
    end

    test "classifies ar:// URL" do
      assert {:arweave, _resource_id} = MetadataRetriever.classify_nft_url("ar://abc123")
    end

    test "classifies ar:// URL with path" do
      assert {:arweave, "/metadata.json"} = MetadataRetriever.classify_nft_url("ar://abc123/metadata.json")
    end

    test "classifies https URL with /ipfs/ path" do
      assert {:ipfs, "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"} =
               MetadataRetriever.classify_nft_url(
                 "https://gateway.pinata.cloud/ipfs/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
               )
    end

    test "classifies regular https URL" do
      assert {:regular, "https://example.com/metadata.json"} =
               MetadataRetriever.classify_nft_url("https://example.com/metadata.json")
    end

    test "classifies bare path as bare_path" do
      assert {:bare_path, "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"} =
               MetadataRetriever.classify_nft_url("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
    end
  end

  describe "resolve_nft_media_url/1" do
    test "resolves ipfs:// URL to gateway URL" do
      {url, headers} =
        MetadataRetriever.resolve_nft_media_url("ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")

      assert url =~ "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
      assert url =~ "ipfs"
      refute url =~ "ipfs://"
      assert is_list(headers)
    end

    test "resolves ar:// URL with path to arweave.net" do
      {url, headers} = MetadataRetriever.resolve_nft_media_url("ar://abc123/metadata.json")

      assert url == "https://arweave.net//metadata.json"
      assert is_list(headers)
    end

    test "passes through regular https URL unchanged" do
      original = "https://example.com/image.png"
      assert {^original, []} = MetadataRetriever.resolve_nft_media_url(original)
    end

    test "resolves https URL with /ipfs/ path to gateway" do
      {url, headers} =
        MetadataRetriever.resolve_nft_media_url(
          "https://gateway.pinata.cloud/ipfs/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
        )

      assert url =~ "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
      assert is_list(headers)
    end

    test "returns original URL for invalid IPFS path" do
      original = "ipfs://not-a-valid-cid"
      assert {^original, []} = MetadataRetriever.resolve_nft_media_url(original)
    end

    test "resolves bare CID path via IPFS gateway" do
      {url, _headers} =
        MetadataRetriever.resolve_nft_media_url("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")

      assert url =~ "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
      refute url =~ "ipfs://"
    end
  end
end
