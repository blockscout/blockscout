defmodule EthereumJSONRPCTest do
  use EthereumJSONRPC.Case, async: true

  import EthereumJSONRPC.Case
  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  import Mox

  alias EthereumJSONRPC.{Blocks, FetchedBalances, FetchedBeneficiaries, FetchedCodes, Subscription}
  alias EthereumJSONRPC.WebSocket.WebSocketClient

  setup :verify_on_exit!

  @moduletag :capture_log

  describe "fetch_balances/1" do
    test "with all valid hash_data returns {:ok, addresses_params}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      expected_fetched_balance =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Geth -> 0
          EthereumJSONRPC.Nethermind -> 1
          variant -> raise ArgumentError, "Unsupported variant (#{variant}})"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, result: EthereumJSONRPC.integer_to_quantity(expected_fetched_balance)}]}
        end)
      end

      hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"

      assert EthereumJSONRPC.fetch_balances(
               [
                 %{block_quantity: "0x1", hash_data: hash}
               ],
               json_rpc_named_arguments
             ) ==
               {:ok,
                %FetchedBalances{
                  params_list: [
                    %{
                      address_hash: hash,
                      block_number: 1,
                      value: expected_fetched_balance
                    }
                  ]
                }}
    end

    test "with all invalid hash_data returns errors", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      expected_message =
        case variant do
          EthereumJSONRPC.Geth ->
            "invalid argument 0: json: cannot unmarshal hex string of odd length into Go value of type common.Address"

          EthereumJSONRPC.Nethermind ->
            "Invalid params: invalid length 1, expected a 0x-prefixed hex string with length of 40."

          _ ->
            raise ArgumentError, "Unsupported variant (#{variant}})"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               error: %{
                 code: -32602,
                 message: expected_message
               }
             }
           ]}
        end)
      end

      assert {:ok,
              %FetchedBalances{
                errors: [
                  %{
                    code: -32602,
                    data: %{hash_data: "0x0", block_quantity: "0x1"},
                    message: ^expected_message
                  }
                ],
                params_list: []
              }} =
               EthereumJSONRPC.fetch_balances([%{block_quantity: "0x1", hash_data: "0x0"}], json_rpc_named_arguments)
    end

    test "with a mix of valid and invalid hash_data returns both", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {
            :ok,
            [
              %{
                id: 0,
                result: "0x0"
              },
              %{
                id: 1,
                result: "0x1"
              },
              %{
                id: 2,
                error: %{
                  code: -32602,
                  message:
                    "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                }
              },
              %{
                id: 3,
                result: "0x3"
              },
              %{
                id: 4,
                error: %{
                  code: -32602,
                  message:
                    "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                }
              }
            ]
          }
        end)
      end

      assert {:ok, %FetchedBalances{params_list: params_list, errors: errors}} =
               EthereumJSONRPC.fetch_balances(
                 [
                   # start with :ok
                   %{
                     block_quantity: "0x1",
                     hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                   },
                   # :ok, :ok clause
                   %{
                     block_quantity: "0x34",
                     hash_data: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
                   },
                   # :ok, :error clause
                   %{
                     block_quantity: "0x2",
                     hash_data: "0x3"
                   },
                   # :error, :ok clause
                   %{
                     block_quantity: "0x35",
                     hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                   },
                   # :error, :error clause
                   %{
                     block_quantity: "0x4",
                     hash_data: "0x5"
                   }
                 ],
                 json_rpc_named_arguments
               )

      assert is_list(params_list)
      assert length(params_list) > 1

      assert is_list(errors)
      assert length(errors) > 1
    end
  end

  describe "fetch_codes/2" do
    @tag :no_nethermind
    test "returns both codes and errors", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      code =
        "0x606060405236156100b95760e060020a600035046309dfdc7181146100dd578063253459e31461011c5780634229616d1461013d57806357d4021b1461017857806367f809e9146101b7578063686f2c90146101ce5780636fbaaa1e146101fa5780638a5fb3ca1461022e5780639dbc4f9b14610260578063a26dbf26146102ed578063a6f9dae1146102f5578063b402295014610328578063ced9267014610366578063d11f13df1461039e578063fae14192146103ab575b6103d66103d86000670de0b6b3a76400003410156104755760018054340190555b50565b6040805160208181018352600080835283519054610100820190945260ca8082526103da94670de0b6b3a7640000900493926107d29083013990509091565b600154670de0b6b3a764000090045b60408051918252519081900360200190f35b6103d6600435600554600090600160a060020a039081163390911614156105955760015481148061016e5750606482115b1561055a57610002565b61012b6000670de0b6b3a7640000600660005060046000505481548110156100025792526002919091026000805160206109bb83398151915201540490565b6103d660058054600160a060020a03191633179055565b6103d65b600554600160a060020a039081163390911614156103d857600154600014156104ef57610002565b6103da6040805160208181018352600082528251600354610140820190945261011f808252909161089c9083013990509091565b6103da604080516020818101835260008252825160025460c082019094526084808252909161074e9083013990509091565b61044f600435600654600090819083116102e85760068054849081101561000257508054818352600285027ff652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f377c0d3f0154600160a060020a03169350670de0b6b3a764000091908590811015610002575050600284026000805160206109bb83398151915201540490505b915091565b60065461012b565b6103d6600435600554600160a060020a039081163390911614156100da5760058054600160a060020a0319168217905550565b6103d6600435600554600160a060020a039081163390911614156100da57600154670de0b6b3a76400009190910290811115610519576105196101d2565b6103d6600435600554600160a060020a039081163390911614156100da5761012c8111806103945750607881105b1561059957610002565b600654600454900361012b565b6103d660043560055433600160a060020a03908116911614156100da57600a81111561059e57610002565b005b565b60405180838152602001806020018281038252838181518152602001915080519060200190808383829060006004602084601f0104600f02600301f150905090810190601f1680156104405780820380516001836020036101000a031916815260200191505b50935050505060405180910390f35b6040518083600160a060020a031681526020018281526020019250505060405180910390f35b506002546802b5e3af16b1880000341061048e57600290045b6100da816000600660005080548060010182818154818355818115116105a3576002028160020283600052602060002091820191016105a391905b80821115610607578054600160a060020a031916815560006001919091019081556104c9565b600154600554604051600160a060020a03919091169160009182818181858883f150505060015550565b6001546000141561052957610002565b600554604051600160a060020a039190911690600090839082818181858883f1505060018054919091039055505050565b506001546005546040516064909204830291600160a060020a039190911690600090839082818181858883f150506001805491909103905550505b5050565b600355565b600255565b50505091909060005260206000209060020201600050604080518082019091523380825260035460643491909102046020929092018290528254600160a060020a0319161782556001919091015550600654600a141561060b5760c860035561061c565b5090565b6006546019141561061c5760966003555b6000805460648481033490810282900490920190925560018054918502929092040190555b600454600680549091908110156100025760009182526002027ff652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f377c0d3f0190506001015460005411156105955760045460068054909190811015610002576002026000805160206109bb8339815191520154600454825491935090811015610002576002027ff652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f377c0d3f0154604051600160a060020a03919091169150600090839082818181858883f19350505050506006600050600460005054815481101561000257600091825281546002919091026000805160206109bb8339815191520154900390556004805460010190556106415653686f776e20696e202520666f726d2e204665652069732068616c766564283530252920666f7220616d6f756e747320657175616c206f722067726561746572207468616e203530206574686572732e2028466565206d6179206368616e67652c206275742069732063617070656420746f2061206d6178696d756d206f662031302529416c6c2062616c616e63652076616c75657320617265206d6561737572656420696e204574686572732c206e6f746520746861742064756520746f206e6f20646563696d616c20706c6163696e672c2074686573652076616c7565732073686f7720757020617320696e746567657273206f6e6c792c2077697468696e2074686520636f6e747261637420697473656c6620796f752077696c6c206765742074686520657861637420646563696d616c2076616c756520796f752061726520737570706f73656420746f54686973206d756c7469706c696572206170706c69657320746f20796f7520617320736f6f6e206173207472616e73616374696f6e2069732072656365697665642c206d6179206265206c6f776572656420746f2068617374656e207061796f757473206f7220696e63726561736564206966207061796f75747320617265206661737420656e6f7567682e2044756520746f206e6f20666c6f6174206f7220646563696d616c732c206d756c7469706c696572206973207831303020666f722061206672616374696f6e616c206d756c7469706c69657220652e672e203235302069732061637475616c6c79206120322e3578206d756c7469706c6965722e20436170706564206174203378206d617820616e6420312e3278206d696e2ef652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f377c0d40"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {
            :ok,
            [
              %{
                id: 0,
                result: code
              },
              %{
                id: 1,
                error: %{
                  code: -32602,
                  message:
                    "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                }
              }
            ]
          }
        end)
      end

      assert {:ok, %FetchedCodes{params_list: params_list, errors: errors}} =
               EthereumJSONRPC.fetch_codes(
                 [
                   # start with :ok
                   %{
                     block_quantity: "0x6ae753",
                     address: "0xe82719202e5965Cf5D9B6673B7503a3b92DE20be"
                   },
                   # :ok, :error clause
                   %{
                     block_quantity: "0x2",
                     address: ""
                   }
                   # :error
                 ],
                 json_rpc_named_arguments
               )

      assert params_list == [
               %{
                 address: "0xe82719202e5965Cf5D9B6673B7503a3b92DE20be",
                 block_number: 7_006_035,
                 code: code
               }
             ]

      assert Enum.count(errors) == 1
    end
  end

  describe "fetch_beneficiaries/2" do
    @tag :no_geth
    test "fetches beneficiaries from variant API", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
          {:ok, []}
        end)

        assert EthereumJSONRPC.fetch_beneficiaries([1], json_rpc_named_arguments) ==
                 {:ok, %FetchedBeneficiaries{params_set: MapSet.new(), errors: []}}
      end
    end
  end

  describe "fetch_block_by_hash/2" do
    test "can fetch blocks", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %{block_hash: block_hash, transaction_hash: transaction_hash} =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            %{
              block_hash: "0x29c850324e357f3c0c836d79860c5af55f7b651e5d7ee253c1af1b14908af49c",
              transaction_hash: "0xa2e81bb56b55ba3dab2daf76501b50dfaad240cccb905dbf89d65c7a84a4a48e"
            }

          EthereumJSONRPC.Geth ->
            %{
              block_hash: "0xe065eed62c152c8c3dd14d6e5948e652c3e36a9cdb10b79853802ef9fa1d536c",
              transaction_hash: "0x615506d9872bb07faa2ce17c02b902148eae88ccba0298902be6a0dbba1124de"
            }
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id}], _options ->
          block_number = "0x0"

          {:ok,
           [
             %{
               id: id,
               result: %{
                 "difficulty" => "0x0",
                 "gasLimit" => "0x0",
                 "gasUsed" => "0x0",
                 "hash" => block_hash,
                 "extraData" => "0x0",
                 "logsBloom" => "0x0",
                 "miner" => "0x0",
                 "number" => block_number,
                 "parentHash" => "0x0",
                 "receiptsRoot" => "0x0",
                 "size" => "0x0",
                 "sha3Uncles" => "0x0",
                 "stateRoot" => "0x0",
                 "timestamp" => "0x0",
                 "totalDifficulty" => "0x0",
                 "transactions" => [
                   %{
                     "blockHash" => block_hash,
                     "blockNumber" => block_number,
                     "from" => "0x0",
                     "gas" => "0x0",
                     "gasPrice" => "0x0",
                     "hash" => transaction_hash,
                     "input" => "0x",
                     "nonce" => "0x0",
                     "r" => "0x0",
                     "s" => "0x0",
                     "to" => "0x0",
                     "transactionIndex" => "0x0",
                     "v" => "0x0",
                     "value" => "0x0"
                   }
                 ],
                 "transactionsRoot" => "0x0",
                 "uncles" => []
               }
             }
           ]}
        end)
      end

      assert {:ok, %Blocks{blocks_params: [_ | _], transactions_params: [_ | _]}} =
               EthereumJSONRPC.fetch_blocks_by_hash([block_hash], json_rpc_named_arguments)
    end

    test "returns errors with block hash in data", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               error: %{
                 code: -32602,
                 message: "Hash too short"
               },
               id: 0,
               jsonrpc: "2.0"
             }
           ]}
        end)
      end

      hash = "0x0"

      assert {:ok,
              %Blocks{
                errors: [
                  %{
                    data: %{
                      hash: ^hash
                    }
                  }
                ]
              }} = EthereumJSONRPC.fetch_blocks_by_hash([hash], json_rpc_named_arguments)
    end

    test "full batch errors are returned", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # I'm not sure how to reliably trigger this on the real chains, so only do mox
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      error = {:error, %{"message" => "methodNotSupported"}}

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        error
      end)

      assert EthereumJSONRPC.fetch_blocks_by_hash(["0x0"], moxed_json_rpc_named_arguments) == error
    end
  end

  describe "fetch_block_by_range/2" do
    test "returns errors with block number in data", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               error: %{
                 code: -32602,
                 message: "Invalid params: Invalid block number: number too large to fit in target type."
               },
               id: 0,
               jsonrpc: "2.0"
             },
             %{
               error: %{
                 code: -32602,
                 message: "Invalid params: Invalid block number: number too large to fit in target type."
               },
               id: 1,
               jsonrpc: "2.0"
             }
           ]}
        end)
      end

      assert {:ok,
              %EthereumJSONRPC.Blocks{
                block_second_degree_relations_params: [],
                blocks_params: [],
                errors: [
                  %{
                    data: %{number: 1_000_000_000_000_000_000_001}
                  },
                  %{
                    data: %{number: 1_000_000_000_000_000_000_000}
                  }
                ],
                transactions_params: []
              }} =
               EthereumJSONRPC.fetch_blocks_by_range(
                 1_000_000_000_000_000_000_000..1_000_000_000_000_000_000_001,
                 json_rpc_named_arguments
               )
    end

    test "returns only errors and results if a mix of results and errors", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      # Can't be faked reliably on real chain
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok,
         [
           %{
             error: %{
               code: -32602,
               message: "Invalid params: Invalid block number: number too large to fit in target type."
             },
             id: 0,
             jsonrpc: "2.0"
           },
           %{
             id: 1,
             result: %{
               "difficulty" => "0x0",
               "extraData" => "0x",
               "gasLimit" => "0x0",
               "gasUsed" => "0x0",
               "hash" => "0x0",
               "logsBloom" => "0x",
               "miner" => "0x0",
               "number" => "0x0",
               "parentHash" => "0x0",
               "receiptsRoot" => "0x0",
               "sha3Uncles" => "0x0",
               "size" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x0",
               "totalDifficulty" => "0x0",
               "transactions" => [],
               "transactionsRoot" => [],
               "uncles" => []
             },
             jsonrpc: "2.0"
           }
         ]}
      end)

      assert {:ok,
              %EthereumJSONRPC.Blocks{
                block_second_degree_relations_params: [],
                blocks_params: [
                  %{
                    difficulty: 0,
                    extra_data: "0x",
                    gas_limit: 0,
                    gas_used: 0,
                    hash: "0x0",
                    logs_bloom: "0x",
                    miner_hash: "0x0",
                    mix_hash: "0x0",
                    nonce: 0,
                    number: 0,
                    parent_hash: "0x0",
                    receipts_root: "0x0",
                    sha3_uncles: "0x0",
                    size: 0,
                    state_root: "0x0",
                    timestamp: _,
                    total_difficulty: 0,
                    transactions_root: [],
                    uncles: []
                  }
                ],
                errors: [
                  %{
                    code: -32602,
                    data: %{number: 1_000_000_000_000_000_000_000},
                    message: "Invalid params: Invalid block number: number too large to fit in target type."
                  }
                ],
                transactions_params: []
              }} =
               EthereumJSONRPC.fetch_blocks_by_range(
                 1_000_000_000_000_000_000_000..1_000_000_000_000_000_000_001,
                 moxed_json_rpc_named_arguments
               )
    end

    test "nil result indicated error code 404", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # Can't be faked reliably on real chain
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok,
         [
           %{
             id: 0,
             result: %{
               "difficulty" => "0x0",
               "extraData" => "0x0",
               "gasLimit" => "0x0",
               "gasUsed" => "0x0",
               "hash" => "0x0",
               "logsBloom" => "0x0",
               "miner" => "0x0",
               "number" => "0x0",
               "parentHash" => "0x0",
               "receiptsRoot" => "0x0",
               "sha3Uncles" => "0x0",
               "size" => "0x0",
               "stateRoot" => "0x0",
               "timestamp" => "0x0",
               "totalDifficulty" => "0x0",
               "transactions" => [],
               "transactionsRoot" => "0x0",
               "uncles" => []
             },
             jsonrpc: "2.0"
           },
           %{
             result: nil,
             id: 1,
             jsonrpc: "2.0"
           }
         ]}
      end)

      assert {:ok,
              %EthereumJSONRPC.Blocks{
                block_second_degree_relations_params: [],
                blocks_params: [%{}],
                errors: [%{code: 404, data: %{number: 1}, message: "Not Found"}],
                transactions_params: []
              }} = EthereumJSONRPC.fetch_blocks_by_range(0..1, moxed_json_rpc_named_arguments)
    end
  end

  describe "fetch_block_by_tag/2" do
    @supported_tags ~w(earliest latest pending)

    @tag capture_log: false
    test "with all supported tags", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      for tag <- @supported_tags do
        if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
          expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                      %{
                                                        id: id,
                                                        method: "eth_getBlockByNumber",
                                                        params: [^tag, false]
                                                      }
                                                    ],
                                                    _options ->
            block_response(id, tag == "pending", "0x1")
          end)
        end

        log_bad_gateway(
          fn -> EthereumJSONRPC.fetch_block_by_tag(tag, json_rpc_named_arguments) end,
          fn result ->
            {:ok, %Blocks{blocks_params: [_ | _], transactions_params: []}} = result
          end
        )
      end
    end

    test "unknown errors are returned", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # Can't be faked reliably on real chain
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      unknown_error = %{"code" => 500, "message" => "Unknown error"}

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:error, unknown_error}
      end)

      assert {:error, ^unknown_error} = EthereumJSONRPC.fetch_block_by_tag("latest", moxed_json_rpc_named_arguments)
    end
  end

  describe "fetch_block_number_by_tag" do
    @supported_tags %{"earliest" => "0x0", "latest" => "0x1", "pending" => nil}

    @tag capture_log: false
    test "with all supported tags", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      for {tag, expected_result} <- @supported_tags do
        if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
          expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                      %{
                                                        id: id,
                                                        method: "eth_getBlockByNumber",
                                                        params: [^tag, false]
                                                      }
                                                    ],
                                                    _options ->
            if tag == "pending" do
              {:ok, [%{id: id, result: nil}]}
            else
              block_response(id, false, expected_result)
            end
          end)
        end

        log_bad_gateway(
          fn -> EthereumJSONRPC.fetch_block_number_by_tag(tag, json_rpc_named_arguments) end,
          if tag == "pending" do
            fn
              # Parity after https://github.com/paritytech/parity-ethereum/pull/8281 and anything spec-compliant
              {:error, reason} ->
                assert reason == :not_found

              # Parity before https://github.com/paritytech/parity-ethereum/pull/8281
              {:ok, number} ->
                assert is_integer(number)
                assert number > 0
            end
          else
            fn result ->
              integer_result = expected_result && quantity_to_integer(expected_result)
              assert {:ok, ^integer_result} = result
            end
          end
        )
      end
    end

    test "unknown errors are returned", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      # Can't be faked reliably on real chain
      moxed_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      unknown_error = %{"code" => 500, "message" => "Unknown error"}

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:error, unknown_error}
      end)

      assert {:error, ^unknown_error} =
               EthereumJSONRPC.fetch_block_number_by_tag("latest", moxed_json_rpc_named_arguments)
    end
  end

  describe "fetch_pending_transactions/2" do
    @tag :no_geth
    test "pending transactions are returned", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               "blockHash" => nil,
               "blockNumber" => nil,
               "from" => "0x0",
               "gas" => "0x0",
               "gasPrice" => "0x0",
               "hash" => "0x73c5599001f77bd570e32c4a5e63157200747910a502fae009821767c36b2ac9",
               "input" => "0x",
               "nonce" => "0x0",
               "r" => "0x0",
               "s" => "0x0",
               "to" => "0x0",
               "transactionIndex" => nil,
               "v" => "0x0",
               "value" => "0x0"
             }
           ]}
        end)
      end

      assert {:ok, pending_transactions} = EthereumJSONRPC.fetch_pending_transactions(json_rpc_named_arguments)
      # can't say more because there could be no pending transactions on test chains
      assert is_list(pending_transactions)
    end
  end

  describe "fetch_transaction_receipts/2" do
    test "with invalid transaction hash", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      hash = "0x0000000000000000000000000000000000000000000000000000000000000000"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, jsonrpc: "2.0", result: nil}]}
        end)
      end

      assert {:error, [%{data: %{hash: ^hash}, message: "Not Found"}]} =
               EthereumJSONRPC.fetch_transaction_receipts(
                 [%{hash: hash, gas: "0x0"}],
                 json_rpc_named_arguments
               )
    end

    test "with valid transaction hash", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      hash =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind ->
            "0xa2e81bb56b55ba3dab2daf76501b50dfaad240cccb905dbf89d65c7a84a4a48e"

          EthereumJSONRPC.Geth ->
            "0x615506d9872bb07faa2ce17c02b902148eae88ccba0298902be6a0dbba1124de"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "blockHash" => "0x29c850324e357f3c0c836d79860c5af55f7b651e5d7ee253c1af1b14908af49c",
                 "blockNumber" => "0x414911",
                 "contractAddress" => nil,
                 "cumulativeGasUsed" => "0x5208",
                 "gasUsed" => "0x5208",
                 "logs" => [],
                 "logsBloom" =>
                   "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                 "root" => nil,
                 "status" => "0x1",
                 "transactionHash" => hash,
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end)
      end

      assert {:ok, %{logs: logs, receipts: [_]}} =
               EthereumJSONRPC.fetch_transaction_receipts([%{hash: hash, gas: "0x0"}], json_rpc_named_arguments)

      assert is_list(logs)
    end
  end

  describe "subscribe/2" do
    test "can subscribe to newHeads", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      subscription_transport_options =
        case transport do
          EthereumJSONRPC.Mox ->
            expect(transport, :subscribe, fn "newHeads", [], _ ->
              {:ok,
               %Subscription{
                 reference: make_ref(),
                 subscriber_pid: subscriber_pid,
                 transport: transport,
                 transport_options: transport_options
               }}
            end)

            transport_options

          EthereumJSONRPC.WebSocket ->
            update_in(transport_options.web_socket_options, fn %WebSocketClient.Options{} = web_socket_options ->
              %WebSocketClient.Options{web_socket_options | event: "newHeads", params: []}
            end)
        end

      assert {:ok,
              %Subscription{
                reference: subscription_reference,
                subscriber_pid: ^subscriber_pid,
                transport: ^transport,
                transport_options: ^subscription_transport_options
              }} = EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments)

      assert is_reference(subscription_reference)
    end

    # Infura timeouts on 2018-09-12
    @tag :no_geth
    test "delivers new heads to caller", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        expect(transport, :subscribe, fn _, _, _ ->
          subscription = %Subscription{
            reference: make_ref(),
            subscriber_pid: subscriber_pid,
            transport: transport,
            transport_options: transport_options
          }

          Process.send_after(subscriber_pid, {subscription, {:ok, %{"number" => "0x1"}}}, block_interval)

          {:ok, subscription}
        end)
      end

      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments)

      assert_receive {^subscription, {:ok, %{"number" => _}}}, block_interval * 2
    end
  end

  describe "unsubscribe/2" do
    # Infura timeouts on 2018-09-10
    @tag :no_geth
    test "can unsubscribe", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        subscription = %Subscription{
          reference: make_ref(),
          subscriber_pid: subscriber_pid,
          transport: transport,
          transport_options: transport_options
        }

        transport
        |> expect(:subscribe, fn _, _, _ -> {:ok, subscription} end)
        |> expect(:unsubscribe, fn ^subscription -> :ok end)
      end

      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments)

      assert :ok = EthereumJSONRPC.unsubscribe(subscription)
    end

    # Infura timeouts on 2018-09-10
    @tag :no_geth
    test "stops messages being sent to subscriber", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        subscription = %Subscription{
          reference: make_ref(),
          subscriber_pid: subscriber_pid,
          transport: transport,
          transport_options: Keyword.fetch!(subscribe_named_arguments, :transport_options)
        }

        {:ok, pid} = Task.start_link(EthereumJSONRPC.WebSocket.Case.Mox, :loop, [%{}])

        transport
        |> expect(:subscribe, 2, fn "newHeads", [], _ ->
          send(pid, {:subscribe, subscription})

          {:ok, subscription}
        end)
        |> expect(:unsubscribe, fn ^subscription ->
          send(pid, {:unsubscribe, subscription})

          :ok
        end)
      end

      assert {:ok, first_subscription} = EthereumJSONRPC.subscribe("newHeads", [], subscribe_named_arguments)
      assert {:ok, second_subscription} = EthereumJSONRPC.subscribe("newHeads", [], subscribe_named_arguments)

      wait = block_interval * 2

      assert_receive {^first_subscription, {:ok, %{"number" => _}}}, wait
      assert_receive {^second_subscription, {:ok, %{"number" => _}}}, wait

      assert :ok = EthereumJSONRPC.unsubscribe(first_subscription)

      clear_mailbox()

      # see the message on the second subscription, so that we don't have to wait for the refute_receive, which would
      # wait the full timeout
      assert_receive {^second_subscription, {:ok, %{"number" => _}}}, wait
      refute_receive {^first_subscription, _}
    end

    test "return error if already unsubscribed", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport == EthereumJSONRPC.Mox do
        subscription = %Subscription{
          reference: make_ref(),
          subscriber_pid: subscriber_pid,
          transport: transport,
          transport_options: transport_options
        }

        transport
        |> expect(:subscribe, fn _, _, _ -> {:ok, subscription} end)
        |> expect(:unsubscribe, fn ^subscription -> :ok end)
        |> expect(:unsubscribe, fn ^subscription -> {:error, :not_found} end)
      end

      assert {:ok, subscription} = EthereumJSONRPC.subscribe("newHeads", [], subscribe_named_arguments)

      assert :ok = EthereumJSONRPC.unsubscribe(subscription)

      assert {:error, :not_found} = EthereumJSONRPC.unsubscribe(subscription)
    end
  end

  describe "unique_request_id" do
    test "returns integer" do
      assert is_integer(EthereumJSONRPC.unique_request_id())
    end
  end

  describe "fetch_net_version/1" do
    test "fetches net version", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expected_version =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Nethermind -> 77
          _variant -> 1
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, "#{expected_version}"}
        end)
      end

      assert {:ok, ^expected_version} = EthereumJSONRPC.fetch_net_version(json_rpc_named_arguments)
    end
  end

  defp clear_mailbox do
    receive do
      _ -> clear_mailbox()
    after
      0 ->
        :ok
    end
  end

  defp block_response(id, pending, block_number) do
    block_hash = "0x29c850324e357f3c0c836d79860c5af55f7b651e5d7ee253c1af1b14908af49c"
    transaction_hash = "0xa2e81bb56b55ba3dab2daf76501b50dfaad240cccb905dbf89d65c7a84a4a48e"

    {:ok,
     [
       %{
         id: id,
         result: %{
           "difficulty" => "0x0",
           "gasLimit" => "0x0",
           "gasUsed" => "0x0",
           "hash" => if(pending, do: nil, else: block_hash),
           "extraData" => "0x0",
           "logsBloom" => "0x0",
           "miner" => "0x0",
           "number" => block_number,
           "parentHash" => "0x0",
           "receiptsRoot" => "0x0",
           "size" => "0x0",
           "sha3Uncles" => "0x0",
           "stateRoot" => "0x0",
           "timestamp" => "0x0",
           "totalDifficulty" => "0x0",
           "transactions" => [transaction_hash],
           "transactionsRoot" => "0x0",
           "uncles" => []
         }
       }
     ]}
  end
end

defmodule EthereumJSONRPCSyncTest do
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias EthereumJSONRPC.FetchedBalances
  setup :verify_on_exit!

  @moduletag :capture_log

  describe "fetch_balances/1" do
    setup do
      initial_env = Application.get_all_env(:indexer)
      on_exit(fn -> Application.put_all_env([{:indexer, initial_env}]) end)
    end

    test "ignores all request with block_quantity != latest when env ETHEREUM_JSONRPC_DISABLE_ARCHIVE_BALANCES is true",
         %{
           json_rpc_named_arguments: json_rpc_named_arguments
         } do
      hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      expected_fetched_balance = 1

      expect(EthereumJSONRPC.Mox, :json_rpc, 1, fn [
                                                     %{
                                                       id: 0,
                                                       jsonrpc: "2.0",
                                                       method: "eth_getBalance",
                                                       params: [^hash, "latest"]
                                                     }
                                                   ],
                                                   _options ->
        {:ok, [%{id: 0, result: EthereumJSONRPC.integer_to_quantity(expected_fetched_balance)}]}
      end)

      Application.put_env(:ethereum_jsonrpc, :disable_archive_balances?, "true")

      assert EthereumJSONRPC.fetch_balances(
               [
                 %{block_quantity: "0x1", hash_data: hash},
                 %{block_quantity: "0x2", hash_data: hash},
                 %{block_quantity: "0x3", hash_data: hash},
                 %{block_quantity: "0x4", hash_data: hash},
                 %{block_quantity: "latest", hash_data: hash}
               ],
               json_rpc_named_arguments
             ) ==
               {:ok,
                %FetchedBalances{
                  params_list: [
                    %{
                      address_hash: hash,
                      block_number: nil,
                      value: expected_fetched_balance
                    }
                  ]
                }}
    end
  end
end
