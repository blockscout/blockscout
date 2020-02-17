defmodule EthereumJSONRPC.ParityTest do
  use ExUnit.Case, async: true
  use EthereumJSONRPC.Case

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Mox

  alias EthereumJSONRPC.FetchedBeneficiaries
  alias Explorer.Chain
  alias Explorer.Chain.Data
  alias Explorer.Chain.InternalTransaction.Type

  setup :verify_on_exit!

  doctest EthereumJSONRPC.Parity

  @moduletag :no_geth

  describe "fetch_internal_transactions/1" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      EthereumJSONRPC.Parity.fetch_internal_transactions([], json_rpc_named_arguments)
    end
  end

  describe "fetch_block_internal_transactions/1" do
    test "with all valid block_numbers returns {:ok, transactions_params}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      gas = 4_533_872

      init =
        "0x6060604052341561000f57600080fd5b60405160208061071a83398101604052808051906020019091905050806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506003600160006001600281111561007e57fe5b60ff1660ff168152602001908152602001600020819055506002600160006002808111156100a857fe5b60ff1660ff168152602001908152602001600020819055505061064a806100d06000396000f30060606040526004361061008e576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff168063247b3210146100935780632ffdfc8a146100bc57806374294144146100f6578063ae4b1b5b14610125578063bf7370d11461017a578063d1104cb2146101a3578063eecd1079146101f8578063fcff021c14610221575b600080fd5b341561009e57600080fd5b6100a661024a565b6040518082815260200191505060405180910390f35b34156100c757600080fd5b6100e0600480803560ff16906020019091905050610253565b6040518082815260200191505060405180910390f35b341561010157600080fd5b610123600480803590602001909190803560ff16906020019091905050610276565b005b341561013057600080fd5b61013861037a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561018557600080fd5b61018d61039f565b6040518082815260200191505060405180910390f35b34156101ae57600080fd5b6101b66104d9565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561020357600080fd5b61020b610588565b6040518082815260200191505060405180910390f35b341561022c57600080fd5b6102346105bd565b6040518082815260200191505060405180910390f35b600060c8905090565b6000600160008360ff1660ff168152602001908152602001600020549050919050565b61027e6104d9565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415156102b757600080fd5b60008160ff161115156102c957600080fd5b6002808111156102d557fe5b60ff168160ff16111515156102e957600080fd5b6000821180156103125750600160008260ff1660ff168152602001908152602001600020548214155b151561031d57600080fd5b81600160008360ff1660ff168152602001908152602001600020819055508060ff167fe868bbbdd6cd2efcd9ba6e0129d43c349b0645524aba13f8a43bfc7c5ffb0889836040518082815260200191505060405180910390a25050565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000806000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16638b8414c46000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561042f57600080fd5b6102c65a03f1151561044057600080fd5b5050506040518051905090508073ffffffffffffffffffffffffffffffffffffffff16630eaba26a6000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b15156104b857600080fd5b6102c65a03f115156104c957600080fd5b5050506040518051905091505090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a3b3fff16000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561056857600080fd5b6102c65a03f1151561057957600080fd5b50505060405180519050905090565b60006105b860016105aa600261059c61039f565b6105e590919063ffffffff16565b61060090919063ffffffff16565b905090565b60006105e06105ca61039f565b6105d261024a565b6105e590919063ffffffff16565b905090565b60008082848115156105f357fe5b0490508091505092915050565b600080828401905083811015151561061457fe5b80915050929150505600a165627a7a723058206b7eef2a57eb659d5e77e45ab5bc074e99c6a841921038cdb931e119c6aac46c0029000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef"

      value = 0
      block_number = 39
      index = 0
      created_contract_address_hash = "0x1e0eaa06d02f965be2dfe0bc9ff52b2d82133461"

      created_contract_code =
        "0x60606040526004361061008e576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff168063247b3210146100935780632ffdfc8a146100bc57806374294144146100f6578063ae4b1b5b14610125578063bf7370d11461017a578063d1104cb2146101a3578063eecd1079146101f8578063fcff021c14610221575b600080fd5b341561009e57600080fd5b6100a661024a565b6040518082815260200191505060405180910390f35b34156100c757600080fd5b6100e0600480803560ff16906020019091905050610253565b6040518082815260200191505060405180910390f35b341561010157600080fd5b610123600480803590602001909190803560ff16906020019091905050610276565b005b341561013057600080fd5b61013861037a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561018557600080fd5b61018d61039f565b6040518082815260200191505060405180910390f35b34156101ae57600080fd5b6101b66104d9565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561020357600080fd5b61020b610588565b6040518082815260200191505060405180910390f35b341561022c57600080fd5b6102346105bd565b6040518082815260200191505060405180910390f35b600060c8905090565b6000600160008360ff1660ff168152602001908152602001600020549050919050565b61027e6104d9565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415156102b757600080fd5b60008160ff161115156102c957600080fd5b6002808111156102d557fe5b60ff168160ff16111515156102e957600080fd5b6000821180156103125750600160008260ff1660ff168152602001908152602001600020548214155b151561031d57600080fd5b81600160008360ff1660ff168152602001908152602001600020819055508060ff167fe868bbbdd6cd2efcd9ba6e0129d43c349b0645524aba13f8a43bfc7c5ffb0889836040518082815260200191505060405180910390a25050565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000806000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16638b8414c46000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561042f57600080fd5b6102c65a03f1151561044057600080fd5b5050506040518051905090508073ffffffffffffffffffffffffffffffffffffffff16630eaba26a6000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b15156104b857600080fd5b6102c65a03f115156104c957600080fd5b5050506040518051905091505090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a3b3fff16000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561056857600080fd5b6102c65a03f1151561057957600080fd5b50505060405180519050905090565b60006105b860016105aa600261059c61039f565b6105e590919063ffffffff16565b61060090919063ffffffff16565b905090565b60006105e06105ca61039f565b6105d261024a565b6105e590919063ffffffff16565b905090565b60008082848115156105f357fe5b0490508091505092915050565b600080828401905083811015151561061457fe5b80915050929150505600a165627a7a723058206b7eef2a57eb659d5e77e45ab5bc074e99c6a841921038cdb931e119c6aac46c0029"

      gas_used = 382_953
      trace_address = []
      transaction_hash = "0x0fa6f723216dba694337f9bb37d8870725655bdf2573526a39454685659e39b1"
      transaction_index = 0
      type = "create"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               result: [
                 %{
                   "trace" => [
                     %{
                       "action" => %{
                         "from" => from_address_hash,
                         "gas" => integer_to_quantity(gas),
                         "init" => init,
                         "value" => integer_to_quantity(value)
                       },
                       "blockNumber" => block_number,
                       "index" => index,
                       "result" => %{
                         "address" => created_contract_address_hash,
                         "code" => created_contract_code,
                         "gasUsed" => integer_to_quantity(gas_used)
                       },
                       "traceAddress" => trace_address,
                       "type" => type
                     }
                   ],
                   "transactionHash" => transaction_hash
                 }
               ]
             }
           ]}
        end)
      end

      assert EthereumJSONRPC.Parity.fetch_block_internal_transactions(
               [block_number],
               json_rpc_named_arguments
             ) == {
               :ok,
               [
                 %{
                   block_number: block_number,
                   created_contract_address_hash: created_contract_address_hash,
                   created_contract_code: created_contract_code,
                   from_address_hash: from_address_hash,
                   gas: gas,
                   gas_used: gas_used,
                   index: index,
                   init: init,
                   trace_address: trace_address,
                   transaction_hash: transaction_hash,
                   type: type,
                   value: value,
                   transaction_index: transaction_index
                 }
               ]
             }
    end
  end

  describe "fetch_first_trace/1" do
    test "with all valid block_numbers returns {:ok, first_trace_params}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      gas = 4_533_872

      init =
        "0x6060604052341561000f57600080fd5b60405160208061071a83398101604052808051906020019091905050806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506003600160006001600281111561007e57fe5b60ff1660ff168152602001908152602001600020819055506002600160006002808111156100a857fe5b60ff1660ff168152602001908152602001600020819055505061064a806100d06000396000f30060606040526004361061008e576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff168063247b3210146100935780632ffdfc8a146100bc57806374294144146100f6578063ae4b1b5b14610125578063bf7370d11461017a578063d1104cb2146101a3578063eecd1079146101f8578063fcff021c14610221575b600080fd5b341561009e57600080fd5b6100a661024a565b6040518082815260200191505060405180910390f35b34156100c757600080fd5b6100e0600480803560ff16906020019091905050610253565b6040518082815260200191505060405180910390f35b341561010157600080fd5b610123600480803590602001909190803560ff16906020019091905050610276565b005b341561013057600080fd5b61013861037a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561018557600080fd5b61018d61039f565b6040518082815260200191505060405180910390f35b34156101ae57600080fd5b6101b66104d9565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561020357600080fd5b61020b610588565b6040518082815260200191505060405180910390f35b341561022c57600080fd5b6102346105bd565b6040518082815260200191505060405180910390f35b600060c8905090565b6000600160008360ff1660ff168152602001908152602001600020549050919050565b61027e6104d9565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415156102b757600080fd5b60008160ff161115156102c957600080fd5b6002808111156102d557fe5b60ff168160ff16111515156102e957600080fd5b6000821180156103125750600160008260ff1660ff168152602001908152602001600020548214155b151561031d57600080fd5b81600160008360ff1660ff168152602001908152602001600020819055508060ff167fe868bbbdd6cd2efcd9ba6e0129d43c349b0645524aba13f8a43bfc7c5ffb0889836040518082815260200191505060405180910390a25050565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000806000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16638b8414c46000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561042f57600080fd5b6102c65a03f1151561044057600080fd5b5050506040518051905090508073ffffffffffffffffffffffffffffffffffffffff16630eaba26a6000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b15156104b857600080fd5b6102c65a03f115156104c957600080fd5b5050506040518051905091505090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a3b3fff16000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561056857600080fd5b6102c65a03f1151561057957600080fd5b50505060405180519050905090565b60006105b860016105aa600261059c61039f565b6105e590919063ffffffff16565b61060090919063ffffffff16565b905090565b60006105e06105ca61039f565b6105d261024a565b6105e590919063ffffffff16565b905090565b60008082848115156105f357fe5b0490508091505092915050565b600080828401905083811015151561061457fe5b80915050929150505600a165627a7a723058206b7eef2a57eb659d5e77e45ab5bc074e99c6a841921038cdb931e119c6aac46c0029000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef"

      value = 0
      block_number = 39
      block_hash = "0x74c72ccabcb98b7ebbd7b31de938212b7e8814a002263b6569564e944d88f51f"
      index = 0
      created_contract_address_hash = "0x1e0eaa06d02f965be2dfe0bc9ff52b2d82133461"

      created_contract_code =
        "0x60606040526004361061008e576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff168063247b3210146100935780632ffdfc8a146100bc57806374294144146100f6578063ae4b1b5b14610125578063bf7370d11461017a578063d1104cb2146101a3578063eecd1079146101f8578063fcff021c14610221575b600080fd5b341561009e57600080fd5b6100a661024a565b6040518082815260200191505060405180910390f35b34156100c757600080fd5b6100e0600480803560ff16906020019091905050610253565b6040518082815260200191505060405180910390f35b341561010157600080fd5b610123600480803590602001909190803560ff16906020019091905050610276565b005b341561013057600080fd5b61013861037a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561018557600080fd5b61018d61039f565b6040518082815260200191505060405180910390f35b34156101ae57600080fd5b6101b66104d9565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561020357600080fd5b61020b610588565b6040518082815260200191505060405180910390f35b341561022c57600080fd5b6102346105bd565b6040518082815260200191505060405180910390f35b600060c8905090565b6000600160008360ff1660ff168152602001908152602001600020549050919050565b61027e6104d9565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415156102b757600080fd5b60008160ff161115156102c957600080fd5b6002808111156102d557fe5b60ff168160ff16111515156102e957600080fd5b6000821180156103125750600160008260ff1660ff168152602001908152602001600020548214155b151561031d57600080fd5b81600160008360ff1660ff168152602001908152602001600020819055508060ff167fe868bbbdd6cd2efcd9ba6e0129d43c349b0645524aba13f8a43bfc7c5ffb0889836040518082815260200191505060405180910390a25050565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000806000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16638b8414c46000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561042f57600080fd5b6102c65a03f1151561044057600080fd5b5050506040518051905090508073ffffffffffffffffffffffffffffffffffffffff16630eaba26a6000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b15156104b857600080fd5b6102c65a03f115156104c957600080fd5b5050506040518051905091505090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a3b3fff16000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561056857600080fd5b6102c65a03f1151561057957600080fd5b50505060405180519050905090565b60006105b860016105aa600261059c61039f565b6105e590919063ffffffff16565b61060090919063ffffffff16565b905090565b60006105e06105ca61039f565b6105d261024a565b6105e590919063ffffffff16565b905090565b60008082848115156105f357fe5b0490508091505092915050565b600080828401905083811015151561061457fe5b80915050929150505600a165627a7a723058206b7eef2a57eb659d5e77e45ab5bc074e99c6a841921038cdb931e119c6aac46c0029"

      gas_used = 382_953
      trace_address = []
      transaction_hash = "0x0fa6f723216dba694337f9bb37d8870725655bdf2573526a39454685659e39b1"
      transaction_index = 0
      type = "create"
      call_type = "create"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               result: %{
                 "output" => "0x",
                 "stateDiff" => nil,
                 "trace" => [
                   %{
                     "action" => %{
                       "from" => from_address_hash,
                       "gas" => integer_to_quantity(gas),
                       "init" => init,
                       "value" => integer_to_quantity(value)
                     },
                     "blockNumber" => block_number,
                     "index" => index,
                     "result" => %{
                       "address" => created_contract_address_hash,
                       "code" => created_contract_code,
                       "gasUsed" => integer_to_quantity(gas_used)
                     },
                     "traceAddress" => trace_address,
                     "type" => type
                   }
                 ],
                 "transactionHash" => transaction_hash
               }
             }
           ]}
        end)
      end

      {:ok, to_address_hash_bytes} = Chain.string_to_address_hash(created_contract_address_hash)
      {:ok, from_address_hash_bytes} = Chain.string_to_address_hash(from_address_hash)
      {:ok, created_contract_code_bytes} = Data.cast(created_contract_code)
      {:ok, init_bytes} = Data.cast(init)
      {:ok, transaction_hash_bytes} = Chain.string_to_transaction_hash(transaction_hash)
      {:ok, type_bytes} = Type.load(type)

      assert EthereumJSONRPC.Parity.fetch_first_trace(
               [
                 %{
                   hash_data: transaction_hash,
                   block_hash: block_hash,
                   block_number: block_number,
                   transaction_index: transaction_index
                 }
               ],
               json_rpc_named_arguments
             ) == {
               :ok,
               %{
                 block_index: 0,
                 block_hash: block_hash,
                 created_contract_address_hash: to_address_hash_bytes,
                 created_contract_code: created_contract_code_bytes,
                 from_address_hash: from_address_hash_bytes,
                 gas: gas,
                 gas_used: gas_used,
                 index: index,
                 init: init_bytes,
                 trace_address: trace_address,
                 transaction_hash: transaction_hash_bytes,
                 type: type_bytes,
                 value: value,
                 transaction_index: transaction_index
               }
             }
    end
  end

  describe "fetch_beneficiaries/1" do
    test "with valid block range, returns {:ok, addresses}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_hash = "0x52a8d2185282506ce681364d2aa0c085ba45fdeb5d6c0ddec1131617a71ee2ca"
      block_number = 5_080_887
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      hash1 = "0xef481b4e2c3ed62265617f2e9dfcdf3cf3efc11a"
      hash2 = "0x523b6539ff08d72a6c8bb598af95bf50c1ea839c"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^block_quantity]}], _options ->
          {:ok,
           [
             %{
               id: id,
               result: [
                 %{
                   "action" => %{
                     "author" => hash1,
                     "rewardType" => "block",
                     "value" => "0xde0b6b3a7640000"
                   },
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
                   "action" => %{
                     "author" => hash2,
                     "rewardType" => "block",
                     "value" => "0xde0b6b3a7640000"
                   },
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
           ]}
        end)
      end

      assert {:ok, %FetchedBeneficiaries{params_set: params_set}} =
               EthereumJSONRPC.Parity.fetch_beneficiaries([5_080_887], json_rpc_named_arguments)

      assert Enum.count(params_set) == 2

      assert %{
               block_number: block_number,
               block_hash: block_hash,
               address_hash: hash2,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set

      assert %{
               block_number: block_number,
               block_hash: block_hash,
               address_hash: hash1,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set
    end

    test "with 'external' 'rewardType'", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_hash = "0xf19a4ea2bb4f2d8839f4c3ec11e0e86c29d57799d7073713958fe1990e197cf5"
      block_number = 5_609_295
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      hash1 = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      hash2 = "0x523b6539ff08d72a6c8bb598af95bf50c1ea839c"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^block_quantity]}], _options ->
          {:ok,
           [
             %{
               id: id,
               result: [
                 %{
                   "action" => %{
                     "author" => hash1,
                     "rewardType" => "external",
                     "value" => "0xde0b6b3a7640000"
                   },
                   "blockHash" => block_hash,
                   "blockNumber" => 5_609_295,
                   "result" => nil,
                   "subtraces" => 0,
                   "traceAddress" => [],
                   "transactionHash" => nil,
                   "transactionPosition" => nil,
                   "type" => "reward"
                 },
                 %{
                   "action" => %{
                     "author" => hash2,
                     "rewardType" => "external",
                     "value" => "0xde0b6b3a7640000"
                   },
                   "blockHash" => "0xf19a4ea2bb4f2d8839f4c3ec11e0e86c29d57799d7073713958fe1990e197cf5",
                   "blockNumber" => 5_609_295,
                   "result" => nil,
                   "subtraces" => 0,
                   "traceAddress" => [],
                   "transactionHash" => nil,
                   "transactionPosition" => nil,
                   "type" => "reward"
                 }
               ]
             }
           ]}
        end)
      end

      assert {:ok, %FetchedBeneficiaries{params_set: params_set, errors: []}} =
               EthereumJSONRPC.Parity.fetch_beneficiaries([5_609_295], json_rpc_named_arguments)

      assert Enum.count(params_set) == 2

      assert %{
               block_number: block_number,
               block_hash: block_hash,
               address_hash: hash1,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set

      assert %{
               block_number: block_number,
               block_hash: block_hash,
               address_hash: hash2,
               address_type: :emission_funds,
               reward: "0xde0b6b3a7640000"
             } in params_set
    end

    test "with no rewards, returns {:ok, []}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _options when is_list(requests) ->
          responses = Enum.map(requests, fn %{id: id} -> %{id: id, result: []} end)
          {:ok, responses}
        end)

        assert {:ok, %FetchedBeneficiaries{params_set: params_set}} =
                 EthereumJSONRPC.Parity.fetch_beneficiaries([5_080_887], json_rpc_named_arguments)

        assert Enum.empty?(params_set)
      end
    end

    test "ignores non-reward traces", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_hash = "0x6659a4926d833a7eab74379fa647ec74c9f5e65f8029552a35264126560f300a"
      block_number = 5_077_429
      block_quantity = EthereumJSONRPC.integer_to_quantity(block_number)
      hash1 = "0xcfa53498686e00d3b4b41f3bea61604038eebb58"
      hash2 = "0x523b6539ff08d72a6c8bb598af95bf50c1ea839c"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, params: [^block_quantity]}], _options ->
          {:ok,
           [
             %{
               id: id,
               result: [
                 %{
                   "action" => %{
                     "callType" => "call",
                     "from" => "0x95426f2bc716022fcf1def006dbc4bb81f5b5164",
                     "gas" => "0x0",
                     "input" => "0x",
                     "to" => "0xe797a1da01eb0f951e0e400f9343de9d17a06bac",
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
                   "action" => %{
                     "author" => hash1,
                     "rewardType" => "block",
                     "value" => "0xde0b6b3a7640000"
                   },
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
                   "action" => %{
                     "author" => hash2,
                     "rewardType" => "block",
                     "value" => "0xde0b6b3a7640000"
                   },
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
           ]}
        end)
      end

      assert {:ok, %FetchedBeneficiaries{params_set: params_set}} =
               EthereumJSONRPC.Parity.fetch_beneficiaries([5_077_429], json_rpc_named_arguments)

      assert Enum.count(params_set) == 2

      assert %{
               block_number: block_number,
               block_hash: block_hash,
               address_hash: hash2,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set

      assert %{
               block_number: block_number,
               block_hash: block_hash,
               address_hash: hash1,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set
    end

    test "with multiple blocks with repeat beneficiaries", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_hash1 = "0xd2170e27857452d130128ac94c5258828a22cc69b07ab6e7fc12f7dd9938ff1c"
      block_number1 = 5_080_886
      block_quantity1 = EthereumJSONRPC.integer_to_quantity(block_number1)

      block_hash2 = "0x52a8d2185282506ce681364d2aa0c085ba45fdeb5d6c0ddec1131617a71ee2ca"
      block_number2 = 5_080_887
      block_quantity2 = EthereumJSONRPC.integer_to_quantity(block_number2)

      hash1 = "0xadc702c4bb09fbc502dd951856b9c7a1528a88de"
      hash2 = "0xef481b4e2c3ed62265617f2e9dfcdf3cf3efc11a"
      hash3 = "0x523b6539ff08d72a6c8bb598af95bf50c1ea839c"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _options when is_list(requests) ->
          responses =
            Enum.map(requests, fn
              %{id: id, params: [^block_quantity1]} ->
                %{
                  id: id,
                  result: [
                    %{
                      "action" => %{
                        "author" => hash1,
                        "rewardType" => "block",
                        "value" => "0xde0b6b3a7640000"
                      },
                      "blockHash" => block_hash1,
                      "blockNumber" => block_number1,
                      "result" => nil,
                      "subtraces" => 0,
                      "traceAddress" => [],
                      "transactionHash" => nil,
                      "transactionPosition" => nil,
                      "type" => "reward"
                    },
                    %{
                      "action" => %{
                        "author" => hash3,
                        "rewardType" => "block",
                        "value" => "0xde0b6b3a7640000"
                      },
                      "blockHash" => block_hash1,
                      "blockNumber" => block_number1,
                      "result" => nil,
                      "subtraces" => 0,
                      "traceAddress" => [],
                      "transactionHash" => nil,
                      "transactionPosition" => nil,
                      "type" => "reward"
                    }
                  ]
                }

              %{id: id, params: [^block_quantity2]} ->
                %{
                  id: id,
                  result: [
                    %{
                      "action" => %{
                        "author" => hash2,
                        "rewardType" => "block",
                        "value" => "0xde0b6b3a7640000"
                      },
                      "blockHash" => block_hash2,
                      "blockNumber" => block_number2,
                      "result" => nil,
                      "subtraces" => 0,
                      "traceAddress" => [],
                      "transactionHash" => nil,
                      "transactionPosition" => nil,
                      "type" => "reward"
                    },
                    %{
                      "action" => %{
                        "author" => hash3,
                        "rewardType" => "block",
                        "value" => "0xde0b6b3a7640000"
                      },
                      "blockHash" => block_hash2,
                      "blockNumber" => block_number2,
                      "result" => nil,
                      "subtraces" => 0,
                      "traceAddress" => [],
                      "transactionHash" => nil,
                      "transactionPosition" => nil,
                      "type" => "reward"
                    }
                  ]
                }
            end)

          {:ok, responses}
        end)
      end

      assert {:ok, %FetchedBeneficiaries{params_set: params_set}} =
               EthereumJSONRPC.Parity.fetch_beneficiaries(
                 [block_number1, block_number2],
                 json_rpc_named_arguments
               )

      assert Enum.count(params_set) == 4

      assert %{
               block_number: block_number1,
               block_hash: block_hash1,
               address_hash: hash1,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set

      assert %{
               block_number: block_number1,
               block_hash: block_hash1,
               address_hash: hash3,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set

      assert %{
               block_number: block_number2,
               block_hash: block_hash2,
               address_hash: hash2,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set

      assert %{
               block_number: block_number2,
               block_hash: block_hash2,
               address_hash: hash3,
               address_type: :validator,
               reward: "0xde0b6b3a7640000"
             } in params_set
    end

    test "with error, returns {:error, reason}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:error, "oops"}
        end)

        assert {:error, "oops"} = EthereumJSONRPC.Parity.fetch_beneficiaries([5_080_887], json_rpc_named_arguments)
      end
    end
  end
end
