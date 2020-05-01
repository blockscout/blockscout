defmodule Explorer.SmartContract.Verifier.ConstructorArgumentsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.Data
  alias Explorer.SmartContract.Verifier.ConstructorArguments

  describe "verify/3" do
    test "veriies constructor constructor arguments with whisper data" do
      constructor_arguments = Base.encode16(:crypto.strong_rand_bytes(64), case: :lower)
      address = insert(:address)

      input =
        "a165627a7a72305820" <>
          Base.encode16(:crypto.strong_rand_bytes(32), case: :lower) <> "0029" <> constructor_arguments

      input_data = %Data{
        bytes: Base.decode16!(input, case: :lower)
      }

      :transaction
      |> insert(created_contract_address_hash: address.hash, input: input_data)
      |> with_block()

      assert ConstructorArguments.verify(address.hash, "", constructor_arguments, "", "")
    end

    test "verifies with multiple nested constructor arguments" do
      address = insert(:address)

      constructor_arguments =
        "000000000000000000000000314159265dd8dbb310642f98f50c066173c1259b93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae00000000000000000000000000000000000000000000000000000000590b09b0"

      input =
        "a165627a7a72305820fbfa6f8a2024760ef0e0eb29a332c9a820526e92f8b4fbcce6f00c7643234b1400297b6c4b278d165a6b33958f8ea5dfb00c8c9d4d0acf1985bef5d10786898bc3e7a165627a7a723058203c2db82e7c80cd1e371fe349b03d49b812c324ba4a3fcd063b7bc2662353c5de0029000000000000000000000000314159265dd8dbb310642f98f50c066173c1259b93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae00000000000000000000000000000000000000000000000000000000590b09b0"

      input_data = %Data{
        bytes: Base.decode16!(input, case: :lower)
      }

      :transaction
      |> insert(created_contract_address_hash: address.hash, input: input_data)
      |> with_block()

      assert ConstructorArguments.verify(address.hash, "", constructor_arguments, "", "")
    end

    test "verifies older version of Solidity where constructor_arguments were directly appended to source code" do
      address = insert(:address)

      constructor_arguments =
        "000000000000000000000000314159265dd8dbb310642f98f50c066173c1259b93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae00000000000000000000000000000000000000000000000000000000590b09b0"

      source_code = "0001"

      input = source_code <> constructor_arguments

      input_data = %Data{
        bytes: Base.decode16!(input, case: :lower)
      }

      :transaction
      |> insert(created_contract_address_hash: address.hash, input: input_data)
      |> with_block()

      assert ConstructorArguments.verify(address.hash, source_code, constructor_arguments, "", "")
    end

    test "verifies with require messages" do
      address = insert(:address)

      source_code = """
        pragma solidity ^0.5.8;

        contract ValidatorProxy {
            mapping(address => bool) public isValidator;
            address public systemAddress = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;
            address[] public validators;

            constructor(address[] memory _validators) public {
                validators = _validators;

                for (uint i = 0; i < _validators.length; i++) {
                    isValidator[_validators[i]] = true;
                }
            }

            function updateValidators(address[] memory newValidators) public {
                require(
                    tx.origin == systemAddress, // solium-disable-line security/no-tx-origin
                    "Only the system address can be responsible for the call of this function."
                );

                for (uint i = 0; i < validators.length; i++) {
                    isValidator[validators[i]] = false;
                }

                for (uint i = 0; i < newValidators.length; i++) {
                    isValidator[newValidators[i]] = true;
                }

                validators = newValidators;
            }

            function numberOfValidators() public view returns (uint) {
                return validators.length;
            }

            function getValidators() public view returns (address[] memory) {
                return validators;
            }
        }


        contract HomeBridge {
            struct TransferState {
                mapping(address => bool) isConfirmedByValidator;
                address[] confirmingValidators;
                bool isCompleted;
            }

            event Confirmation(
                bytes32 transferHash,
                bytes32 transactionHash,
                uint256 amount,
                address recipient,
                address indexed validator
            );
            event TransferCompleted(
                bytes32 transferHash,
                bytes32 transactionHash,
                uint256 amount,
                address recipient,
                bool coinTransferSuccessful
            );

            mapping(bytes32 => TransferState) public transferState;
            ValidatorProxy public validatorProxy;
            uint public validatorsRequiredPercent;

            constructor(ValidatorProxy _proxy, uint _validatorsRequiredPercent) public {
                require(
                    address(_proxy) != address(0),
                    "proxy must not be the zero address!"
                );
                require(
                    _validatorsRequiredPercent >= 0 &&
                        _validatorsRequiredPercent <= 100,
                    "_validatorsRequiredPercent must be between 0 and 100"
                );
                validatorProxy = _proxy;
                validatorsRequiredPercent = _validatorsRequiredPercent;
            }

            function fund() external payable {}

            function confirmTransfer(
                bytes32 transferHash,
                bytes32 transactionHash,
                uint256 amount,
                address payable recipient
            ) public {
                // We compute a keccak hash for the transfer and use that as an identifier for the transfer
                bytes32 transferStateId = keccak256(
                    abi.encodePacked(transferHash, transactionHash, amount, recipient)
                );

                require(
                    !transferState[transferStateId].isCompleted,
                    "transfer already completed"
                );

                require(
                    validatorProxy.isValidator(msg.sender),
                    "must be validator to confirm transfers"
                );

                require(
                    recipient != address(0),
                    "recipient must not be the zero address!"
                );

                require(amount > 0, "amount must not be zero");

                if (_confirmTransfer(transferStateId, msg.sender)) {
                    // We have to emit the events here, because _confirmTransfer
                    // doesn't even receive the necessary information to do it on
                    // its own

                    emit Confirmation(
                        transferHash,
                        transactionHash,
                        amount,
                        recipient,
                        msg.sender
                    );
                }

                if (_requiredConfirmationsReached(transferStateId)) {
                    transferState[transferStateId].isCompleted = true;
                    delete transferState[transferStateId].confirmingValidators;
                    bool coinTransferSuccessful = recipient.send(amount);
                    emit TransferCompleted(
                        transferHash,
                        transactionHash,
                        amount,
                        recipient,
                        coinTransferSuccessful
                    );
                }
            }

            // check if a 2nd confirmTransfer would complete a transfer. this
            // can happen after validator set changes.
            function reconfirmCompletesTransfer(
                bytes32 transferHash,
                bytes32 transactionHash,
                uint256 amount,
                address payable recipient
            ) public view returns (bool) {
                require(
                    recipient != address(0),
                    "recipient must not be the zero address!"
                );
                require(amount > 0, "amount must not be zero");

                // We compute a keccak hash for the transfer and use that as an identifier for the transfer
                bytes32 transferStateId = keccak256(
                    abi.encodePacked(transferHash, transactionHash, amount, recipient)
                );

                require(
                    !transferState[transferStateId].isCompleted,
                    "transfer already completed"
                );

                address[] storage confirmingValidators = transferState[transferStateId]
                    .confirmingValidators;
                uint numConfirming = 0;
                for (uint i = 0; i < confirmingValidators.length; i++) {
                    if (validatorProxy.isValidator(confirmingValidators[i])) {
                        numConfirming += 1;
                    }
                }
                return numConfirming >= _getNumRequiredConfirmations();
            }

            function _purgeConfirmationsFromExValidators(bytes32 transferStateId)
                internal
            {
                address[] storage confirmingValidators = transferState[transferStateId]
                    .confirmingValidators;

                uint i = 0;
                while (i < confirmingValidators.length) {
                    if (validatorProxy.isValidator(confirmingValidators[i])) {
                        i++;
                    } else {
                        confirmingValidators[i] = confirmingValidators[confirmingValidators
                                .length -
                            1];
                        confirmingValidators.length--;
                    }
                }
            }

            function _getNumRequiredConfirmations() internal view returns (uint) {
                return
                    (
                            validatorProxy.numberOfValidators() *
                                validatorsRequiredPercent +
                                99
                        ) /
                        100;
            }

            function _confirmTransfer(bytes32 transferStateId, address validator)
                internal
                returns (bool)
            {
                if (transferState[transferStateId].isConfirmedByValidator[validator]) {
                    return false;
                }

                transferState[transferStateId].isConfirmedByValidator[validator] = true;
                transferState[transferStateId].confirmingValidators.push(validator);

                return true;
            }

            function _requiredConfirmationsReached(bytes32 transferStateId)
                internal
                returns (bool)
            {
                uint numRequired = _getNumRequiredConfirmations();

                /* We now check if we have enough confirmations.  If that is the
                  case, we purge ex-validators from the list of confirmations
                  and do the check again, so we do not count
                  confirmations from ex-validators.

                  This means that old confirmations stay valid over validator set changes given
                  that the validator doesn't lose its validator status.

                  The double check is here to save some gas. If checking the validator
                  status for all confirming validators becomes too costly, we can introduce
                  a 'serial number' for the validator set changes and determine if there
                  was a change of the validator set between the first confirmation
                  and the last confirmation and skip calling into
                  _purgeConfirmationsFromExValidators if there were no changes.
                */

                if (
                    transferState[transferStateId].confirmingValidators.length <
                    numRequired
                ) {
                    return false;
                }

                _purgeConfirmationsFromExValidators(transferStateId);

                if (
                    transferState[transferStateId].confirmingValidators.length <
                    numRequired
                ) {
                    return false;
                }

                return true;
            }
        }
      """

      constructor_arguments =
        "000000000000000000000000fb5a36f0e12cef9f88d95f0e02cad4ba183336dc0000000000000000000000000000000000000000000000000000000000000032"

      # dirty one: "5f76616c696461746f7273526571756972656450657263656e74206d757374206265206265747765656e203020616e642031303070726f7879206d757374206e6f7420626520746865207a65726f206164647265737321000000000000000000000000fb5a36f0e12cef9f88d95f0e02cad4ba183336dc0000000000000000000000000000000000000000000000000000000000000032"

      input =
        "608060405234801561001057600080fd5b50604051604080610ebb8339810180604052604081101561003057600080fd5b5080516020909101516001600160a01b038216610098576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526023815260200180610e986023913960400191505060405180910390fd5b60648111156100f2576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526034815260200180610e646034913960400191505060405180910390fd5b600180546001600160a01b0319166001600160a01b039390931692909217909155600255610d3f806101256000396000f3fe6080604052600436106100655760003560e01c8063397bc64111610043578063397bc64114610135578063b60d42881461015f578063f176cde71461016957610065565b806305dab2881461006a5780630b1ec76014610091578063236459c7146100cf575b600080fd5b34801561007657600080fd5b5061007f6101bb565b60408051918252519081900360200190f35b34801561009d57600080fd5b506100a66101c1565b6040805173ffffffffffffffffffffffffffffffffffffffff9092168252519081900360200190f35b3480156100db57600080fd5b50610121600480360360808110156100f257600080fd5b508035906020810135906040810135906060013573ffffffffffffffffffffffffffffffffffffffff166101dd565b604080519115158252519081900360200190f35b34801561014157600080fd5b506101216004803603602081101561015857600080fd5b5035610484565b61016761049c565b005b34801561017557600080fd5b506101676004803603608081101561018c57600080fd5b508035906020810135906040810135906060013573ffffffffffffffffffffffffffffffffffffffff1661049e565b60025481565b60015473ffffffffffffffffffffffffffffffffffffffff1681565b600073ffffffffffffffffffffffffffffffffffffffff821661024b576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526027815260200180610cc76027913960400191505060405180910390fd5b600083116102ba57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601760248201527f616d6f756e74206d757374206e6f74206265207a65726f000000000000000000604482015290519081900360640190fd5b604080516020808201889052818301879052606080830187905273ffffffffffffffffffffffffffffffffffffffff8616901b608083015282516074818403018152609490920183528151918101919091206000818152918290529190206002015460ff161561038b57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f7472616e7366657220616c726561647920636f6d706c65746564000000000000604482015290519081900360640190fd5b600081815260208190526040812060010190805b825481101561046e57600154835473ffffffffffffffffffffffffffffffffffffffff9091169063facd743b908590849081106103d857fe5b600091825260209182902001546040805163ffffffff851660e01b815273ffffffffffffffffffffffffffffffffffffffff90921660048301525160248083019392829003018186803b15801561042e57600080fd5b505afa158015610442573d6000803e3d6000fd5b505050506040513d602081101561045857600080fd5b505115610466576001820191505b60010161039f565b506104776108a7565b1115979650505050505050565b60006020819052908152604090206002015460ff1681565b565b604080516020808201879052818301869052606080830186905273ffffffffffffffffffffffffffffffffffffffff8516901b608083015282516074818403018152609490920183528151918101919091206000818152918290529190206002015460ff161561056f57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f7472616e7366657220616c726561647920636f6d706c65746564000000000000604482015290519081900360640190fd5b600154604080517ffacd743b000000000000000000000000000000000000000000000000000000008152336004820152905173ffffffffffffffffffffffffffffffffffffffff9092169163facd743b91602480820192602092909190829003018186803b1580156105e057600080fd5b505afa1580156105f4573d6000803e3d6000fd5b505050506040513d602081101561060a57600080fd5b5051610661576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526026815260200180610cee6026913960400191505060405180910390fd5b73ffffffffffffffffffffffffffffffffffffffff82166106cd576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526027815260200180610cc76027913960400191505060405180910390fd5b6000831161073c57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601760248201527f616d6f756e74206d757374206e6f74206265207a65726f000000000000000000604482015290519081900360640190fd5b6107468133610954565b156107ab57604080518681526020810186905280820185905273ffffffffffffffffffffffffffffffffffffffff84166060820152905133917fdee96a12459a8c17d4cf9571d9ab18de19fa1055adff514e2d25595382d218df919081900360800190a25b6107b481610a35565b156108a05760008181526020819052604081206002810180547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016600190811790915561080392910190610c67565b60405160009073ffffffffffffffffffffffffffffffffffffffff84169085156108fc0290869084818181858888f1604080518c8152602081018c90528082018b905273ffffffffffffffffffffffffffffffffffffffff8a166060820152821515608082015290519196507f546c8621785b0cc9f951c75b68621fbdfce93ba6df3943b1271813c3598852d1955081900360a0019350915050a1505b5050505050565b60006064600254600160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663d6832ea96040518163ffffffff1660e01b815260040160206040518083038186803b15801561091657600080fd5b505afa15801561092a573d6000803e3d6000fd5b505050506040513d602081101561094057600080fd5b5051026063018161094d57fe5b0490505b90565b60008281526020818152604080832073ffffffffffffffffffffffffffffffffffffffff8516845290915281205460ff161561099257506000610a2f565b5060008281526020818152604080832073ffffffffffffffffffffffffffffffffffffffff851680855281845291842080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00166001908117909155848452908101805480830182559085529290932090910180547fffffffffffffffffffffffff00000000000000000000000000000000000000001690911790555b92915050565b600080610a406108a7565b600084815260208190526040902060010154909150811115610a66576000915050610a98565b610a6f83610a9d565b600083815260208190526040902060010154811115610a92576000915050610a98565b60019150505b919050565b6000818152602081905260408120600101905b8154811015610c6257600154825473ffffffffffffffffffffffffffffffffffffffff9091169063facd743b90849084908110610ae957fe5b600091825260209182902001546040805163ffffffff851660e01b815273ffffffffffffffffffffffffffffffffffffffff90921660048301525160248083019392829003018186803b158015610b3f57600080fd5b505afa158015610b53573d6000803e3d6000fd5b505050506040513d6020811015610b6957600080fd5b505115610b7857600101610c5d565b815482907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8101908110610ba857fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16828281548110610bdf57fe5b600091825260209091200180547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff929092169190911790558154610c5b837fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8301610c88565b505b610ab0565b505050565b5080546000825590600052602060002090810190610c859190610ca8565b50565b815481835581811115610c6257600083815260209020610c629181019083015b61095191905b80821115610cc25760008155600101610cae565b509056fe726563697069656e74206d757374206e6f7420626520746865207a65726f2061646472657373216d7573742062652076616c696461746f7220746f20636f6e6669726d207472616e7366657273a165627a7a7230582050f9daa0f47602e3462444b6fc1dc592b21ec7e054969a8a5a1846570c2570cc00295f76616c696461746f7273526571756972656450657263656e74206d757374206265206265747765656e203020616e642031303070726f7879206d757374206e6f7420626520746865207a65726f206164647265737321000000000000000000000000fb5a36f0e12cef9f88d95f0e02cad4ba183336dc0000000000000000000000000000000000000000000000000000000000000032"

      input_data = %Data{
        bytes: Base.decode16!(input, case: :lower)
      }

      :transaction
      |> insert(created_contract_address_hash: address.hash, input: input_data)
      |> with_block()

      assert ConstructorArguments.verify(address.hash, input, constructor_arguments, source_code, "HomeBridge")
    end

    test "get require messages from constructor" do
      contract_source_code = """
      pragma solidity 0.6.1;


      contract HomeBridge {
          uint public validatorsRequiredPercent;

          constructor(address _proxy, uint256 _validatorsRequiredPercent) public {
              require       (
                  address(_proxy) != address(0),



                  "proxy must not be the zero address!"
              );


              require(
                  _validatorsRequiredPercent >= 0 &&
                      _validatorsRequiredPercent <= 100,
                  "_validatorsRequiredPercent must be between 0 and 100"
              );
              validatorsRequiredPercent = _validatorsRequiredPercent;
          }
      }
      """

      result = ConstructorArguments.extract_require_messages_from_constructor(contract_source_code, "HomeBridge")

      assert result == [
               "70726f7879206d757374206e6f7420626520746865207a65726f206164647265737321",
               "5f76616c696461746f7273526571756972656450657263656e74206d757374206265206265747765656e203020616e6420313030"
             ]
    end

    test "get require messages with a single quote from constructor" do
      contract_source_code = """
      pragma solidity 0.6.1;


      contract HomeBridge {
          uint public validatorsRequiredPercent;

          constructor(address _proxy, uint256 _validatorsRequiredPercent) public {


              require(
                  _validatorsRequiredPercent >= 0 &&
                      _validatorsRequiredPercent <= 100,
                  '_validatorsRequiredPercent must be between 0 and 100'
              );
              validatorsRequiredPercent = _validatorsRequiredPercent;
          }
      }
      """

      result = ConstructorArguments.extract_require_messages_from_constructor(contract_source_code, "HomeBridge")

      assert result == [
               "5f76616c696461746f7273526571756972656450657263656e74206d757374206265206265747765656e203020616e6420313030"
             ]
    end

    test "get require messages with different quotes inside from constructor" do
      contract_source_code = """
      pragma solidity 0.6.1;


      contract HomeBridge {
          uint public validatorsRequiredPercent;

          constructor(uint256 _validatorsRequiredPercent) public {


              require(
                  _validatorsRequiredPercent >= 0 &&
                      _validatorsRequiredPercent <= 100,
                  "_val\"idatorsReq'uiredPercent must be ' between \" 0 and 100"
              );
              validatorsRequiredPercent = _validatorsRequiredPercent;
          }
      }
      """

      result = ConstructorArguments.extract_require_messages_from_constructor(contract_source_code, "HomeBridge")

      assert result == [
               "5f76616c22696461746f727352657127756972656450657263656e74206d7573742062652027206265747765656e2022203020616e6420313030"
             ]
    end

    test "get empty require messages from constructor with require without message" do
      contract_source_code = """
      pragma solidity 0.6.1;


      contract HomeBridge {
          uint public validatorsRequiredPercent;

          constructor(uint256 _validatorsRequiredPercent) public {


              require(
                  _validatorsRequiredPercent >= 0 &&
                      _validatorsRequiredPercent <= 100
              );
              validatorsRequiredPercent = _validatorsRequiredPercent;
          }
      }
      """

      result = ConstructorArguments.extract_require_messages_from_constructor(contract_source_code, "HomeBridge")

      assert result == []
    end

    test "get empty require messages from constructor" do
      contract_source_code = """
      pragma solidity 0.6.1;


      contract HomeBridge {
          uint public validatorsRequiredPercent;

          constructor(address _proxy, uint256 _validatorsRequiredPercent) public {
              validatorsRequiredPercent = _validatorsRequiredPercent;
          }
      }
      """

      result = ConstructorArguments.extract_require_messages_from_constructor(contract_source_code, "HomeBridge")

      assert result == []
    end
  end

  test "get empty require messages if no constructor" do
    contract_source_code = """
    pragma solidity 0.6.1;


    contract HomeBridge {
        uint public validatorsRequiredPercent;

    }
    """

    result = ConstructorArguments.extract_require_messages_from_constructor(contract_source_code, "HomeBridge")

    assert result == []
  end

  test "returns purified constructor arguments" do
    contract_source_code = """
    pragma solidity 0.6.1;


    contract HomeBridge {
        uint public validatorsRequiredPercent;

        constructor(address _proxy, uint256 _validatorsRequiredPercent) public {
            require       (
                address(_proxy) != address(0),



                "proxy must not be the zero address!"
            );


            require(
                _validatorsRequiredPercent >= 0 &&
                    _validatorsRequiredPercent <= 100,
                "_validatorsRequiredPercent must be between 0 and 100"
            );
            validatorsRequiredPercent = _validatorsRequiredPercent;
        }
    }
    """

    dirty_constructor_arguments =
      "5f76616c696461746f7273526571756972656450657263656e74206d757374206265206265747765656e203020616e642031303070726f7879206d757374206e6f7420626520746865207a65726f206164647265737321000000000000000000000000fb5a36f0e12cef9f88d95f0e02cad4ba183336dc0000000000000000000000000000000000000000000000000000000000000032"

    result =
      ConstructorArguments.remove_require_messages_from_constructor_arguments(
        contract_source_code,
        dirty_constructor_arguments,
        "HomeBridge"
      )

    assert result ==
             "000000000000000000000000fb5a36f0e12cef9f88d95f0e02cad4ba183336dc0000000000000000000000000000000000000000000000000000000000000032"
  end

  test "didn't replace text param if it is the same as message in require" do
    contract_source_code = """
    pragma solidity 0.5.11;


      contract HomeBridge {
          string public param;
          uint public param2;

          constructor(string memory test, uint test2) public {
              require(
                  test2 != 0,

                  "proxy must not be the zero address!"
              );

              param = test;
              param2 = test2;
          }
      }
    """

    dirty_constructor_arguments =
      "70726f7879206d757374206e6f7420626520746865207a65726f2061646472657373210000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000002d000000000000000000000000000000000000000000000000000000000000002370726f7879206d757374206e6f7420626520746865207a65726f2061646472657373210000000000000000000000000000000000000000000000000000000000"

    result =
      ConstructorArguments.remove_require_messages_from_constructor_arguments(
        contract_source_code,
        dirty_constructor_arguments,
        "HomeBridge"
      )

    # Arg [0] (string) : 70726f7879206d757374206e6f7420626520746865207a65726f206164647265737321
    # Arg [1] (uint256) : 45
    assert result ==
             "0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000002d000000000000000000000000000000000000000000000000000000000000002370726f7879206d757374206e6f7420626520746865207a65726f2061646472657373210000000000000000000000000000000000000000000000000000000000"
  end

  test "returns the same constructor arguments if no matches in require hexed messages" do
    contract_source_code = """
    pragma solidity 0.6.1;


    contract HomeBridge {
        uint public validatorsRequiredPercent;

        constructor(address _proxy, uint256 _validatorsRequiredPercent) public {
            require       (
                address(_proxy) != address(0),



                "proxy must not be the zero address!"
            );


            require(
                _validatorsRequiredPercent >= 0 &&
                    _validatorsRequiredPercent <= 100,
                "_validatorsRequiredPercent must be between 0 and 100"
            );
            validatorsRequiredPercent = _validatorsRequiredPercent;
        }
    }
    """

    dirty_constructor_arguments =
      "4f76616c696461746f7273526571756972656450657263656e74206d757374206265206265747765656e203020616e642031303070726f7879206d757374206e6f7420626520746864207a65726f206164647265737321000000000000000000000000fb5a36f0e12cef9f88d95f0e02cad4ba183336dc0000000000000000000000000000000000000000000000000000000000000032"

    result =
      ConstructorArguments.remove_require_messages_from_constructor_arguments(
        contract_source_code,
        dirty_constructor_arguments,
        "HomeBridge"
      )

    assert result ==
             "4f76616c696461746f7273526571756972656450657263656e74206d757374206265206265747765656e203020616e642031303070726f7879206d757374206e6f7420626520746864207a65726f206164647265737321000000000000000000000000fb5a36f0e12cef9f88d95f0e02cad4ba183336dc0000000000000000000000000000000000000000000000000000000000000032"
  end
end
