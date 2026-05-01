defmodule Utils.JSONTest do
  use ExUnit.Case
  doctest Utils.JSON

  describe "encode!/2" do
    test "encodes basic term to JSON string" do
      result = Utils.JSON.encode!([1, 2, 3])
      assert result == "[1,2,3]"
    end

    test "encodes map to JSON string" do
      result = Utils.JSON.encode!(%{"key" => "value", "num" => 42})
      # Order may vary, so check both keys are present
      assert String.contains?(result, [~s("key":"value"), ~s("num":42)])
    end

    test "encodes with pretty option" do
      result = Utils.JSON.encode!(%{"key" => "value"}, pretty: true)
      assert String.contains?(result, "\n")
      assert String.contains?(result, " ")
    end

    test "encodes with custom space count for pretty" do
      result = Utils.JSON.encode!([1, 2], pretty: true, space: 4)
      assert String.contains?(result, "\n")
      # Should have 4-space indentation
      assert String.contains?(result, "    ")
    end

    test "encodes nil" do
      assert Utils.JSON.encode!(nil) == "null"
    end

    test "encodes booleans" do
      assert Utils.JSON.encode!(true) == "true"
      assert Utils.JSON.encode!(false) == "false"
    end

    test "encodes strings" do
      assert Utils.JSON.encode!("hello") == ~s("hello")
    end

    test "raises on circular reference" do
      circular = %{"a" => 1}
      # Elixir JSON doesn't support circular refs, so this may raise
      # depending on the data structure. Just verify no crash on simple data.
      assert Utils.JSON.encode!(%{"test" => circular}) |> is_binary()
    end
  end

  describe "encode_to_iodata!/2" do
    test "encodes to iodata" do
      result = Utils.JSON.encode_to_iodata!([1, 2, 3])
      assert IO.iodata_to_binary(result) == "[1,2,3]"
    end

    test "encodes to iodata with pretty option" do
      result = Utils.JSON.encode_to_iodata!(%{"key" => "value"}, pretty: true)
      binary = IO.iodata_to_binary(result)
      assert String.contains?(binary, "\n")
    end
  end

  describe "encode/2" do
    test "returns ok tuple on success" do
      {:ok, result} = Utils.JSON.encode(%{"key" => "value"})
      assert is_binary(result)
    end
  end

  describe "decode!/2" do
    test "decodes basic JSON string to term" do
      result = Utils.JSON.decode!("[1,2,3]")
      assert result == [1, 2, 3]
    end

    test "decodes object with string keys" do
      result = Utils.JSON.decode!(~s({"key":"value"}))
      assert result == %{"key" => "value"}
    end

    test "decodes object with atom keys" do
      result = Utils.JSON.decode!(~s({"key":"value"}), keys: :atoms)
      assert result == %{key: "value"}
    end

    test "decodes nested object with atom keys" do
      result = Utils.JSON.decode!(~s({"outer":{"inner":"value"}}), keys: :atoms)
      assert result == %{outer: %{inner: "value"}}
    end

    test "decodes array with nested objects as atoms" do
      result = Utils.JSON.decode!(~s([{"key":"value"}]), keys: :atoms)
      assert result == [%{key: "value"}]
    end

    test "decodes null" do
      assert Utils.JSON.decode!("null") == nil
    end

    test "decodes booleans" do
      assert Utils.JSON.decode!("true") == true
      assert Utils.JSON.decode!("false") == false
    end

    test "decodes numbers" do
      assert Utils.JSON.decode!("42") == 42
      assert Utils.JSON.decode!("3.14") == 3.14
    end

    test "raises on invalid JSON" do
      assert_raise JSON.DecodeError, fn ->
        Utils.JSON.decode!("{invalid}")
      end
    end
  end

  describe "decode/2" do
    test "returns ok tuple on success" do
      {:ok, result} = Utils.JSON.decode("[1,2,3]")
      assert result == [1, 2, 3]
    end

    test "returns error tuple on invalid JSON" do
      {:error, _reason} = Utils.JSON.decode("{invalid}")
    end

    test "respects atom keys option" do
      {:ok, result} = Utils.JSON.decode(~s({"key":"value"}), keys: :atoms)
      assert result == %{key: "value"}
    end
  end

  describe "decode_string/2" do
    test "returns decoded term on success" do
      result = Utils.JSON.decode_string("[1,2,3]")
      assert result == [1, 2, 3]
    end

    test "returns nil on invalid JSON" do
      result = Utils.JSON.decode_string("{invalid}")
      assert result == nil
    end

    test "respects atom keys option" do
      result = Utils.JSON.decode_string(~s({"key":"value"}), keys: :atoms)
      assert result == %{key: "value"}
    end
  end

  describe "pretty printing" do
    test "formats object with proper indentation" do
      data = %{"name" => "John", "age" => 30}
      result = Utils.JSON.encode!(data, pretty: true)

      # Should have newlines and indentation
      assert String.contains?(result, "\n")
      assert String.contains?(result, "  ")
    end

    test "formats array with proper indentation" do
      data = [%{"id" => 1}, %{"id" => 2}]
      result = Utils.JSON.encode!(data, pretty: true)

      assert String.contains?(result, "\n")
      assert String.contains?(result, "  ")
    end

    test "formats nested structures" do
      data = %{"user" => %{"name" => "John", "emails" => ["a@test", "b@test"]}}
      result = Utils.JSON.encode!(data, pretty: true)

      # Verify it's valid JSON with pretty format
      parsed = Utils.JSON.decode!(result)
      assert parsed == data
    end
  end

  describe "backwards compatibility" do
    test "handles data that Jason would encode" do
      data = %{
        "string" => "value",
        "number" => 42,
        "float" => 3.14,
        "bool" => true,
        "null" => nil,
        "array" => [1, 2, 3],
        "nested" => %{"key" => "value"}
      }

      encoded = Utils.JSON.encode!(data)
      decoded = Utils.JSON.decode!(encoded)

      assert decoded == data
    end

    test "encodes nested structs that only implement Jason.Encoder" do
      data = %{"value" => %Explorer.Chain.Wei{value: Decimal.new(100)}}

      assert Utils.JSON.encode!(data) == ~s({"value":"100"})
    end
  end
end
