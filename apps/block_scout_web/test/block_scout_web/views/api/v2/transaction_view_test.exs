# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.TransactionViewTest do
  use BlockScoutWeb.ConnCase, async: true

  import ExUnit.CaptureLog

  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @tuple_input %{
    "components" => [
      %{"name" => "twitter", "type" => "string"},
      %{"name" => "telegram", "type" => "string"},
      %{"name" => "discord", "type" => "string"},
      %{"name" => "website", "type" => "string"},
      %{"name" => "farcaster", "type" => "string"}
    ],
    "name" => "socials_",
    "type" => "tuple"
  }
  @tuple_type "(string,string,string,string,string)"
  @tuple_value {"", "", "", "", ""}
  @tuple_json ["", "", "", "", ""]

  test "decodes a tuple value from transaction input and renders it without logging a warning" do
    function_abi = %{
      "inputs" => [@tuple_input],
      "name" => "launch",
      "outputs" => [],
      "type" => "function"
    }

    selector = ABI.FunctionSelector.parse_specification_item(function_abi)

    input =
      [@tuple_value]
      |> ABI.TypeEncoder.encode(selector)
      |> Base.encode16(case: :lower)

    smart_contract =
      :smart_contract
      |> insert(abi: [function_abi])
      |> Repo.preload(:address)

    transaction =
      :transaction
      |> insert(to_address: smart_contract.address, input: "0x" <> input)
      |> Repo.preload(to_address: :smart_contract)

    log =
      capture_log(fn ->
        assert [decoded_input] = Transaction.decode_transactions([transaction], true, api?: true)

        assert TransactionView.decoded_input(decoded_input) == %{
                 "method_id" => Base.encode16(selector.method_id, case: :lower),
                 "method_call" => "launch((string,string,string,string,string) socials_)",
                 "parameters" => [
                   %{"name" => "socials_", "type" => @tuple_type, "value" => @tuple_json}
                 ]
               }
      end)

    refute log =~ "Error determining value json"
  end

  test "decodes a tuple value from an event log and renders it without logging a warning" do
    event_input = Map.put(@tuple_input, "indexed", false)
    event_abi = %{"anonymous" => false, "inputs" => [event_input], "name" => "Launched", "type" => "event"}
    selector = ABI.FunctionSelector.parse_specification_item(event_abi)
    <<method_id::binary-size(4), _::binary>> = selector.method_id
    method_id_string = Base.encode16(method_id, case: :lower)

    data =
      [@tuple_value]
      |> ABI.TypeEncoder.encode(selector.types)
      |> Base.encode16(case: :lower)

    smart_contract =
      :smart_contract
      |> insert(abi: [event_abi])
      |> Repo.preload(:address)

    address =
      Repo.preload(smart_contract.address, [
        :names,
        :smart_contract,
        Implementation.proxy_implementations_smart_contracts_association()
      ])

    {:ok, log_data} = Explorer.Chain.Data.cast("0x" <> data)

    decoded_log =
      :log
      |> build(
        address: address,
        address_hash: address.hash,
        data: log_data,
        first_topic: topic("0x" <> Base.encode16(selector.method_id, case: :lower)),
        transaction_hash: build(:transaction).hash
      )
      |> List.wrap()
      |> TransactionView.decode_logs(false)
      |> List.first()

    captured_log =
      capture_log(fn ->
        assert {:ok, decoded_method_id, method_call, mapping} = decoded_log

        assert TransactionView.render("decoded_log_input.json", %{
                 method_id: decoded_method_id,
                 text: method_call,
                 mapping: mapping
               }) == %{
                 "method_id" => method_id_string,
                 "method_call" => "Launched((string,string,string,string,string) socials_)",
                 "parameters" => [
                   %{
                     "indexed" => false,
                     "name" => "socials_",
                     "type" => @tuple_type,
                     "value" => @tuple_json
                   }
                 ]
               }
      end)

    refute captured_log =~ "Error determining value json"
  end

  describe "decode_logs/2" do
    test "doesn't use decoding candidate event with different 2nd, 3d or 4th topic" do
      insert(:contract_method,
        identifier: Base.decode16!("d20a68b2", case: :lower),
        abi: %{
          "name" => "OptionSettled",
          "type" => "event",
          "inputs" => [
            %{"name" => "accountId", "type" => "uint256", "indexed" => true, "internalType" => "uint256"},
            %{"name" => "option", "type" => "address", "indexed" => false, "internalType" => "address"},
            %{"name" => "subId", "type" => "uint256", "indexed" => false, "internalType" => "uint256"},
            %{"name" => "amount", "type" => "int256", "indexed" => false, "internalType" => "int256"},
            %{"name" => "value", "type" => "int256", "indexed" => false, "internalType" => "int256"}
          ],
          "anonymous" => false
        }
      )

      topic1_bytes = ExKeccak.hash_256("OptionSettled(uint256,address,uint256,int256,int256)")
      topic1 = "0x" <> Base.encode16(topic1_bytes, case: :lower)
      log1_topic2 = "0x0000000000000000000000000000000000000000000000000000000000005d19"
      log2_topic2 = "0x000000000000000000000000000000000000000000000000000000000000634a"

      log1_data =
        "0x000000000000000000000000aeb81cbe6b19ceeb0dbe0d230cffe35bb40a13a700000000000000000000000000000000000000000000045d964b80006597b700fffffffffffffffffffffffffffffffffffffffffffffffffe55aca2c2f40000ffffffffffffffffffffffffffffffffffffffffffffffe3a8289da3d7a13ef2"

      log2_data =
        "0x000000000000000000000000aeb81cbe6b19ceeb0dbe0d230cffe35bb40a13a700000000000000000000000000000000000000000000045d964b80006597b700000000000000000000000000000000000000000000000000011227ebced227ae00000000000000000000000000000000000000000000001239fdf180a3d6bd85"

      transaction = insert(:transaction)

      log1 =
        insert(:log,
          transaction: transaction,
          first_topic: topic(topic1),
          second_topic: topic(log1_topic2),
          third_topic: nil,
          fourth_topic: nil,
          data: log1_data
        )

      log2 =
        insert(:log,
          transaction: transaction,
          first_topic: topic(topic1),
          second_topic: topic(log2_topic2),
          third_topic: nil,
          fourth_topic: nil,
          data: log2_data
        )

      logs =
        [log1, log2]
        |> Repo.preload(
          address: [:names, :smart_contract, Implementation.proxy_implementations_smart_contracts_association()]
        )

      assert [
               {:ok, "d20a68b2",
                "OptionSettled(uint256 indexed accountId, address option, uint256 subId, int256 amount, int256 value)",
                [
                  {"accountId", "uint256", true, 23833},
                  {"option", "address", false,
                   <<174, 184, 28, 190, 107, 25, 206, 235, 13, 190, 13, 35, 12, 255, 227, 91, 180, 10, 19, 167>>},
                  {"subId", "uint256", false, 20_615_843_020_801_704_441_600},
                  {"amount", "int256", false, -120_000_000_000_000_000},
                  {"value", "int256", false, -522_838_470_013_113_778_446}
                ]},
               {:ok, "d20a68b2",
                "OptionSettled(uint256 indexed accountId, address option, uint256 subId, int256 amount, int256 value)",
                [
                  {"accountId", "uint256", true, 25418},
                  {"option", "address", false,
                   <<174, 184, 28, 190, 107, 25, 206, 235, 13, 190, 13, 35, 12, 255, 227, 91, 180, 10, 19, 167>>},
                  {"subId", "uint256", false, 20_615_843_020_801_704_441_600},
                  {"amount", "int256", false, 77_168_037_359_396_782},
                  {"value", "int256", false, 336_220_154_890_848_484_741}
                ]}
             ] = TransactionView.decode_logs(logs, false)
    end

    test "properly decode logs if they have same topics" do
      insert(:contract_method,
        identifier: Base.decode16!("d20a68b2", case: :lower),
        abi: %{
          "name" => "OptionSettled",
          "type" => "event",
          "inputs" => [
            %{"name" => "accountId", "type" => "uint256", "indexed" => true, "internalType" => "uint256"},
            %{"name" => "option", "type" => "address", "indexed" => false, "internalType" => "address"},
            %{"name" => "subId", "type" => "uint256", "indexed" => false, "internalType" => "uint256"},
            %{"name" => "amount", "type" => "int256", "indexed" => false, "internalType" => "int256"},
            %{"name" => "value", "type" => "int256", "indexed" => false, "internalType" => "int256"}
          ],
          "anonymous" => false
        }
      )

      topic1_bytes = ExKeccak.hash_256("OptionSettled(uint256,address,uint256,int256,int256)")
      topic1 = "0x" <> Base.encode16(topic1_bytes, case: :lower)
      topic2 = "0x0000000000000000000000000000000000000000000000000000000000005d19"

      log1_data =
        "0x000000000000000000000000aeb81cbe6b19ceeb0dbe0d230cffe35bb40a13a700000000000000000000000000000000000000000000045d964b80006597b700fffffffffffffffffffffffffffffffffffffffffffffffffe55aca2c2f40000ffffffffffffffffffffffffffffffffffffffffffffffe3a8289da3d7a13ef2"

      log2_data =
        "0x000000000000000000000000aeb81cbe6b19ceeb0dbe0d230cffe35bb40a13a700000000000000000000000000000000000000000000045d964b80006597b700000000000000000000000000000000000000000000000000011227ebced227ae00000000000000000000000000000000000000000000001239fdf180a3d6bd85"

      transaction = insert(:transaction)

      log1 =
        insert(:log,
          transaction: transaction,
          first_topic: topic(topic1),
          second_topic: topic(topic2),
          third_topic: nil,
          fourth_topic: nil,
          data: log1_data
        )

      log2 =
        insert(:log,
          transaction: transaction,
          first_topic: topic(topic1),
          second_topic: topic(topic2),
          third_topic: nil,
          fourth_topic: nil,
          data: log2_data
        )

      logs =
        [log1, log2]
        |> Repo.preload(
          address: [:names, :smart_contract, Implementation.proxy_implementations_smart_contracts_association()]
        )

      assert [
               {:ok, "d20a68b2",
                "OptionSettled(uint256 indexed accountId, address option, uint256 subId, int256 amount, int256 value)",
                [
                  {"accountId", "uint256", true, 23833},
                  {"option", "address", false,
                   <<174, 184, 28, 190, 107, 25, 206, 235, 13, 190, 13, 35, 12, 255, 227, 91, 180, 10, 19, 167>>},
                  {"subId", "uint256", false, 20_615_843_020_801_704_441_600},
                  {"amount", "int256", false, -120_000_000_000_000_000},
                  {"value", "int256", false, -522_838_470_013_113_778_446}
                ]},
               {:ok, "d20a68b2",
                "OptionSettled(uint256 indexed accountId, address option, uint256 subId, int256 amount, int256 value)",
                [
                  {"accountId", "uint256", true, 23833},
                  {"option", "address", false,
                   <<174, 184, 28, 190, 107, 25, 206, 235, 13, 190, 13, 35, 12, 255, 227, 91, 180, 10, 19, 167>>},
                  {"subId", "uint256", false, 20_615_843_020_801_704_441_600},
                  {"amount", "int256", false, 77_168_037_359_396_782},
                  {"value", "int256", false, 336_220_154_890_848_484_741}
                ]}
             ] = TransactionView.decode_logs(logs, false)
    end
  end

  defp topic(topic_hex_string) do
    {:ok, topic} = Explorer.Chain.Hash.Full.cast(topic_hex_string)
    topic
  end
end
