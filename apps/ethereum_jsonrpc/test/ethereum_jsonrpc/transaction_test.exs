defmodule EthereumJSONRPC.TransactionTest do
  use ExUnit.Case, async: true

  doctest EthereumJSONRPC.Transaction

  alias EthereumJSONRPC.Transaction

  describe "to_elixir/1" do
    test "skips unsupported keys" do
      map = %{"key" => "value", "key1" => "value1"}

      assert %{nil: nil} = Transaction.to_elixir(map)
    end
  end

  # takes decoded json and converts + normalises to params map
  describe "elixir_to_params/1" do
    test "transforms legacy transaction without type" do
      transaction_json = ~S"""
      {
            "blockHash": "0x13e5fee5b2c16ceb7ca24f8821bdadfd56c60c439cba05d3877d2df86e35b9f2",
            "blockNumber": "0x9ea5fd",
            "ethCompatible": true,
            "feeCurrency": null,
            "from": "0xcf3b8258b589ac6bdf3add067eedb681c3990d72",
            "gas": "0xc37d5",
            "gasPrice": "0x20c85580",
            "gatewayFee": "0x1",
            "gatewayFeeRecipient": "0xbabababababa",
            "hash": "0xaf717775f61b3da57d57cde57d19277fbc97b8f74327e158109dd2723cbd587f",
            "input": "0x45cc0a2f00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000432380000000000000000000000000000000000000000000000000000000061b9c26000000000000000000000000000000000000000000000000000000000000000084d414b455244414f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000054554482d41000000000000000000000000000000000000000000000000000000",
            "nonce": "0x66b75",
            "r": "0x39d6e222c2a4083a56e59429064d397a8464448059d8f3cc958366f739b3f393",
            "s": "0x520073d1101f3ccfbe3dcb799d5d7b3bbfba8abba4295946c59407f89cbaaf03",
            "to": "0xcd8e18890e416aa7ab09aa793b406c187747c687",
            "transactionIndex": "0x0",
            "v": "0x149fb",
            "value": "0x0"
      }
      """

      result =
        transaction_json
        |> Jason.decode!()
        |> Transaction.elixir_to_params()

      assert result.gas == "0xc37d5"
      assert result.block_hash == "0x13e5fee5b2c16ceb7ca24f8821bdadfd56c60c439cba05d3877d2df86e35b9f2"
      assert result.gas_fee_recipient_hash == "0xbabababababa"
      assert result.gateway_fee == "0x1"
    end

    test "transforms legacy transaction with type" do
      transaction_json = ~S"""
        {
              "blockHash": "0x98d3e9b236730c9a563b0940fe57cfc31ba040d997b0b4b2b015cda4991b6473",
              "blockNumber": "0x8c21a3",
              "ethCompatible": false,
              "feeCurrency": "0x62492a644a588fd904270bed06ad52b9abfea1ae",
              "from": "0x6c3ac5fcb13e8dcd908c405ec6dacf0ef575d8fc",
              "gas": "0x1e971",
              "gasPrice": "0x28f29fbe",
              "gatewayFee": "0x1",
              "gatewayFeeRecipient": "0xbabababababa",
              "hash": "0xe8196cadced0e005add1490fd1ed041b41c9e33fc4afc76fa0dabacfccc06374",
              "input": "0xa9059cbb000000000000000000000000f19ef729c9328854e39fb7d4c58e48aedb6a7b970000000000000000000000000000000000000000000000000000000000002710",
              "nonce": "0x3d530",
              "r": "0x9698f4c225ba151471433cf06c5625c82650f41a662d27cbb15ea1c87bc205aa",
              "s": "0x27f7d6c64410af88291609c7170784110367042fd59511765a37b4450065b03b",
              "to": "0xddc9be57f553fe75752d61606b94cbd7e0264ef8",
              "transactionIndex": "0x9",
              "type": "0x0",
              "v": "0x1e704",
              "value": "0x0"
          }
      """

      result =
        transaction_json
        |> Jason.decode!()
        |> Transaction.elixir_to_params()

      assert result.gas == "0x1e971"
      assert result.block_hash == "0x98d3e9b236730c9a563b0940fe57cfc31ba040d997b0b4b2b015cda4991b6473"
      assert result.gas_fee_recipient_hash == "0xbabababababa"
      assert result.gateway_fee == "0x1"
      assert result.value == "0x0"
      assert result.type == "0x0"
    end

    test "transforms dynamic fee transaction with type" do
      transaction_json = ~S"""
      {
        "accessList": [],
        "blockHash": "0x26b90e879b1d4b63e3b33bcfebad5c59511e3249e93fef1dc05e98b0016075fb",
        "blockNumber": 19,
        "chainId": "0x8ad6f8",
        "ethCompatible": false,
        "feeCurrency": null,
        "from": "0xa5ca67fe05ee3f07961f59a73a0e75732fbae592",
        "gas": 59309,
        "gasPrice": 2100000000,
        "gatewayFee": "0x7",
        "gatewayFeeRecipient": "0xbababbbb",
        "hash": "0xd87938ea8839f7e418c64579d59c2e0f727af6ec338f19cd5a874755792c01a6",
        "input": "0xa9059cbb000000000000000000000000a5ca67fe05ee3f07961f59a73a0e75732fbae59200000000000000000000000000000000000000000000000000000000000003e8",
        "maxFeePerGas": 2200000000,
        "maxPriorityFeePerGas": 2000000000,
        "nonce": 0,
        "r": "0x36c2328311f7515fb648bb80b9a043a64f7e8f5a6a9c360f0ef65151c62c0ead",
        "s": "0x362fbcb94d11b748e4b06acabd44be50ff8055a43498e87bc078ede49109c809",
        "to": "0x000000000000000000000000000000000000d008",
        "transactionIndex": 0,
        "type": "0x2",
        "v": "0x1",
        "value": 0
      }
      """

      result =
        transaction_json
        |> Jason.decode!()
        |> Transaction.elixir_to_params()

      assert result.type == "0x2"
      assert result.max_fee_per_gas == 2_200_000_000
      assert result.max_priority_fee_per_gas == 2_000_000_000
      assert result.gas_fee_recipient_hash == "0xbababbbb"
      assert result.gateway_fee == "0x7"
    end

    test "transforms celo transaction with type" do
      transaction_json = ~S"""
      {
        "blockHash": "0x30f5b6fc4236a3b0cdc09fde43a9a70df9d59cb355806476e3801d2b449dd590",
        "blockNumber": 7635,
        "ethCompatible": false,
        "feeCurrency": "0x000000000000000000000000000000000000d008",
        "from": "0xa5ca67fe05ee3f07961f59a73a0e75732fbae592",
        "gas": 71000,
        "gasPrice": 2200000000,
        "gatewayFee": "0x9",
        "gatewayFeeRecipient": "0xcafebabe",
        "hash": "0x864a4a2e99a846a8bb6a79c31676eae4fbbe3f5e90c50b961e53e1d456864aff",
        "input": "0x",
        "nonce": 17,
        "r": "0x58c544eb80a5573cfeab40c1c187c743a65f78087b80399dc8955e3639c29b37",
        "s": "0x4f8db109a6518b591718eea4905f625596e36b5985d73815285e9a0f52acab5b",
        "to": "0xa5ca67fe05ee3f07961f59a73a0e75732fbae592",
        "transactionIndex": 0,
        "type": "0x7c",
        "v": "0x1",
        "value": 1000
      }
      """

      result =
        transaction_json
        |> Jason.decode!()
        |> Transaction.elixir_to_params()

      assert result.type == "0x7c"
      assert result.gas_fee_recipient_hash == "0xcafebabe"
      assert result.gateway_fee == "0x9"
      assert result.value == 1000
    end

    test "transforms celo transaction with type and optional max fee fields" do
      transaction_json = ~S"""
      {
        "blockHash": "0x30f5b6fc4236a3b0cdc09fde43a9a70df9d59cb355806476e3801d2b449dd590",
        "blockNumber": 7635,
        "ethCompatible": false,
        "feeCurrency": "0x000000000000000000000000000000000000d008",
        "from": "0xa5ca67fe05ee3f07961f59a73a0e75732fbae592",
        "gas": 71000,
        "gasPrice": 2200000000,
        "gatewayFee": "0x9",
        "gatewayFeeRecipient": "0xcafebabe",
        "hash": "0x864a4a2e99a846a8bb6a79c31676eae4fbbe3f5e90c50b961e53e1d456864aff",
        "input": "0x",
        "maxFeePerGas": 7777777,
        "maxPriorityFeePerGas": 666666,
        "nonce": 17,
        "r": "0x58c544eb80a5573cfeab40c1c187c743a65f78087b80399dc8955e3639c29b37",
        "s": "0x4f8db109a6518b591718eea4905f625596e36b5985d73815285e9a0f52acab5b",
        "to": "0xa5ca67fe05ee3f07961f59a73a0e75732fbae592",
        "transactionIndex": 0,
        "type": "0x7c",
        "v": "0x1",
        "value": 1000
      }
      """

      result =
        transaction_json
        |> Jason.decode!()
        |> Transaction.elixir_to_params()

      assert result.type == "0x7c"
      assert result.gas_fee_recipient_hash == "0xcafebabe"
      assert result.gateway_fee == "0x9"
      assert result.value == 1000
      assert result.max_fee_per_gas == 7_777_777
      assert result.max_priority_fee_per_gas == 666_666
    end

    # https://github.com/celo-org/data-services/issues/724
    test "handles 0x7b transaction type" do
      transaction_json = ~S"""
      {
        "blockHash": "0x1f07e34685a3b970ef9c71272f3945418794b991adedbc962de39332d229ef97",
        "blockNumber": "0x1245938",
        "from": "0x0cc59ed03b3e763c02d54d695ffe353055f1502d",
        "gas": "0x1688c",
        "gasPrice": 77777,
        "maxFeePerGas": "0x362b7669",
        "maxPriorityFeePerGas": "0x313ec8bd",
        "feeCurrency": "0x62492a644a588fd904270bed06ad52b9abfea1ae",
        "gatewayFeeRecipient": null,
        "gatewayFee": "0x0",
        "hash": "0x2e003d340a2a83c7daf11d951fa525d6e76b0eac5b53c787be1f86d18443ba36",
        "input": "0x",
        "nonce": "0x505",
        "to": "0x325f890e573880311cfbadfe8ec3d51ffdd97a76",
        "transactionIndex": "0x0",
        "value": "0x38d7ea4c68000",
        "type": "0x7b",
        "accessList": [],
        "chainId": "0xf370",
        "v": "0x1",
        "r": "0x22b6471286077b287235600964542af771b00cbc1829633207d6d316ebfb391e",
        "s": "0x3310de0fe2cc0ee3f516e075f077f657f87f89aeb23321ed774f8754b0f33554",
        "ethCompatible": false
      }
      """

      result =
        transaction_json
        |> Jason.decode!()
        |> Transaction.elixir_to_params()

      assert result.gas_price == 77777
    end
  end
end
