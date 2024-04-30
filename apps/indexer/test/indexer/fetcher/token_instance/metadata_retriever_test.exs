defmodule Indexer.Fetcher.TokenInstance.MetadataRetrieverTest do
  use EthereumJSONRPC.Case

  alias Indexer.Fetcher.TokenInstance.MetadataRetriever
  alias Plug.Conn

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "fetch_json/4" do
    setup do
      bypass = Bypass.open()

      {:ok, bypass: bypass}
    end

    test "returns {:error, @no_uri_error} when empty uri is passed" do
      error = {:error, "no uri"}
      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true

      result = MetadataRetriever.fetch_json({:ok, [""]}, token_id, hex_token_id, from_base_uri)

      assert result == error
    end

    test "returns {:error, @vm_execution_error} when 'execution reverted' error passed in uri" do
      uri_error = {:error, "something happened: execution reverted"}
      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true
      result_error = {:error, "VM execution error"}

      result = MetadataRetriever.fetch_json(uri_error, token_id, hex_token_id, from_base_uri)

      assert result == result_error
    end

    test "returns {:error, @vm_execution_error} when 'VM execution error' error passed in uri" do
      error = {:error, "VM execution error"}
      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true

      result = MetadataRetriever.fetch_json(error, token_id, hex_token_id, from_base_uri)

      assert result == error
    end

    test "returns {:error, error} when all other errors passed in uri" do
      error = {:error, "Some error"}
      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true

      result = MetadataRetriever.fetch_json(error, token_id, hex_token_id, from_base_uri)

      assert result == error
    end

    test "returns {:error, truncated_error} when long error passed in uri" do
      error =
        {:error,
         "ERROR: Unable to establish a connection to the database server. The database server may be offline, or there could be a network issue preventing access. Please ensure that the database server is running and that the network configuration is correct. Additionally, check the database credentials and permissions to ensure they are valid. If the issue persists, contact your system administrator for further assistance. Error code: DB_CONN_FAILED_101234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890"}

      token_id = "TOKEN_ID"
      hex_token_id = "HEX_TOKEN_ID"
      from_base_uri = true

      truncated_error =
        {:error,
         "ERROR: Unable to establish a connection to the database server. The database server may be offline, or there could be a network issue preventing access. Please ensure that the database server is running and that the network configuration is correct. Ad..."}

      result = MetadataRetriever.fetch_json(error, token_id, hex_token_id, from_base_uri)

      assert result == truncated_error
    end

    test "Constructs IPFS link with query param" do
      configuration = Application.get_env(:indexer, :ipfs)

      Application.put_env(:indexer, :ipfs,
        gateway_url: Keyword.get(configuration, :gateway_url),
        gateway_url_param_location: :query,
        gateway_url_param_key: "x-apikey",
        gateway_url_param_value: "mykey"
      )

      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      result = %{
        "name" => "asda",
        "description" => "asda",
        "salePrice" => 34,
        "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
        "collectionId" => "1871_1665123820823"
      }

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      Explorer.Mox.HTTPoison
      |> expect(:get, fn "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP?x-apikey=mykey",
                         _headers,
                         _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(result)}}
      end)

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == MetadataRetriever.fetch_json({:ok, [data]})

      Application.put_env(:explorer, :http_adapter, HTTPoison)
      Application.put_env(:indexer, :ipfs, configuration)
    end

    test "Constructs IPFS link with no query param, if gateway_url_param_location is invalid" do
      configuration = Application.get_env(:indexer, :ipfs)

      Application.put_env(:indexer, :ipfs,
        gateway_url: Keyword.get(configuration, :gateway_url),
        gateway_url_param_location: :query2,
        gateway_url_param_key: "x-apikey",
        gateway_url_param_value: "mykey"
      )

      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      result = %{
        "name" => "asda",
        "description" => "asda",
        "salePrice" => 34,
        "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
        "collectionId" => "1871_1665123820823"
      }

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      Explorer.Mox.HTTPoison
      |> expect(:get, fn "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP", _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(result)}}
      end)

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == MetadataRetriever.fetch_json({:ok, [data]})

      Application.put_env(:explorer, :http_adapter, HTTPoison)
      Application.put_env(:indexer, :ipfs, configuration)
    end

    test "Constructs IPFS link with additional header" do
      configuration = Application.get_env(:indexer, :ipfs)

      Application.put_env(:indexer, :ipfs,
        gateway_url: Keyword.get(configuration, :gateway_url),
        gateway_url_param_location: :header,
        gateway_url_param_key: "x-apikey",
        gateway_url_param_value: "mykey"
      )

      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      result = %{
        "name" => "asda",
        "description" => "asda",
        "salePrice" => 34,
        "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
        "collectionId" => "1871_1665123820823"
      }

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      Explorer.Mox.HTTPoison
      |> expect(:get, fn "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP",
                         [{"x-apikey", "mykey"}],
                         _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(result)}}
      end)

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == MetadataRetriever.fetch_json({:ok, [data]})

      Application.put_env(:explorer, :http_adapter, HTTPoison)
      Application.put_env(:indexer, :ipfs, configuration)
    end

    test "fetches json with latin1 encoding", %{bypass: bypass} do
      path = "/api/card/55265"

      json = """
      {
        "name": "Sérgio Mendonça"
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      assert {:ok, %{metadata: %{"name" => "Sérgio Mendonça"}}} ==
               MetadataRetriever.fetch_json({:ok, ["http://localhost:#{bypass.port}#{path}"]})
    end

    test "fetches json metadata when HTTP status 301", %{bypass: bypass} do
      path = "/1302"

      attributes = """
      [
        {"trait_type": "Mouth", "value": "Discomfort"},
        {"trait_type": "Background", "value": "Army Green"},
        {"trait_type": "Eyes", "value": "Wide Eyed"},
        {"trait_type": "Fur", "value": "Black"},
        {"trait_type": "Earring", "value": "Silver Hoop"},
        {"trait_type": "Hat", "value": "Sea Captain's Hat"}
      ]
      """

      json = """
      {
        "attributes": #{attributes}
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      {:ok, %{metadata: metadata}} =
        MetadataRetriever.fetch_metadata_from_uri("http://localhost:#{bypass.port}#{path}", [])

      assert Map.get(metadata, "attributes") == Jason.decode!(attributes)
    end

    test "decodes json file in tokenURI" do
      data =
        {:ok,
         [
           "data:application/json,{\"name\":\"Home%20Address%20-%200x0000000000C1A6066c6c8B9d63e9B6E8865dC117\",\"description\":\"This%20NFT%20can%20be%20redeemed%20on%20HomeWork%20to%20grant%20a%20controller%20the%20exclusive%20right%20to%20deploy%20contracts%20with%20arbitrary%20bytecode%20to%20the%20designated%20home%20address.\",\"image\":\"data:image/svg+xml;charset=utf-8;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNDQgNzIiPjxzdHlsZT48IVtDREFUQVsuQntzdHJva2UtbGluZWpvaW46cm91bmR9LkN7c3Ryb2tlLW1pdGVybGltaXQ6MTB9LkR7c3Ryb2tlLXdpZHRoOjJ9LkV7ZmlsbDojOWI5YjlhfS5Ge3N0cm9rZS1saW5lY2FwOnJvdW5kfV1dPjwvc3R5bGU+PGcgdHJhbnNmb3JtPSJtYXRyaXgoMS4wMiAwIDAgMS4wMiA4LjEgMCkiPjxwYXRoIGZpbGw9IiNmZmYiIGQ9Ik0xOSAzMmgzNHYyNEgxOXoiLz48ZyBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI1IDQwaDl2MTZoLTl6Ii8+PHBhdGggZmlsbD0iIzkyZDNmNSIgZD0iTTQwIDQwaDh2N2gtOHoiLz48cGF0aCBmaWxsPSIjZWE1YTQ3IiBkPSJNNTMgMzJIMTl2LTFsMTYtMTYgMTggMTZ6Ii8+PHBhdGggZmlsbD0ibm9uZSIgZD0iTTE5IDMyaDM0djI0SDE5eiIvPjxwYXRoIGZpbGw9IiNlYTVhNDciIGQ9Ik0yOSAyMWwtNSA1di05aDV6Ii8+PC9nPjwvZz48ZyB0cmFuc2Zvcm09Im1hdHJpeCguODQgMCAwIC44NCA2NSA1KSI+PHBhdGggZD0iTTkuNSAyMi45bDQuOCA2LjRhMy4xMiAzLjEyIDAgMCAxLTMgMi4ybC00LjgtNi40Yy4zLTEuNCAxLjYtMi40IDMtMi4yeiIgZmlsbD0iI2QwY2ZjZSIvPjxwYXRoIGZpbGw9IiMwMTAxMDEiIGQ9Ik00MS43IDM4LjVsNS4xLTYuNSIvPjxwYXRoIGQ9Ik00Mi45IDI3LjhMMTguNCA1OC4xIDI0IDYybDIxLjgtMjcuMyAyLjMtMi44eiIgY2xhc3M9IkUiLz48cGF0aCBmaWxsPSIjMDEwMTAxIiBkPSJNNDMuNCAyOS4zbC00LjcgNS44Ii8+PHBhdGggZD0iTTQ2LjggMzJjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uNy0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4ycy0zLjYgOS45LS4zIDEyLjUiIGNsYXNzPSJFIi8+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI3LjMgMjZsMTEuOCAxNS43IDMuNCAyLjQgOS4xIDE0LjQtMy4yIDIuMy0xIC43LTEwLjItMTMuNi0xLjMtMy45LTExLjgtMTUuN3oiLz48cGF0aCBkPSJNMTIgMTkuOWw1LjkgNy45IDEwLjItNy42LTMuNC00LjVzNi44LTUuMSAxMC43LTQuNWMwIDAtNi42LTMtMTMuMyAxLjFTMTIgMTkuOSAxMiAxOS45eiIgY2xhc3M9IkUiLz48ZyBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZD0iTTUyIDU4LjlMNDAuOSA0My4ybC0zLjEtMi4zLTEwLjYtMTQuNy0yLjkgMi4yIDEwLjYgMTQuNyAxLjEgMy42IDExLjUgMTUuNXpNMTIuNSAxOS44bDUuOCA4IDEwLjMtNy40LTMuMy00LjZzNi45LTUgMTAuOC00LjNjMCAwLTYuNi0zLjEtMTMuMy45cy0xMC4zIDcuNC0xMC4zIDcuNHptLTIuNiAyLjlsNC43IDYuNWMtLjUgMS4zLTEuNyAyLjEtMyAyLjJsLTQuNy02LjVjLjMtMS40IDEuNi0yLjQgMy0yLjJ6Ii8+PHBhdGggZD0iTTQxLjMgMzguNWw1LjEtNi41bS0zLjUtMi43bC00LjYgNS44bTguMS0zLjFjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uOC0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4yLTMuNCA0LjMtMy42IDkuOS0uMyAxMi41IiBjbGFzcz0iRiIvPjxwYXRoIGQ9Ik0zMC44IDQ0LjRMMTkgNTguOWw0IDMgMTAtMTIuNyIgY2xhc3M9IkYiLz48L2c+PC9nPjwvc3ZnPg==\"}"
         ]}

      assert MetadataRetriever.fetch_json(data) ==
               {:ok,
                %{
                  metadata: %{
                    "description" =>
                      "This NFT can be redeemed on HomeWork to grant a controller the exclusive right to deploy contracts with arbitrary bytecode to the designated home address.",
                    "image" =>
                      "data:image/svg+xml;charset=utf-8;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNDQgNzIiPjxzdHlsZT48IVtDREFUQVsuQntzdHJva2UtbGluZWpvaW46cm91bmR9LkN7c3Ryb2tlLW1pdGVybGltaXQ6MTB9LkR7c3Ryb2tlLXdpZHRoOjJ9LkV7ZmlsbDojOWI5YjlhfS5Ge3N0cm9rZS1saW5lY2FwOnJvdW5kfV1dPjwvc3R5bGU+PGcgdHJhbnNmb3JtPSJtYXRyaXgoMS4wMiAwIDAgMS4wMiA4LjEgMCkiPjxwYXRoIGZpbGw9IiNmZmYiIGQ9Ik0xOSAzMmgzNHYyNEgxOXoiLz48ZyBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI1IDQwaDl2MTZoLTl6Ii8+PHBhdGggZmlsbD0iIzkyZDNmNSIgZD0iTTQwIDQwaDh2N2gtOHoiLz48cGF0aCBmaWxsPSIjZWE1YTQ3IiBkPSJNNTMgMzJIMTl2LTFsMTYtMTYgMTggMTZ6Ii8+PHBhdGggZmlsbD0ibm9uZSIgZD0iTTE5IDMyaDM0djI0SDE5eiIvPjxwYXRoIGZpbGw9IiNlYTVhNDciIGQ9Ik0yOSAyMWwtNSA1di05aDV6Ii8+PC9nPjwvZz48ZyB0cmFuc2Zvcm09Im1hdHJpeCguODQgMCAwIC44NCA2NSA1KSI+PHBhdGggZD0iTTkuNSAyMi45bDQuOCA2LjRhMy4xMiAzLjEyIDAgMCAxLTMgMi4ybC00LjgtNi40Yy4zLTEuNCAxLjYtMi40IDMtMi4yeiIgZmlsbD0iI2QwY2ZjZSIvPjxwYXRoIGZpbGw9IiMwMTAxMDEiIGQ9Ik00MS43IDM4LjVsNS4xLTYuNSIvPjxwYXRoIGQ9Ik00Mi45IDI3LjhMMTguNCA1OC4xIDI0IDYybDIxLjgtMjcuMyAyLjMtMi44eiIgY2xhc3M9IkUiLz48cGF0aCBmaWxsPSIjMDEwMTAxIiBkPSJNNDMuNCAyOS4zbC00LjcgNS44Ii8+PHBhdGggZD0iTTQ2LjggMzJjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uNy0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4ycy0zLjYgOS45LS4zIDEyLjUiIGNsYXNzPSJFIi8+PHBhdGggZmlsbD0iI2E1NzkzOSIgZD0iTTI3LjMgMjZsMTEuOCAxNS43IDMuNCAyLjQgOS4xIDE0LjQtMy4yIDIuMy0xIC43LTEwLjItMTMuNi0xLjMtMy45LTExLjgtMTUuN3oiLz48cGF0aCBkPSJNMTIgMTkuOWw1LjkgNy45IDEwLjItNy42LTMuNC00LjVzNi44LTUuMSAxMC43LTQuNWMwIDAtNi42LTMtMTMuMyAxLjFTMTIgMTkuOSAxMiAxOS45eiIgY2xhc3M9IkUiLz48ZyBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAiIGNsYXNzPSJCIEMgRCI+PHBhdGggZD0iTTUyIDU4LjlMNDAuOSA0My4ybC0zLjEtMi4zLTEwLjYtMTQuNy0yLjkgMi4yIDEwLjYgMTQuNyAxLjEgMy42IDExLjUgMTUuNXpNMTIuNSAxOS44bDUuOCA4IDEwLjMtNy40LTMuMy00LjZzNi45LTUgMTAuOC00LjNjMCAwLTYuNi0zLjEtMTMuMy45cy0xMC4zIDcuNC0xMC4zIDcuNHptLTIuNiAyLjlsNC43IDYuNWMtLjUgMS4zLTEuNyAyLjEtMyAyLjJsLTQuNy02LjVjLjMtMS40IDEuNi0yLjQgMy0yLjJ6Ii8+PHBhdGggZD0iTTQxLjMgMzguNWw1LjEtNi41bS0zLjUtMi43bC00LjYgNS44bTguMS0zLjFjMy4yIDIuNiA4LjcgMS4yIDEyLjEtMy4yczMuNi05LjkuMy0xMi41bC01LjEgNi41LTIuOC0uMS0uOC0yLjcgNS4xLTYuNWMtMy4yLTIuNi04LjctMS4yLTEyLjEgMy4yLTMuNCA0LjMtMy42IDkuOS0uMyAxMi41IiBjbGFzcz0iRiIvPjxwYXRoIGQ9Ik0zMC44IDQ0LjRMMTkgNTguOWw0IDMgMTAtMTIuNyIgY2xhc3M9IkYiLz48L2c+PC9nPjwvc3ZnPg==",
                    "name" => "Home Address - 0x0000000000C1A6066c6c8B9d63e9B6E8865dC117"
                  }
                }}
    end

    test "decodes base64 encoded json file in tokenURI" do
      data =
        {:ok,
         [
           "data:application/json;base64,eyJuYW1lIjogIi54ZGFpIiwgImRlc2NyaXB0aW9uIjogIlB1bmsgRG9tYWlucyBkaWdpdGFsIGlkZW50aXR5LiBWaXNpdCBodHRwczovL3B1bmsuZG9tYWlucy8iLCAiaW1hZ2UiOiAiZGF0YTppbWFnZS9zdmcreG1sO2Jhc2U2NCxQSE4yWnlCNGJXeHVjejBpYUhSMGNEb3ZMM2QzZHk1M015NXZjbWN2TWpBd01DOXpkbWNpSUhacFpYZENiM2c5SWpBZ01DQTFNREFnTlRBd0lpQjNhV1IwYUQwaU5UQXdJaUJvWldsbmFIUTlJalV3TUNJK1BHUmxabk0rUEd4cGJtVmhja2R5WVdScFpXNTBJR2xrUFNKbmNtRmtJaUI0TVQwaU1DVWlJSGt4UFNJd0pTSWdlREk5SWpFd01DVWlJSGt5UFNJd0pTSStQSE4wYjNBZ2IyWm1jMlYwUFNJd0pTSWdjM1I1YkdVOUluTjBiM0F0WTI5c2IzSTZjbWRpS0RVNExERTNMREV4TmlrN2MzUnZjQzF2Y0dGamFYUjVPakVpSUM4K1BITjBiM0FnYjJabWMyVjBQU0l4TURBbElpQnpkSGxzWlQwaWMzUnZjQzFqYjJ4dmNqcHlaMklvTVRFMkxESTFMREUzS1R0emRHOXdMVzl3WVdOcGRIazZNU0lnTHo0OEwyeHBibVZoY2tkeVlXUnBaVzUwUGp3dlpHVm1jejQ4Y21WamRDQjRQU0l3SWlCNVBTSXdJaUIzYVdSMGFEMGlOVEF3SWlCb1pXbG5hSFE5SWpVd01DSWdabWxzYkQwaWRYSnNLQ05uY21Ga0tTSXZQangwWlhoMElIZzlJalV3SlNJZ2VUMGlOVEFsSWlCa2IyMXBibUZ1ZEMxaVlYTmxiR2x1WlQwaWJXbGtaR3hsSWlCbWFXeHNQU0ozYUdsMFpTSWdkR1Y0ZEMxaGJtTm9iM0k5SW0xcFpHUnNaU0lnWm05dWRDMXphWHBsUFNKNExXeGhjbWRsSWo0dWVHUmhhVHd2ZEdWNGRENDhkR1Y0ZENCNFBTSTFNQ1VpSUhrOUlqY3dKU0lnWkc5dGFXNWhiblF0WW1GelpXeHBibVU5SW0xcFpHUnNaU0lnWm1sc2JEMGlkMmhwZEdVaUlIUmxlSFF0WVc1amFHOXlQU0p0YVdSa2JHVWlQbkIxYm1zdVpHOXRZV2x1Y3p3dmRHVjRkRDQ4TDNOMlp6ND0ifQ=="
         ]}

      assert MetadataRetriever.fetch_json(data) ==
               {:ok,
                %{
                  metadata: %{
                    "name" => ".xdai",
                    "description" => "Punk Domains digital identity. Visit https://punk.domains/",
                    "image" =>
                      "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA1MDAgNTAwIiB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCI+PGRlZnM+PGxpbmVhckdyYWRpZW50IGlkPSJncmFkIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIwJSI+PHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6cmdiKDU4LDE3LDExNik7c3RvcC1vcGFjaXR5OjEiIC8+PHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjpyZ2IoMTE2LDI1LDE3KTtzdG9wLW9wYWNpdHk6MSIgLz48L2xpbmVhckdyYWRpZW50PjwvZGVmcz48cmVjdCB4PSIwIiB5PSIwIiB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCIgZmlsbD0idXJsKCNncmFkKSIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiBmaWxsPSJ3aGl0ZSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSJ4LWxhcmdlIj4ueGRhaTwvdGV4dD48dGV4dCB4PSI1MCUiIHk9IjcwJSIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgZmlsbD0id2hpdGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPnB1bmsuZG9tYWluczwvdGV4dD48L3N2Zz4="
                  }
                }}
    end

    test "decodes base64 encoded json file (with unicode string) in tokenURI" do
      data =
        {:ok,
         [
           "data:application/json;base64,eyJkZXNjcmlwdGlvbiI6ICJQdW5rIERvbWFpbnMgZGlnaXRhbCBpZGVudGl0eSDDry4gVmlzaXQgaHR0cHM6Ly9wdW5rLmRvbWFpbnMvIn0="
         ]}

      assert MetadataRetriever.fetch_json(data) ==
               {:ok,
                %{
                  metadata: %{
                    "description" => "Punk Domains digital identity ï. Visit https://punk.domains/"
                  }
                }}
    end

    test "fetches image from ipfs link directly", %{bypass: bypass} do
      path = "/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"

      json = """
      {
        "image": "https://ipfs.io/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      data =
        {:ok,
         [
           "http://localhost:#{bypass.port}#{path}"
         ]}

      assert {:ok,
              %{
                metadata: %{
                  "image" => "https://ipfs.io/ipfs/bafybeig6nlmyzui7llhauc52j2xo5hoy4lzp6442lkve5wysdvjkizxonu"
                }
              }} == MetadataRetriever.fetch_json(data)
    end

    test "Fetches metadata from ipfs", %{bypass: bypass} do
      path = "/ipfs/bafybeid4ed2ua7fwupv4nx2ziczr3edhygl7ws3yx6y2juon7xakgj6cfm/51.json"

      json = """
      {
        "image": "ipfs://bafybeihxuj3gxk7x5p36amzootyukbugmx3pw7dyntsrohg3se64efkuga/51.png"
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      data =
        {:ok,
         [
           "http://localhost:#{bypass.port}#{path}"
         ]}

      {:ok,
       %{
         metadata: metadata
       }} = MetadataRetriever.fetch_json(data)

      assert "ipfs://bafybeihxuj3gxk7x5p36amzootyukbugmx3pw7dyntsrohg3se64efkuga/51.png" == Map.get(metadata, "image")
    end

    test "Fetches metadata from '${url}'", %{bypass: bypass} do
      path = "/data/8/8578.json"

      data =
        {:ok,
         [
           "'http://localhost:#{bypass.port}#{path}'"
         ]}

      json = """
      {
        "attributes": [
          {"trait_type": "Character", "value": "Blue Suit Boxing Glove"},
          {"trait_type": "Face", "value": "Wink"},
          {"trait_type": "Hat", "value": "Blue"},
          {"trait_type": "Background", "value": "Red Carpet"}
        ],
        "image": "https://cards.collecttrumpcards.com/cards/0c68b1ab6.jpg",
        "name": "Trump Digital Trading Card #8578",
        "tokeId": 8578
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      assert {:ok,
              %{
                metadata: Jason.decode!(json)
              }} == MetadataRetriever.fetch_json(data)
    end

    test "Process custom execution reverted" do
      data =
        {:error,
         "(3) execution reverted: Nonexistent token (0x08c379a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000114e6f6e6578697374656e7420746f6b656e000000000000000000000000000000)"}

      assert {:error, "VM execution error"} == MetadataRetriever.fetch_json(data)
    end

    test "Process CIDv0 IPFS links" do
      data = "QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP"

      result = %{
        "name" => "asda",
        "description" => "asda",
        "salePrice" => 34,
        "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
        "collectionId" => "1871_1665123820823"
      }

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      Explorer.Mox.HTTPoison
      |> expect(:get, fn "https://ipfs.io/ipfs/QmT1Yz43R1PLn2RVovAnEM5dHQEvpTcnwgX8zftvY1FcjP", _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(result)}}
      end)

      assert {:ok,
              %{
                metadata: %{
                  "collectionId" => "1871_1665123820823",
                  "description" => "asda",
                  "img_hash" => "QmUfW3PVnh9GGuHcQgc3ZeNEbhwp5HE8rS5ac9MDWWQebz",
                  "name" => "asda",
                  "salePrice" => 34
                }
              }} == MetadataRetriever.fetch_json({:ok, [data]})

      Application.put_env(:explorer, :http_adapter, HTTPoison)
    end

    test "Process URI directly from link", %{bypass: bypass} do
      path = "/api/dejobio/v1/nftproduct/1"

      json = """
      {
          "image": "https:\/\/cdn.discordapp.com\/attachments\/1008567215739650078\/1080111780858187796\/savechives_a_dragon_playing_football_in_a_city_full_of_flowers__0739cc42-aae1-4909-a964-3f9c0ed1a9ed.png",
          "external_url": "https:\/\/dejob.io\/blue-reign-the-dragon-football-champion-of-the-floral-city\/",
          "name": "Blue Reign: The Dragon Football Champion of the Floral City",
          "description": "Test",
          "attributes": [
              {
                  "trait_type": "Product Type",
                  "value": "Book"
              },
              {
                  "display_type": "number",
                  "trait_type": "Total Sold",
                  "value": "0"
              },
              {
                  "display_type": "number",
                  "trait_type": "Success Sold",
                  "value": "0"
              },
              {
                  "max_value": "100",
                  "trait_type": "Success Rate",
                  "value": "0"
              }
          ]
      }
      """

      Bypass.expect(bypass, "GET", path, fn conn ->
        Conn.resp(conn, 200, json)
      end)

      assert {:ok,
              %{
                metadata: Jason.decode!(json)
              }} ==
               MetadataRetriever.fetch_json({:ok, ["http://localhost:#{bypass.port}#{path}"]})
    end
  end
end
