defmodule Explorer.Factory do
  use ExMachina.Ecto, repo: Explorer.Repo

  require Ecto.Query

  import Ecto.Query
  import Explorer.Chain, only: [hash_to_lower_case_string: 1]
  import Kernel, except: [+: 2]

  alias Explorer.Account.{
    Identity,
    Watchlist,
    WatchlistAddress
  }

  alias Explorer.Accounts.{
    User,
    UserContact
  }

  alias Explorer.Admin.Administrator
  alias Explorer.Chain.Block.{EmissionReward, Range, Reward}

  alias Explorer.Chain.{
    Address,
    Address.CurrentTokenBalance,
    Address.TokenBalance,
    Address.CoinBalance,
    Address.CoinBalanceDaily,
    Block,
    ContractMethod,
    Data,
    DecompiledSmartContract,
    Hash,
    InternalTransaction,
    Log,
    PendingBlockOperation,
    SmartContract,
    Token,
    TokenTransfer,
    Token.Instance,
    Transaction
  }

  alias Explorer.SmartContract.Helper

  alias Explorer.Market.MarketHistory
  alias Explorer.Repo

  alias Explorer.Utility.MissingBlockRange

  alias Ueberauth.Strategy.Auth0
  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth

  def account_identity_factory do
    %Identity{
      uid: sequence("github|"),
      email: sequence(:email, &"me-#{&1}@blockscout.com"),
      name: sequence("John")
    }
  end

  def auth_factory do
    %Auth{
      info: %Info{
        birthday: nil,
        description: nil,
        email: sequence(:email, &"test_user-#{&1}@blockscout.com"),
        first_name: nil,
        image: sequence("https://example.com/avatar/test_user"),
        last_name: nil,
        location: nil,
        name: sequence("User Test"),
        nickname: sequence("test_user"),
        phone: nil,
        urls: %{profile: nil, website: nil}
      },
      provider: :auth0,
      strategy: Auth0,
      uid: sequence("blockscout|000")
    }
  end

  def watchlist_address_factory do
    %{
      "address_hash" => to_string(build(:address).hash),
      "name" => sequence("test"),
      "notification_settings" => %{
        "native" => %{
          "incoming" => random_bool(),
          "outcoming" => random_bool()
        },
        "ERC-20" => %{
          "incoming" => random_bool(),
          "outcoming" => random_bool()
        },
        "ERC-721" => %{
          "incoming" => random_bool(),
          "outcoming" => random_bool()
        }
      },
      "notification_methods" => %{
        "email" => random_bool()
      }
    }
  end

  def custom_abi_factory do
    contract_address_hash = to_string(insert(:contract_address).hash)

    %{"contract_address_hash" => contract_address_hash, "name" => sequence("test"), "abi" => contract_code_info().abi}
  end

  def public_tags_request_factory do
    %{
      "full_name" => sequence("full name"),
      "email" => sequence(:email, &"test_user-#{&1}@blockscout.com"),
      "tags" => Enum.join(Enum.map(1..Enum.random(1..2), fn _ -> sequence("Tag") end), ";"),
      "website" => sequence("website"),
      "additional_comment" => sequence("additional_comment"),
      "addresses" => Enum.map(1..Enum.random(1..10), fn _ -> to_string(build(:address).hash) end),
      "company" => sequence("company"),
      "is_owner" => random_bool()
    }
  end

  def account_watchlist_factory do
    %Watchlist{
      identity: build(:account_identity)
    }
  end

  def tag_address_factory do
    %{"name" => sequence("name"), "address_hash" => to_string(build(:address).hash)}
  end

  def tag_transaction_factory do
    %{"name" => sequence("name"), "transaction_hash" => to_string(insert(:transaction).hash)}
  end

  def account_watchlist_address_factory do
    hash = build(:address).hash

    %WatchlistAddress{
      name: "wallet",
      watchlist: build(:account_watchlist),
      address_hash: hash,
      address_hash_hash: hash_to_lower_case_string(hash),
      watch_coin_input: true,
      watch_coin_output: true,
      watch_erc_20_input: true,
      watch_erc_20_output: true,
      watch_erc_721_input: true,
      watch_erc_721_output: true,
      watch_erc_1155_input: true,
      watch_erc_1155_output: true,
      notify_email: true
    }
  end

  def address_factory do
    %Address{
      hash: address_hash()
    }
  end

  def address_name_factory do
    %Address.Name{
      address: build(:address),
      name: "FooContract"
    }
  end

  def unique_address_name_factory do
    %Address.Name{
      address: build(:address),
      name: sequence("FooContract")
    }
  end

  def unfetched_balance_factory do
    %CoinBalance{
      address_hash: address_hash(),
      block_number: block_number()
    }
  end

  def unfetched_balance_daily_factory do
    %CoinBalanceDaily{
      address_hash: address_hash(),
      day: Timex.shift(Timex.now(), days: Enum.random(0..100) * -1)
    }
  end

  def update_balance_value(%CoinBalance{address_hash: address_hash, block_number: block_number}, value) do
    Repo.update_all(
      from(
        balance in CoinBalance,
        where: balance.address_hash == ^address_hash and balance.block_number == ^block_number
      ),
      set: [value: value, value_fetched_at: DateTime.utc_now()]
    )
  end

  def fetched_balance_factory do
    unfetched_balance_factory()
    |> struct!(value: Enum.random(1..100_000))
  end

  def fetched_balance_daily_factory do
    unfetched_balance_daily_factory()
    |> struct!(value: Enum.random(1..100_000))
  end

  def contract_address_factory do
    %Address{
      hash: address_hash(),
      contract_code: Map.fetch!(contract_code_info(), :bytecode)
    }
  end

  def contract_code_info do
    %{
      bytecode:
        "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
      tx_input:
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
      name: "SimpleStorage",
      source_code: """
      pragma solidity ^0.4.24;

      contract SimpleStorage {
          uint storedData;

          function set(uint x) public {
              storedData = x;
          }

          function get() public constant returns (uint) {
              return storedData;
          }
      }
      """,
      abi: [
        %{
          "constant" => false,
          "inputs" => [%{"name" => "x", "type" => "uint256"}],
          "name" => "set",
          "outputs" => [],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get",
          "outputs" => [%{"name" => "", "type" => "uint256"}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        }
      ],
      version: "v0.4.24+commit.e67f0147",
      optimized: false
    }
  end

  def contract_code_info_modern_compilator do
    %{
      bytecode:
        "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c806360fe47b11461003b5780636d4ce63c14610057575b600080fd5b610055600480360381019061005091906100c3565b610075565b005b61005f61007f565b60405161006c91906100ff565b60405180910390f35b8060008190555050565b60008054905090565b600080fd5b6000819050919050565b6100a08161008d565b81146100ab57600080fd5b50565b6000813590506100bd81610097565b92915050565b6000602082840312156100d9576100d8610088565b5b60006100e7848285016100ae565b91505092915050565b6100f98161008d565b82525050565b600060208201905061011460008301846100f0565b9291505056fea2646970667358221220d5d429d16f620053da9907372b66303e007b04bfd112159cff82cb67ff40da4264736f6c634300080a0033",
      tx_input:
        "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c806360fe47b11461003b5780636d4ce63c14610057575b600080fd5b610055600480360381019061005091906100c3565b610075565b005b61005f61007f565b60405161006c91906100ff565b60405180910390f35b8060008190555050565b60008054905090565b600080fd5b6000819050919050565b6100a08161008d565b81146100ab57600080fd5b50565b6000813590506100bd81610097565b92915050565b6000602082840312156100d9576100d8610088565b5b60006100e7848285016100ae565b91505092915050565b6100f98161008d565b82525050565b600060208201905061011460008301846100f0565b9291505056fea2646970667358221220d5d429d16f620053da9907372b66303e007b04bfd112159cff82cb67ff40da4264736f6c634300080a0033",
      name: "SimpleStorage",
      source_code: """
      pragma solidity ^0.8.10;
      // SPDX-License-Identifier: MIT

      contract SimpleStorage {
          uint storedData;

          function set(uint x) public {
              storedData = x;
          }

          function get() public view returns (uint) {
              return storedData;
          }
      }
      """,
      abi: [
        %{
          "inputs" => [],
          "name" => "get",
          "outputs" => [
            %{
              "internalType" => "uint256",
              "name" => "",
              "type" => "uint256"
            }
          ],
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "inputs" => [
            %{
              "internalType" => "uint256",
              "name" => "x",
              "type" => "uint256"
            }
          ],
          "name" => "set",
          "outputs" => [],
          "stateMutability" => "nonpayable",
          "type" => "function"
        }
      ],
      version: "v0.8.10+commit.fc410830",
      optimized: false
    }
  end

  def contract_code_info_with_constructor_arguments do
    %{
      bytecode:
        "0x6080604052600080fdfea26469706673582212209864ab97aa6a0d2c5cc0828f7fbe63df8fb5e90c758d49371edb3184bcc8239664736f6c63430008040033",
      tx_input:
        "0x60806040526315c8dd0d60005534801561001857600080fd5b5060405161053e38038061053e8339810160408190526100379161039b565b855161004a906001906020890190610056565b505050505050506104f1565b828054828255906000526020600020908101928215610091579160200282015b82811115610091578251825591602001919060010190610076565b5061009d9291506100a1565b5090565b5b8082111561009d57600081556001016100a2565b60006001600160401b038311156100cf576100cf6104db565b60206100e3601f8501601f19168201610488565b91508382528484840111156100f757600080fd5b60005b84811015610113578381015183820183015281016100fa565b848111156101245760008286850101525b50509392505050565b600082601f83011261013d578081fd5b8151602061015261014d836104b8565b610488565b80838252828201915082860187848660051b8901011115610171578586fd5b855b858110156101a35781516001600160a01b0381168114610191578788fd5b84529284019290840190600101610173565b5090979650505050505050565b600082601f8301126101c0578081fd5b815160206101d061014d836104b8565b80838252828201915082860187848660051b89010111156101ef578586fd5b855b858110156101a35781518015158114610208578788fd5b845292840192908401906001016101f1565b600082601f83011261022a578081fd5b8151602061023a61014d836104b8565b80838252828201915082860187848660051b8901011115610259578586fd5b855b858110156101a35781516001600160401b03811115610278578788fd5b8801603f81018a13610288578788fd5b6102998a87830151604084016100b6565b855250928401929084019060010161025b565b600082601f8301126102bc578081fd5b815160206102cc61014d836104b8565b80838252828201915082860187848660051b89010111156102eb578586fd5b855b858110156101a3578151845292840192908401906001016102ed565b600082601f830112610319578081fd5b8151602061032961014d836104b8565b80838252828201915082860187848660051b8901011115610348578586fd5b855b858110156101a35781516001600160401b03811115610367578788fd5b8801603f81018a13610377578788fd5b6103888a87830151604084016100b6565b855250928401929084019060010161034a565b60008060008060008060c087890312156103b3578182fd5b86516001600160401b03808211156103c9578384fd5b6103d58a838b016102ac565b975060208901519150808211156103ea578384fd5b6103f68a838b0161012d565b9650604089015191508082111561040b578384fd5b6104178a838b016102ac565b9550606089015191508082111561042c578384fd5b6104388a838b016101b0565b9450608089015191508082111561044d578384fd5b6104598a838b0161021a565b935060a089015191508082111561046e578283fd5b5061047b89828a01610309565b9150509295509295509295565b604051601f8201601f191681016001600160401b03811182821017156104b0576104b06104db565b604052919050565b60006001600160401b038211156104d1576104d16104db565b5060051b60200190565b634e487b7160e01b600052604160045260246000fd5b603f806104ff6000396000f3fe6080604052600080fdfea26469706673582212209864ab97aa6a0d2c5cc0828f7fbe63df8fb5e90c758d49371edb3184bcc8239664736f6c6343000804003300000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002a00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000756b5b30000000000000000000000000000000000000000000000000000000000000002000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000004fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb0000000000000000000000000000000000000000000000000000000000000006ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd8f0000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000371776500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003657771000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000097177657177657177650000000000000000000000000000000000000000000000",
      name: "Simple",
      source_code: """
      // SPDX-License-Identifier: GPL-3.0
      pragma solidity >=0.7.0 <0.9.0;

      contract Simple {

          uint256 number = 365485325;
          uint256[] array;


          constructor(uint256[] memory arr, address[] memory addresses,int[] memory ints, bool[] memory bools, bytes[] memory byts, string[]  memory strings) {
              array = arr;
          }

      }
      """,
      abi: [
        %{
          "inputs" => [
            %{
              "internalType" => "uint256[]",
              "name" => "arr",
              "type" => "uint256[]"
            },
            %{
              "internalType" => "address[]",
              "name" => "addresses",
              "type" => "address[]"
            },
            %{
              "internalType" => "int256[]",
              "name" => "ints",
              "type" => "int256[]"
            },
            %{
              "internalType" => "bool[]",
              "name" => "bools",
              "type" => "bool[]"
            },
            %{
              "internalType" => "bytes[]",
              "name" => "byts",
              "type" => "bytes[]"
            },
            %{
              "internalType" => "string[]",
              "name" => "strings",
              "type" => "string[]"
            }
          ],
          "stateMutability" => "nonpayable",
          "type" => "constructor"
        }
      ],
      version: "v0.8.4+commit.c7e474f2",
      optimized: true,
      optimization_runs: 1,
      constructor_args:
        "00000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002a00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000756b5b30000000000000000000000000000000000000000000000000000000000000002000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000004fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb0000000000000000000000000000000000000000000000000000000000000006ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd8f0000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000371776500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003657771000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000097177657177657177650000000000000000000000000000000000000000000000"
    }
  end

  def address_hash do
    {:ok, address_hash} =
      "address_hash"
      |> sequence(& &1)
      |> Hash.Address.cast()

    if to_string(address_hash) == "0x0000000000000000000000000000000000000000" do
      address_hash()
    else
      address_hash
    end
  end

  def block_factory do
    %Block{
      consensus: true,
      number: block_number(),
      hash: block_hash(),
      parent_hash: block_hash(),
      nonce: sequence("block_nonce", & &1),
      miner: build(:address),
      difficulty: Enum.random(1..100_000),
      total_difficulty: Enum.random(1..100_000),
      size: Enum.random(1..100_000),
      gas_limit: Enum.random(1..100_000),
      gas_used: Enum.random(1..100_000),
      timestamp: DateTime.utc_now(),
      refetch_needed: false
    }
  end

  def contract_method_factory() do
    %ContractMethod{
      identifier: Base.decode16!("60fe47b1", case: :lower),
      abi: %{
        "constant" => false,
        "inputs" => [%{"name" => "x", "type" => "uint256"}],
        "name" => "set",
        "outputs" => [],
        "payable" => false,
        "stateMutability" => "nonpayable",
        "type" => "function"
      },
      type: "function"
    }
  end

  def block_hash do
    {:ok, block_hash} =
      "block_hash"
      |> sequence(& &1)
      |> Hash.Full.cast()

    block_hash
  end

  def block_number do
    sequence("block_number", & &1)
  end

  def block_second_degree_relation_factory do
    %Block.SecondDegreeRelation{
      uncle_hash: block_hash(),
      nephew: build(:block),
      index: 0
    }
  end

  def with_block(%Transaction{index: nil} = transaction) do
    with_block(transaction, insert(:block))
  end

  def with_block(transactions) when is_list(transactions) do
    block = insert(:block)
    with_block(transactions, block)
  end

  def with_block(%Transaction{} = transaction, %Block{} = block) do
    with_block(transaction, block, [])
  end

  # The `transaction.block` must be consensus.  Non-consensus blocks can only be associated with the
  # `transaction_forks`.
  def with_block(transactions, %Block{consensus: true} = block) when is_list(transactions) do
    Enum.map(transactions, &with_block(&1, block))
  end

  def with_block(%Transaction{index: nil} = transaction, collated_params) when is_list(collated_params) do
    block = insert(:block)
    with_block(transaction, block, collated_params)
  end

  def with_block(
        %Transaction{index: nil} = transaction,
        # The `transaction.block` must be consensus.  Non-consensus blocks can only be associated with the
        # `transaction_forks`.
        %Block{consensus: true, hash: block_hash, number: block_number},
        collated_params
      )
      when is_list(collated_params) do
    next_transaction_index = block_hash_to_next_transaction_index(block_hash)

    cumulative_gas_used = collated_params[:cumulative_gas_used] || Enum.random(21_000..100_000)
    gas_used = collated_params[:gas_used] || Enum.random(21_000..100_000)
    status = Keyword.get(collated_params, :status, Enum.random([:ok, :error]))

    error = (status == :error && collated_params[:error]) || nil

    transaction
    |> Transaction.changeset(%{
      block_hash: block_hash,
      block_number: block_number,
      cumulative_gas_used: cumulative_gas_used,
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.to_address_hash,
      error: error,
      gas_used: gas_used,
      index: next_transaction_index,
      status: status
    })
    |> Repo.update!()
    |> Repo.preload(:block)
  end

  def with_contract_creation(%Transaction{} = transaction, %Address{hash: contract_address_hash}) do
    transaction
    |> Transaction.changeset(%{
      created_contract_address_hash: contract_address_hash
    })
    |> Repo.update!()
  end

  def with_contract_creation(%InternalTransaction{} = internal_transaction, %Address{
        contract_code: contract_code,
        hash: contract_address_hash
      }) do
    internal_transaction
    |> InternalTransaction.changeset(%{
      contract_code: contract_code,
      created_contract_address_hash: contract_address_hash
    })
    |> Repo.update!()
  end

  def data(sequence_name) do
    unpadded =
      sequence_name
      |> sequence(& &1)
      |> Integer.to_string(16)

    unpadded_length = String.length(unpadded)

    padded =
      case rem(unpadded_length, 2) do
        0 -> unpadded
        1 -> "0" <> unpadded
      end

    {:ok, data} = Data.cast("0x#{padded}")

    data
  end

  def pending_block_operation_factory do
    %PendingBlockOperation{}
  end

  def internal_transaction_factory() do
    gas = Enum.random(21_000..100_000)
    gas_used = Enum.random(0..gas)

    %InternalTransaction{
      from_address: build(:address),
      to_address: build(:address),
      call_type: :delegatecall,
      gas: gas,
      gas_used: gas_used,
      input: %Data{bytes: <<1>>},
      output: %Data{bytes: <<2>>},
      # caller MUST supply `index`
      trace_address: [],
      # caller MUST supply `transaction` because it can't be built lazily to allow overrides without creating an extra
      # transaction
      # caller MUST supply `block_hash` (usually the same as the transaction's)
      # caller MUST supply `block_index`
      type: :call,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  def internal_transaction_create_factory() do
    gas = Enum.random(21_000..100_000)
    gas_used = Enum.random(0..gas)

    contract_code = Map.fetch!(contract_code_info(), :bytecode)

    %InternalTransaction{
      created_contract_code: contract_code,
      created_contract_address: build(:address, contract_code: contract_code),
      from_address: build(:address),
      gas: gas,
      gas_used: gas_used,
      # caller MUST supply `index`
      init: data(:internal_transaction_init),
      trace_address: [],
      # caller MUST supply `transaction` because it can't be built lazily to allow overrides without creating an extra
      # transaction
      # caller MUST supply `block_hash` (usually the same as the transaction's)
      # caller MUST supply `block_index`
      type: :create,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  def internal_transaction_selfdestruct_factory() do
    %InternalTransaction{
      from_address: build(:address),
      trace_address: [],
      # caller MUST supply `transaction` because it can't be built lazily to allow overrides without creating an extra
      # transaction
      type: :selfdestruct,
      value: sequence("internal_transaction_value", &Decimal.new(&1))
    }
  end

  def log_factory do
    block = build(:block)

    %Log{
      address: build(:address),
      block: block,
      block_number: block.number,
      data: data(:log_data),
      first_topic: nil,
      fourth_topic: nil,
      index: sequence("log_index", & &1),
      second_topic: nil,
      third_topic: nil,
      transaction: build(:transaction),
      type: sequence("0x")
    }
  end

  def token_factory do
    %Token{
      name: "Infinite Token",
      symbol: "IT",
      total_supply: 1_000_000_000,
      decimals: 18,
      contract_address: build(:address),
      type: "ERC-20",
      cataloged: true
    }
  end

  def unique_token_factory do
    Map.replace(token_factory(), :name, sequence("Infinite Token"))
  end

  def token_transfer_log_factory do
    token_contract_address = build(:address)
    to_address = build(:address)
    from_address = build(:address)

    transaction = build(:transaction, to_address: token_contract_address, from_address: from_address)

    log_params = %{
      first_topic: TokenTransfer.constant(),
      second_topic: zero_padded_address_hash_string(from_address.hash),
      third_topic: zero_padded_address_hash_string(to_address.hash),
      address_hash: token_contract_address.hash,
      address: nil,
      data: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
      transaction: transaction
    }

    build(:log, log_params)
  end

  def token_transfer_log_with_transaction(%Log{} = log, %Transaction{} = transaction) do
    params = %{
      second_topic: zero_padded_address_hash_string(transaction.from_address.hash),
      transaction: transaction
    }

    struct!(log, params)
  end

  def token_transfer_log_with_to_address(%Log{} = log, %Address{} = to_address) do
    %Log{log | third_topic: zero_padded_address_hash_string(to_address.hash)}
  end

  def token_transfer_factory do
    log = build(:token_transfer_log)
    to_address_hash = address_hash_from_zero_padded_hash_string(log.third_topic)
    from_address_hash = address_hash_from_zero_padded_hash_string(log.second_topic)

    # `to_address` is the only thing that isn't created from the token_transfer_log_factory
    to_address = build(:address, hash: to_address_hash)
    from_address = build(:address, hash: from_address_hash)
    contract_code = Map.fetch!(contract_code_info(), :bytecode)

    token_address = insert(:contract_address, contract_code: contract_code)
    insert(:token, contract_address: token_address)

    %TokenTransfer{
      block: build(:block),
      amount: Decimal.new(1),
      block_number: block_number(),
      from_address: from_address,
      to_address: to_address,
      token_contract_address: token_address,
      transaction: log.transaction,
      log_index: log.index
    }
  end

  def market_history_factory do
    %MarketHistory{
      closing_price: price(),
      opening_price: price(),
      date: Date.utc_today()
    }
  end

  def emission_reward_factory do
    # Generate ranges like 1 - 10,000; 10,001 - 20,000, 20,001 - 30,000; etc
    x = sequence("block_range", & &1)
    lower = x * Kernel.+(10_000, 1)
    upper = Kernel.+(lower, 9_999)

    wei_per_ether = Decimal.new(1_000_000_000_000_000_000)

    reward_multiplier =
      1..5
      |> Enum.random()
      |> Decimal.new()

    reward = Decimal.mult(reward_multiplier, wei_per_ether)

    %EmissionReward{
      block_range: %Range{from: lower, to: upper},
      reward: reward
    }
  end

  def reward_factory do
    %Reward{
      address_hash: build(:address).hash,
      address_type: :validator,
      block_hash: build(:block).hash,
      reward: Decimal.new(3)
    }
  end

  def transaction_factory do
    %Transaction{
      from_address: build(:address),
      gas: Enum.random(21_000..100_000),
      gas_price: Enum.random(10..99) * 1_000_000_00,
      hash: transaction_hash(),
      input: transaction_input(),
      nonce: Enum.random(1..1_000),
      r: sequence(:transaction_r, & &1),
      s: sequence(:transaction_s, & &1),
      to_address: build(:address),
      v: Enum.random(27..30),
      value: Enum.random(1..100_000)
    }
  end

  def transaction_to_verified_contract_factory do
    smart_contract = build(:smart_contract)

    address = %Address{
      hash: address_hash(),
      verified: true,
      contract_code: contract_code_info().bytecode,
      smart_contract: smart_contract
    }

    input_data =
      "set(uint)"
      |> ABI.encode([50])
      |> Base.encode16(case: :lower)

    build(:transaction, to_address: address, input: "0x" <> input_data)
  end

  def transaction_hash do
    {:ok, transaction_hash} =
      "transaction_hash"
      |> sequence(& &1)
      |> Hash.Full.cast()

    transaction_hash
  end

  def transaction_input do
    data(:transaction_input)
  end

  def transaction_fork_factory do
    %Transaction.Fork{
      hash: transaction_hash(),
      index: 0,
      uncle_hash: block_hash()
    }
  end

  def smart_contract_factory do
    contract_code_info = contract_code_info()

    {:ok, data} = Explorer.Chain.Data.cast(contract_code_info.bytecode)
    bytecode_md5 = Helper.contract_code_md5(data.bytes)

    %SmartContract{
      address_hash: insert(:address, contract_code: contract_code_info.bytecode, verified: true).hash,
      compiler_version: contract_code_info.version,
      name: contract_code_info.name,
      contract_source_code: contract_code_info.source_code,
      optimization: contract_code_info.optimized,
      abi: contract_code_info.abi,
      contract_code_md5: bytecode_md5,
      verified_via_sourcify: Enum.random([true, false]),
      is_vyper_contract: Enum.random([true, false])
    }
  end

  def unique_smart_contract_factory do
    Map.replace(smart_contract_factory(), :name, sequence("SimpleStorage"))
  end

  def decompiled_smart_contract_factory do
    contract_code_info = contract_code_info()

    %DecompiledSmartContract{
      address_hash: insert(:address, contract_code: contract_code_info.bytecode, decompiled: true).hash,
      decompiler_version: "test_decompiler",
      decompiled_source_code: contract_code_info.source_code
    }
  end

  def token_instance_factory do
    %Instance{
      token_contract_address_hash: insert(:token).contract_address_hash,
      token_id: sequence("token_id", & &1),
      metadata: %{key: "value"},
      error: nil
    }
  end

  def token_balance_factory do
    %TokenBalance{
      address: build(:address),
      token_contract_address_hash: insert(:token).contract_address_hash,
      block_number: block_number(),
      value: Enum.random(1..100_000),
      value_fetched_at: DateTime.utc_now(),
      token_type: "ERC-20"
    }
  end

  def address_coin_balance_factory do
    %CoinBalance{
      address: insert(:address),
      block_number: insert(:block).number,
      value: Enum.random(1..100_000_000),
      value_fetched_at: DateTime.utc_now()
    }
  end

  def address_current_token_balance_factory do
    %CurrentTokenBalance{
      address: build(:address),
      token_contract_address_hash: insert(:token).contract_address_hash,
      block_number: block_number(),
      value: Enum.random(1..100_000),
      value_fetched_at: DateTime.utc_now()
    }
  end

  def address_current_token_balance_with_token_id_factory do
    {token_type, token_id} = Enum.random([{"ERC-20", nil}, {"ERC-721", nil}, {"ERC-1155", Enum.random(1..100_000)}])

    %CurrentTokenBalance{
      address: build(:address),
      token_contract_address_hash: insert(:token).contract_address_hash,
      block_number: block_number(),
      value: Enum.random(1..100_000),
      value_fetched_at: DateTime.utc_now(),
      token_id: token_id,
      token_type: token_type
    }
  end

  defp block_hash_to_next_transaction_index(block_hash) do
    import Kernel, except: [+: 2]

    Repo.one!(
      from(
        transaction in Transaction,
        select: coalesce(max(transaction.index), -1) + 1,
        where: transaction.block_hash == ^block_hash
      )
    )
  end

  defp price do
    1..10_000
    |> Enum.random()
    |> Decimal.new()
    |> Decimal.div(Decimal.new(100))
  end

  defp zero_padded_address_hash_string(%Explorer.Chain.Hash{byte_count: 20} = hash) do
    "0x" <> hash_string = Explorer.Chain.Hash.to_string(hash)
    "0x000000000000000000000000" <> hash_string
  end

  defp address_hash_from_zero_padded_hash_string("0x000000000000000000000000" <> hash_string) do
    {:ok, hash} = Explorer.Chain.Hash.cast(Explorer.Chain.Hash.Address, "0x" <> hash_string)
    hash
  end

  def user_factory do
    username = sequence("user", &"user#{&1}")

    %User{
      username: username,
      password_hash: Bcrypt.hash_pwd_salt("password"),
      contacts: [
        %UserContact{
          email: "#{username}@blockscout",
          primary: true,
          verified: true
        }
      ]
    }
  end

  def administrator_factory do
    %Administrator{
      role: "owner",
      user: build(:user)
    }
  end

  def missing_block_range_factory do
    %MissingBlockRange{
      from_number: 1,
      to_number: 0
    }
  end

  def random_bool, do: Enum.random([true, false])
end
