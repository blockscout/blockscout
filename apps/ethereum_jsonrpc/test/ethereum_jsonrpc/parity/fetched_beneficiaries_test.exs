defmodule EthereumJSONRPC.Nethermind.FetchedBeneficiariesTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC
  alias EthereumJSONRPC.Nethermind.FetchedBeneficiaries

  describe "from_responses/2" do
    test "when block is not found" do
      block_quantity = EthereumJSONRPC.integer_to_quantity(1_000)
      responses = [%{id: 0, result: nil}]
      id_to_params = %{0 => %{block_quantity: block_quantity}}

      expected_output = %EthereumJSONRPC.FetchedBeneficiaries{
        errors: [%{code: 404, data: %{block_quantity: block_quantity}, message: "Not Found"}],
        params_set: MapSet.new([])
      }

      assert FetchedBeneficiaries.from_responses(responses, id_to_params) == expected_output
    end

    test "with an error result" do
      block_number = 1_000
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      error_code = -32603
      error_message = "Internal error occurred: {}, this should not be the case with eth_call, most likely a bug."

      responses = [%{id: 0, error: %{code: error_code, message: error_message}}]

      id_to_params = %{0 => %{block_quantity: block_quantity}}

      expected_output = %EthereumJSONRPC.FetchedBeneficiaries{
        errors: [%{code: error_code, data: %{block_quantity: block_quantity}, message: error_message}],
        params_set: MapSet.new()
      }

      assert FetchedBeneficiaries.from_responses(responses, id_to_params) == expected_output
    end

    test "when reward type is external" do
      block_hash = "0x52a8d2185282506ce681364d2aa0c085ba45fdeb5d6c0ddec1131617a71ee2ca"
      block_number = 1_000
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      hash1 = "0xef481b4e2c3ed62265617f2e9dfcdf3cf3efc11a"
      hash2 = "0xef481b4e2c3ed62265617f2e9dfcdf3cf3efc11a"
      reward = "0xde0b6b3a7640000"

      responses = [
        %{
          id: 0,
          result: [
            %{
              "action" => %{"author" => hash1, "rewardType" => "external", "value" => reward},
              "blockHash" => block_hash,
              "blockNumber" => block_number,
              "result" => nil,
              "subtraces" => 0,
              "traceAddress" => [],
              "transactionHash" => nil,
              "transactionPosition" => nil,
              "type" => "reward"
            },
            %{
              "action" => %{"author" => hash2, "rewardType" => "external", "value" => reward},
              "blockHash" => "0x52a8d2185282506ce681364d2aa0c085ba45fdeb5d6c0ddec1131617a71ee2ca",
              "blockNumber" => block_number,
              "result" => nil,
              "subtraces" => 0,
              "traceAddress" => [],
              "transactionHash" => nil,
              "transactionPosition" => nil,
              "type" => "reward"
            }
          ]
        }
      ]

      id_to_params = %{0 => %{block_quantity: block_quantity}}

      expected_output = %EthereumJSONRPC.FetchedBeneficiaries{
        errors: [],
        params_set:
          MapSet.new([
            %{
              address_hash: hash1,
              address_type: :validator,
              block_hash: block_hash,
              block_number: block_number,
              reward: reward
            },
            %{
              address_hash: hash2,
              address_type: :emission_funds,
              block_hash: block_hash,
              block_number: block_number,
              reward: reward
            }
          ])
      }

      assert FetchedBeneficiaries.from_responses(responses, id_to_params) == expected_output
    end

    test "when reward type is block with uncles" do
      block_hash = "0x52a8d2185282506ce681364d2aa0c085ba45fdeb5d6c0ddec1131617a71ee2ca"
      block_number = 1_000
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      hash1 = "0xef481b4e2c3ed62265617f2e9dfcdf3cf3efc11a"
      hash2 = "0x523b6539ff08d72a6c8bb598af95bf50c1ea839c"
      reward = "0xde0b6b3a7640000"

      responses = [
        %{
          id: 0,
          result: [
            %{
              "action" => %{"author" => hash1, "rewardType" => "block", "value" => reward},
              "blockHash" => block_hash,
              "blockNumber" => block_number,
              "result" => nil,
              "subtraces" => 0,
              "traceAddress" => [],
              "transactionHash" => nil,
              "transactionPosition" => nil,
              "type" => "reward"
            },
            %{
              "action" => %{"author" => hash2, "rewardType" => "uncle", "value" => reward},
              "blockHash" => block_hash,
              "blockNumber" => block_number,
              "result" => nil,
              "subtraces" => 0,
              "traceAddress" => [],
              "transactionHash" => nil,
              "transactionPosition" => nil,
              "type" => "reward"
            }
          ]
        }
      ]

      id_to_params = %{0 => %{block_quantity: block_quantity}}

      expected_output = %EthereumJSONRPC.FetchedBeneficiaries{
        errors: [],
        params_set:
          MapSet.new([
            %{
              address_hash: hash1,
              address_type: :validator,
              block_hash: block_hash,
              block_number: block_number,
              reward: reward
            },
            %{
              address_hash: hash2,
              address_type: :uncle,
              block_hash: block_hash,
              block_number: block_number,
              reward: reward
            }
          ])
      }

      assert FetchedBeneficiaries.from_responses(responses, id_to_params) == expected_output
    end

    test "ignores non-reward responses" do
      block_hash = "0x52a8d2185282506ce681364d2aa0c085ba45fdeb5d6c0ddec1131617a71ee2ca"
      block_number = 1_000
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      hash1 = "0xef481b4e2c3ed62265617f2e9dfcdf3cf3efc11a"
      hash2 = "0x523b6539ff08d72a6c8bb598af95bf50c1ea839c"
      reward = "0xde0b6b3a7640000"

      responses = [
        %{
          id: 0,
          result: [
            %{
              "action" => %{
                "callType" => "call",
                "from" => hash1,
                "gas" => "0x0",
                "input" => "0x",
                "to" => hash2,
                "value" => "0x4a817c800"
              },
              "blockHash" => block_hash,
              "blockNumber" => block_number,
              "result" => %{"gasUsed" => "0x0", "output" => "0x"},
              "subtraces" => 0,
              "traceAddress" => [],
              "transactionHash" => "0x5acf90f846b8216bdbc309cf4eb24adc69d730bf29304dc0e740cf6df850666e",
              "transactionPosition" => 0,
              "type" => "call"
            },
            %{
              "action" => %{"author" => hash1, "rewardType" => "block", "value" => reward},
              "blockHash" => block_hash,
              "blockNumber" => block_number,
              "result" => nil,
              "subtraces" => 0,
              "traceAddress" => [],
              "transactionHash" => nil,
              "transactionPosition" => nil,
              "type" => "reward"
            }
          ]
        }
      ]

      id_to_params = %{0 => %{block_quantity: block_quantity}}

      expected_output = %EthereumJSONRPC.FetchedBeneficiaries{
        errors: [],
        params_set:
          MapSet.new([
            %{
              address_hash: hash1,
              address_type: :validator,
              block_hash: block_hash,
              block_number: block_number,
              reward: reward
            }
          ])
      }

      assert FetchedBeneficiaries.from_responses(responses, id_to_params) == expected_output
    end
  end

  describe "requests/1" do
    test "maps multiple ids to request params map" do
      input = %{
        0 => %{block_quantity: EthereumJSONRPC.integer_to_quantity(1)},
        1 => %{block_quantity: EthereumJSONRPC.integer_to_quantity(2)}
      }

      expected_output = [
        %{id: 0, jsonrpc: "2.0", method: "trace_block", params: [EthereumJSONRPC.integer_to_quantity(1)]},
        %{id: 1, jsonrpc: "2.0", method: "trace_block", params: [EthereumJSONRPC.integer_to_quantity(2)]}
      ]

      assert FetchedBeneficiaries.requests(input) == expected_output
    end

    test "skips Genesis block" do
      input = %{
        0 => %{block_quantity: EthereumJSONRPC.integer_to_quantity(0)},
        1 => %{block_quantity: EthereumJSONRPC.integer_to_quantity(1)}
      }

      expected_output = [
        %{id: 1, jsonrpc: "2.0", method: "trace_block", params: [EthereumJSONRPC.integer_to_quantity(1)]}
      ]

      assert FetchedBeneficiaries.requests(input) == expected_output
    end
  end
end
