defmodule Indexer.Fetcher.Stability.ValidatorTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Stability.Validator, as: ValidatorStability
  alias EthereumJSONRPC.Encoder

  setup :verify_on_exit!
  setup :set_mox_global

  @accepts_list_of_addresses %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "address[]", "name" => "", "internalType" => "address[]"}],
    "name" => "getActiveValidatorList",
    "inputs" => [%{"type" => "address[]", "name" => "", "internalType" => "address[]"}]
  }

  @accepts_integer %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [
      %{
        "internalType" => "uint256",
        "name" => "",
        "type" => "uint256"
      }
    ],
    "name" => "getActiveValidatorList",
    "inputs" => [
      %{
        "internalType" => "uint256",
        "name" => "",
        "type" => "uint256"
      }
    ]
  }

  if Application.compile_env(:explorer, :chain_type) == :stability do
    describe "check update_validators_list" do
      test "deletes absent validators" do
        _validator = insert(:validator_stability)
        _validator_active = insert(:validator_stability, state: :active)
        _validator_inactive = insert(:validator_stability, state: :inactive)
        _validator_probation = insert(:validator_stability, state: :probation)

        start_supervised!({Indexer.Fetcher.Stability.Validator, name: Indexer.Fetcher.Stability.Validator})

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, 1, fn
          [
            %{
              id: id_1,
              jsonrpc: "2.0",
              method: "eth_call",
              params: [%{data: "0xa5aa7380", to: "0x0000000000000000000000000000000000000805"}, "latest"]
            },
            %{
              id: id_2,
              jsonrpc: "2.0",
              method: "eth_call",
              params: [%{data: "0xe35c0f7d", to: "0x0000000000000000000000000000000000000805"}, "latest"]
            }
          ],
          _ ->
            <<"0x", _method_id::binary-size(8), result::binary>> =
              [@accepts_list_of_addresses]
              |> ABI.parse_specification()
              |> Enum.at(0)
              |> Encoder.encode_function_call([[]])

            {:ok,
             [
               %{
                 id: id_1,
                 jsonrpc: "2.0",
                 result: "0x" <> result
               },
               %{
                 id: id_2,
                 jsonrpc: "2.0",
                 result: "0x" <> result
               }
             ]}
        end)

        :timer.sleep(100)
        assert ValidatorStability.get_all_validators() == []
      end

      test "updates validators" do
        validator_active1 = insert(:validator_stability, state: :active)
        validator_active2 = insert(:validator_stability, state: :active)
        _validator_active3 = insert(:validator_stability, state: :active)

        validator_inactive1 = insert(:validator_stability, state: :inactive)
        validator_inactive2 = insert(:validator_stability, state: :inactive)
        _validator_inactive3 = insert(:validator_stability, state: :inactive)

        validator_probation1 = insert(:validator_stability, state: :probation)
        validator_probation2 = insert(:validator_stability, state: :probation)
        _validator_probation3 = insert(:validator_stability, state: :probation)

        start_supervised!({Indexer.Fetcher.Stability.Validator, name: Indexer.Fetcher.Stability.Validator})

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn
          [
            %{
              id: id_1,
              jsonrpc: "2.0",
              method: "eth_call",
              params: [%{data: "0xa5aa7380", to: "0x0000000000000000000000000000000000000805"}, "latest"]
            },
            %{
              id: id_2,
              jsonrpc: "2.0",
              method: "eth_call",
              params: [%{data: "0xe35c0f7d", to: "0x0000000000000000000000000000000000000805"}, "latest"]
            }
          ],
          _ ->
            <<"0x", _method_id::binary-size(8), result_all::binary>> =
              [@accepts_list_of_addresses]
              |> ABI.parse_specification()
              |> Enum.at(0)
              |> Encoder.encode_function_call([
                [
                  validator_active1.address_hash.bytes,
                  validator_active2.address_hash.bytes,
                  validator_inactive1.address_hash.bytes,
                  validator_inactive2.address_hash.bytes,
                  validator_probation1.address_hash.bytes,
                  validator_probation2.address_hash.bytes
                ]
              ])

            <<"0x", _method_id::binary-size(8), result_active::binary>> =
              [@accepts_list_of_addresses]
              |> ABI.parse_specification()
              |> Enum.at(0)
              |> Encoder.encode_function_call([
                [
                  validator_active1.address_hash.bytes,
                  validator_inactive1.address_hash.bytes,
                  validator_probation1.address_hash.bytes
                ]
              ])

            {:ok,
             [
               %{
                 id: id_1,
                 jsonrpc: "2.0",
                 result: "0x" <> result_active
               },
               %{
                 id: id_2,
                 jsonrpc: "2.0",
                 result: "0x" <> result_all
               }
             ]}
        end)

        "0x" <> address_1 = to_string(validator_active1.address_hash)
        "0x" <> address_2 = to_string(validator_inactive1.address_hash)
        "0x" <> address_3 = to_string(validator_probation1.address_hash)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn
          [
            %{
              id: id_1,
              jsonrpc: "2.0",
              method: "eth_call",
              params: [
                %{
                  data: "0x41ee9a53000000000000000000000000" <> ^address_1,
                  to: "0x0000000000000000000000000000000000000805"
                },
                "latest"
              ]
            },
            %{
              id: id_2,
              jsonrpc: "2.0",
              method: "eth_call",
              params: [
                %{
                  data: "0x41ee9a53000000000000000000000000" <> ^address_2,
                  to: "0x0000000000000000000000000000000000000805"
                },
                "latest"
              ]
            },
            %{
              id: id_3,
              jsonrpc: "2.0",
              method: "eth_call",
              params: [
                %{
                  data: "0x41ee9a53000000000000000000000000" <> ^address_3,
                  to: "0x0000000000000000000000000000000000000805"
                },
                "latest"
              ]
            }
          ],
          _ ->
            <<"0x", _method_id::binary-size(8), result_1::binary>> =
              [@accepts_integer]
              |> ABI.parse_specification()
              |> Enum.at(0)
              |> Encoder.encode_function_call([10])

            <<"0x", _method_id::binary-size(8), result_2::binary>> =
              [@accepts_integer]
              |> ABI.parse_specification()
              |> Enum.at(0)
              |> Encoder.encode_function_call([1])

            <<"0x", _method_id::binary-size(8), result_3::binary>> =
              [@accepts_integer]
              |> ABI.parse_specification()
              |> Enum.at(0)
              |> Encoder.encode_function_call([0])

            {:ok,
             [
               %{
                 id: id_1,
                 jsonrpc: "2.0",
                 result: "0x" <> result_1
               },
               %{
                 id: id_2,
                 jsonrpc: "2.0",
                 result: "0x" <> result_2
               },
               %{
                 id: id_3,
                 jsonrpc: "2.0",
                 result: "0x" <> result_3
               }
             ]}
        end)

        :timer.sleep(100)
        validators = ValidatorStability.get_all_validators()

        assert Enum.count(validators) == 6

        map =
          Enum.reduce(validators, %{}, fn validator, map -> Map.put(map, validator.address_hash.bytes, validator) end)

        assert %ValidatorStability{state: :inactive} = map[validator_active2.address_hash.bytes]
        assert %ValidatorStability{state: :inactive} = map[validator_inactive2.address_hash.bytes]
        assert %ValidatorStability{state: :inactive} = map[validator_probation2.address_hash.bytes]

        assert %ValidatorStability{state: :probation} = map[validator_active1.address_hash.bytes]
        assert %ValidatorStability{state: :probation} = map[validator_inactive1.address_hash.bytes]
        assert %ValidatorStability{state: :active} = map[validator_probation1.address_hash.bytes]
      end
    end
  end
end
