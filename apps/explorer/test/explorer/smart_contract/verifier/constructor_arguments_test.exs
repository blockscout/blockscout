defmodule Explorer.SmartContract.Verifier.ConstructorArgumentsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.Data
  alias Explorer.SmartContract.Verifier.ConstructorArguments

  describe "verify/3" do
    test "verifies constructor constructor arguments with whisper data" do
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

    test "verifies with string in keccak256" do
      address = insert(:address)

      source_code = """
      /**
      *Submitted for verification at Etherscan.io on 2020-04-14
      */

      pragma solidity 0.5.10;

      /**
      * @dev Collection of functions related to the address type,
      */
      library Address {
         /**
          * @dev Returns true if `account` is a contract.
          *
          * This test is non-exhaustive, and there may be false-negatives: during the
          * execution of a contract's constructor, its address will be reported as
          * not containing a contract.
          *
          * > It is unsafe to assume that an address for which this function returns
          * false is an externally-owned account (EOA) and not a contract.
          */
         function isContract(address account) internal view returns (bool) {
             // This method relies in extcodesize, which returns 0 for contracts in
             // construction, since the code is only stored at the end of the
             // constructor execution.

             uint256 size;
             // solhint-disable-next-line no-inline-assembly
             assembly { size := extcodesize(account) }
             return size > 0;
         }
      }


      interface IDistribution {
         function supply() external view returns(uint256);
         function poolAddress(uint8) external view returns(address);
      }



      contract Sacrifice {
         constructor(address payable _recipient) public payable {
             selfdestruct(_recipient);
         }
      }


      interface IERC677MultiBridgeToken {
         function transfer(address _to, uint256 _value) external returns (bool);
         function transferDistribution(address _to, uint256 _value) external returns (bool);
         function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
         function balanceOf(address _account) external view returns (uint256);
      }







      /**
      * @dev Contract module which provides a basic access control mechanism, where
      * there is an account (an owner) that can be granted exclusive access to
      * specific functions.
      *
      * This module is used through inheritance. It will make available the modifier
      * `onlyOwner`, which can be aplied to your functions to restrict their use to
      * the owner.
      */
      contract Ownable {
         address private _owner;

         event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

         /**
          * @dev Initializes the contract setting the deployer as the initial owner.
          */
         constructor () internal {
             _owner = msg.sender;
             emit OwnershipTransferred(address(0), _owner);
         }

         /**
          * @dev Returns the address of the current owner.
          */
         function owner() public view returns (address) {
             return _owner;
         }

         /**
          * @dev Throws if called by any account other than the owner.
          */
         modifier onlyOwner() {
             require(isOwner(), "Ownable: caller is not the owner");
             _;
         }

         /**
          * @dev Returns true if the caller is the current owner.
          */
         function isOwner() public view returns (bool) {
             return msg.sender == _owner;
         }

         /**
          * @dev Leaves the contract without owner. It will not be possible to call
          * `onlyOwner` functions anymore. Can only be called by the current owner.
          *
          * > Note: Renouncing ownership will leave the contract without an owner,
          * thereby removing any functionality that is only available to the owner.
          */
         function renounceOwnership() public onlyOwner {
             emit OwnershipTransferred(_owner, address(0));
             _owner = address(0);
         }

         /**
          * @dev Transfers ownership of the contract to a new account (`newOwner`).
          * Can only be called by the current owner.
          */
         function transferOwnership(address newOwner) public onlyOwner {
             _transferOwnership(newOwner);
         }

         /**
          * @dev Transfers ownership of the contract to a new account (`newOwner`).
          */
         function _transferOwnership(address newOwner) internal {
             require(newOwner != address(0), "Ownable: new owner is the zero address");
             emit OwnershipTransferred(_owner, newOwner);
             _owner = newOwner;
         }
      }





      /**
      * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
      * the optional functions; to access them see `ERC20Detailed`.
      */
      interface IERC20 {
         /**
          * @dev Returns the amount of tokens in existence.
          */
         function totalSupply() external view returns (uint256);

         /**
          * @dev Returns the amount of tokens owned by `account`.
          */
         function balanceOf(address account) external view returns (uint256);

         /**
          * @dev Moves `amount` tokens from the caller's account to `recipient`.
          *
          * Returns a boolean value indicating whether the operation succeeded.
          *
          * Emits a `Transfer` event.
          */
         function transfer(address recipient, uint256 amount) external returns (bool);

         /**
          * @dev Returns the remaining number of tokens that `spender` will be
          * allowed to spend on behalf of `owner` through `transferFrom`. This is
          * zero by default.
          *
          * This value changes when `approve` or `transferFrom` are called.
          */
         function allowance(address owner, address spender) external view returns (uint256);

         /**
          * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
          *
          * Returns a boolean value indicating whether the operation succeeded.
          *
          * > Beware that changing an allowance with this method brings the risk
          * that someone may use both the old and the new allowance by unfortunate
          * transaction ordering. One possible solution to mitigate this race
          * condition is to first reduce the spender's allowance to 0 and set the
          * desired value afterwards:
          * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
          *
          * Emits an `Approval` event.
          */
         function approve(address spender, uint256 amount) external returns (bool);

         /**
          * @dev Moves `amount` tokens from `sender` to `recipient` using the
          * allowance mechanism. `amount` is then deducted from the caller's
          * allowance.
          *
          * Returns a boolean value indicating whether the operation succeeded.
          *
          * Emits a `Transfer` event.
          */
         function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

         /**
          * @dev Emitted when `value` tokens are moved from one account (`from`) to
          * another (`to`).
          *
          * Note that `value` may be zero.
          */
         event Transfer(address indexed from, address indexed to, uint256 value);

         /**
          * @dev Emitted when the allowance of a `spender` for an `owner` is set by
          * a call to `approve`. `value` is the new allowance.
          */
         event Approval(address indexed owner, address indexed spender, uint256 value);
      }



      /**
      * @dev Wrappers over Solidity's arithmetic operations with added overflow
      * checks.
      *
      * Arithmetic operations in Solidity wrap on overflow. This can easily result
      * in bugs, because programmers usually assume that an overflow raises an
      * error, which is the standard behavior in high level programming languages.
      * `SafeMath` restores this intuition by reverting the transaction when an
      * operation overflows.
      *
      * Using this library instead of the unchecked operations eliminates an entire
      * class of bugs, so it's recommended to use it always.
      */
      library SafeMath {
         /**
          * @dev Returns the addition of two unsigned integers, reverting on
          * overflow.
          *
          * Counterpart to Solidity's `+` operator.
          *
          * Requirements:
          * - Addition cannot overflow.
          */
         function add(uint256 a, uint256 b) internal pure returns (uint256) {
             uint256 c = a + b;
             require(c >= a, "SafeMath: addition overflow");

             return c;
         }

         /**
          * @dev Returns the subtraction of two unsigned integers, reverting on
          * overflow (when the result is negative).
          *
          * Counterpart to Solidity's `-` operator.
          *
          * Requirements:
          * - Subtraction cannot overflow.
          */
         function sub(uint256 a, uint256 b) internal pure returns (uint256) {
             require(b <= a, "SafeMath: subtraction overflow");
             uint256 c = a - b;

             return c;
         }

         /**
          * @dev Returns the multiplication of two unsigned integers, reverting on
          * overflow.
          *
          * Counterpart to Solidity's `*` operator.
          *
          * Requirements:
          * - Multiplication cannot overflow.
          */
         function mul(uint256 a, uint256 b) internal pure returns (uint256) {
             // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
             // benefit is lost if 'b' is also tested.
             // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
             if (a == 0) {
                 return 0;
             }

             uint256 c = a * b;
             require(c / a == b, "SafeMath: multiplication overflow");

             return c;
         }

         /**
          * @dev Returns the integer division of two unsigned integers. Reverts on
          * division by zero. The result is rounded towards zero.
          *
          * Counterpart to Solidity's `/` operator. Note: this function uses a
          * `revert` opcode (which leaves remaining gas untouched) while Solidity
          * uses an invalid opcode to revert (consuming all remaining gas).
          *
          * Requirements:
          * - The divisor cannot be zero.
          */
         function div(uint256 a, uint256 b) internal pure returns (uint256) {
             // Solidity only automatically asserts when dividing by 0
             require(b > 0, "SafeMath: division by zero");
             uint256 c = a / b;
             // assert(a == b * c + a % b); // There is no case in which this doesn't hold

             return c;
         }

         /**
          * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
          * Reverts when dividing by zero.
          *
          * Counterpart to Solidity's `%` operator. This function uses a `revert`
          * opcode (which leaves remaining gas untouched) while Solidity uses an
          * invalid opcode to revert (consuming all remaining gas).
          *
          * Requirements:
          * - The divisor cannot be zero.
          */
         function mod(uint256 a, uint256 b) internal pure returns (uint256) {
             require(b != 0, "SafeMath: modulo by zero");
             return a % b;
         }
      }



      /**
      * @title SafeERC20
      * @dev Wrappers around ERC20 operations that throw on failure (when the token
      * contract returns false). Tokens that return no value (and instead revert or
      * throw on failure) are also supported, non-reverting calls are assumed to be
      * successful.
      * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
      * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
      */
      library SafeERC20 {
         using SafeMath for uint256;
         using Address for address;

         function safeTransfer(IERC20 token, address to, uint256 value) internal {
             callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
         }

         function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
             callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
         }

         function safeApprove(IERC20 token, address spender, uint256 value) internal {
             // safeApprove should only be called when setting an initial allowance,
             // or when resetting it to zero. To increase and decrease it, use
             // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
             // solhint-disable-next-line max-line-length
             require((value == 0) || (token.allowance(address(this), spender) == 0),
                 "SafeERC20: approve from non-zero to non-zero allowance"
             );
             callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
         }

         function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
             uint256 newAllowance = token.allowance(address(this), spender).add(value);
             callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
         }

         function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
             uint256 newAllowance = token.allowance(address(this), spender).sub(value);
             callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
         }

         /**
          * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
          * on the return value: the return value is optional (but if data is returned, it must not be false).
          * @param token The token targeted by the call.
          * @param data The call data (encoded using abi.encode or one of its variants).
          */
         function callOptionalReturn(IERC20 token, bytes memory data) private {
             // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
             // we're implementing it ourselves.

             // A Solidity high level call has three parts:
             //  1. The target address is checked to verify it contains contract code
             //  2. The call itself is made, and success asserted
             //  3. The return value is decoded, which in turn checks the size of the returned data.
             // solhint-disable-next-line max-line-length
             require(address(token).isContract(), "SafeERC20: call to non-contract");

             // solhint-disable-next-line avoid-low-level-calls
             (bool success, bytes memory returndata) = address(token).call(data);
             require(success, "SafeERC20: low-level call failed");

             if (returndata.length > 0) { // Return data is optional
                 // solhint-disable-next-line max-line-length
                 require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
             }
         }
      }








      /**
      * @dev Implementation of the `IERC20` interface.
      *
      * This implementation was taken from
      * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.3.0/contracts/token/ERC20/ERC20.sol
      * This differs from the original one only in the definition for the `_balances`
      * mapping: we made it `internal` instead of `private` since we use the `_balances`
      * in the `ERC677BridgeToken` child contract to be able to transfer tokens to address(0)
      * (see its `_superTransfer` function). The original OpenZeppelin implementation
      * doesn't allow transferring to address(0).
      *
      * This implementation is agnostic to the way tokens are created. This means
      * that a supply mechanism has to be added in a derived contract using `_mint`.
      * For a generic mechanism see `ERC20Mintable`.
      *
      * *For a detailed writeup see our guide [How to implement supply
      * mechanisms](https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226).*
      *
      * We have followed general OpenZeppelin guidelines: functions revert instead
      * of returning `false` on failure. This behavior is nonetheless conventional
      * and does not conflict with the expectations of ERC20 applications.
      *
      * Additionally, an `Approval` event is emitted on calls to `transferFrom`.
      * This allows applications to reconstruct the allowance for all accounts just
      * by listening to said events. Other implementations of the EIP may not emit
      * these events, as it isn't required by the specification.
      *
      * Finally, the non-standard `decreaseAllowance` and `increaseAllowance`
      * functions have been added to mitigate the well-known issues around setting
      * allowances. See `IERC20.approve`.
      */
      contract ERC20 is IERC20 {
         using SafeMath for uint256;

         mapping (address => uint256) internal _balances; // CHANGED: not private to write a custom transfer method

         mapping (address => mapping (address => uint256)) private _allowances;

         uint256 private _totalSupply;

         /**
          * @dev See `IERC20.totalSupply`.
          */
         function totalSupply() public view returns (uint256) {
             return _totalSupply;
         }

         /**
          * @dev See `IERC20.balanceOf`.
          */
         function balanceOf(address account) public view returns (uint256) {
             return _balances[account];
         }

         /**
          * @dev See `IERC20.transfer`.
          *
          * Requirements:
          *
          * - `recipient` cannot be the zero address.
          * - the caller must have a balance of at least `amount`.
          */
         function transfer(address recipient, uint256 amount) public returns (bool) {
             _transfer(msg.sender, recipient, amount);
             return true;
         }

         /**
          * @dev See `IERC20.allowance`.
          */
         function allowance(address owner, address spender) public view returns (uint256) {
             return _allowances[owner][spender];
         }

         /**
          * @dev See `IERC20.approve`.
          *
          * Requirements:
          *
          * - `spender` cannot be the zero address.
          */
         function approve(address spender, uint256 value) public returns (bool) {
             _approve(msg.sender, spender, value);
             return true;
         }

         /**
          * @dev See `IERC20.transferFrom`.
          *
          * Emits an `Approval` event indicating the updated allowance. This is not
          * required by the EIP. See the note at the beginning of `ERC20`;
          *
          * Requirements:
          * - `sender` and `recipient` cannot be the zero address.
          * - `sender` must have a balance of at least `value`.
          * - the caller must have allowance for `sender`'s tokens of at least
          * `amount`.
          */
         function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
             _transfer(sender, recipient, amount);
             _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
             return true;
         }

         /**
          * @dev Atomically increases the allowance granted to `spender` by the caller.
          *
          * This is an alternative to `approve` that can be used as a mitigation for
          * problems described in `IERC20.approve`.
          *
          * Emits an `Approval` event indicating the updated allowance.
          *
          * Requirements:
          *
          * - `spender` cannot be the zero address.
          */
         function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
             _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
             return true;
         }

         /**
          * @dev Atomically decreases the allowance granted to `spender` by the caller.
          *
          * This is an alternative to `approve` that can be used as a mitigation for
          * problems described in `IERC20.approve`.
          *
          * Emits an `Approval` event indicating the updated allowance.
          *
          * Requirements:
          *
          * - `spender` cannot be the zero address.
          * - `spender` must have allowance for the caller of at least
          * `subtractedValue`.
          */
         function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
             _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
             return true;
         }

         /**
          * @dev Moves tokens `amount` from `sender` to `recipient`.
          *
          * This is internal function is equivalent to `transfer`, and can be used to
          * e.g. implement automatic token fees, slashing mechanisms, etc.
          *
          * Emits a `Transfer` event.
          *
          * Requirements:
          *
          * - `sender` cannot be the zero address.
          * - `recipient` cannot be the zero address.
          * - `sender` must have a balance of at least `amount`.
          */
         function _transfer(address sender, address recipient, uint256 amount) internal {
             require(sender != address(0), "ERC20: transfer from the zero address");
             require(recipient != address(0), "ERC20: transfer to the zero address");

             _balances[sender] = _balances[sender].sub(amount);
             _balances[recipient] = _balances[recipient].add(amount);
             emit Transfer(sender, recipient, amount);
         }

         /** @dev Creates `amount` tokens and assigns them to `account`, increasing
          * the total supply.
          *
          * Emits a `Transfer` event with `from` set to the zero address.
          *
          * Requirements
          *
          * - `to` cannot be the zero address.
          */
         function _mint(address account, uint256 amount) internal {
             require(account != address(0), "ERC20: mint to the zero address");

             _totalSupply = _totalSupply.add(amount);
             _balances[account] = _balances[account].add(amount);
             emit Transfer(address(0), account, amount);
         }

          /**
          * @dev Destoys `amount` tokens from `account`, reducing the
          * total supply.
          *
          * Emits a `Transfer` event with `to` set to the zero address.
          *
          * Requirements
          *
          * - `account` cannot be the zero address.
          * - `account` must have at least `amount` tokens.
          */
         function _burn(address account, uint256 value) internal {
             require(account != address(0), "ERC20: burn from the zero address");

             _totalSupply = _totalSupply.sub(value);
             _balances[account] = _balances[account].sub(value);
             emit Transfer(account, address(0), value);
         }

         /**
          * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
          *
          * This is internal function is equivalent to `approve`, and can be used to
          * e.g. set automatic allowances for certain subsystems, etc.
          *
          * Emits an `Approval` event.
          *
          * Requirements:
          *
          * - `owner` cannot be the zero address.
          * - `spender` cannot be the zero address.
          */
         function _approve(address owner, address spender, uint256 value) internal {
             require(owner != address(0), "ERC20: approve from the zero address");
             require(spender != address(0), "ERC20: approve to the zero address");

             _allowances[owner][spender] = value;
             emit Approval(owner, spender, value);
         }

         /**
          * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
          * from the caller's allowance.
          *
          * See `_burn` and `_approve`.
          */
         function _burnFrom(address account, uint256 amount) internal {
             _burn(account, amount);
             _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
         }
      }





      /**
      * @dev Optional functions from the ERC20 standard.
      */
      contract ERC20Detailed is IERC20 {
         string private _name;
         string private _symbol;
         uint8 private _decimals;

         /**
          * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
          * these values are immutable: they can only be set once during
          * construction.
          */
         constructor (string memory name, string memory symbol, uint8 decimals) public {
             _name = name;
             _symbol = symbol;
             _decimals = decimals;
         }

         /**
          * @dev Returns the name of the token.
          */
         function name() public view returns (string memory) {
             return _name;
         }

         /**
          * @dev Returns the symbol of the token, usually a shorter version of the
          * name.
          */
         function symbol() public view returns (string memory) {
             return _symbol;
         }

         /**
          * @dev Returns the number of decimals used to get its user representation.
          * For example, if `decimals` equals `2`, a balance of `505` tokens should
          * be displayed to a user as `5,05` (`505 / 10 ** 2`).
          *
          * Tokens usually opt for a value of 18, imitating the relationship between
          * Ether and Wei.
          *
          * > Note that this information is only used for _display_ purposes: it in
          * no way affects any of the arithmetic of the contract, including
          * `IERC20.balanceOf` and `IERC20.transfer`.
          */
         function decimals() public view returns (uint8) {
             return _decimals;
         }
      }



      /**
      * @title ERC20Permittable
      * @dev This is ERC20 contract extended by the `permit` function (see EIP712).
      */
      contract ERC20Permittable is ERC20, ERC20Detailed {

         string public constant version = "1";

         // EIP712 niceties
         bytes32 public DOMAIN_SEPARATOR;
         // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
         bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

         mapping(address => uint256) public nonces;
         mapping(address => mapping(address => uint256)) public expirations;

         constructor(
             string memory _name,
             string memory _symbol,
             uint8 _decimals
         ) ERC20Detailed(_name, _symbol, _decimals) public {
             DOMAIN_SEPARATOR = keccak256(abi.encode(
                 keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                 keccak256(bytes(_name)),
                 keccak256(bytes(version)),
                 1, // Chain ID for Ethereum Mainnet
                 address(this)
             ));
         }

         /// @dev transferFrom in this contract works in a slightly different form than the generic
         /// transferFrom function. This contract allows for "unlimited approval".
         /// Should the user approve an address for the maximum uint256 value,
         /// then that address will have unlimited approval until told otherwise.
         /// @param _sender The address of the sender.
         /// @param _recipient The address of the recipient.
         /// @param _amount The value to transfer.
         /// @return Success status.
         function transferFrom(address _sender, address _recipient, uint256 _amount) public returns (bool) {
             _transfer(_sender, _recipient, _amount);

             if (_sender != msg.sender) {
                 uint256 allowedAmount = allowance(_sender, msg.sender);

                 if (allowedAmount != uint256(-1)) {
                     // If allowance is limited, adjust it.
                     // In this case `transferFrom` works like the generic
                     _approve(_sender, msg.sender, allowedAmount.sub(_amount));
                 } else {
                     // If allowance is unlimited by `permit`, `approve`, or `increaseAllowance`
                     // function, don't adjust it. But the expiration date must be empty or in the future
                     require(
                         expirations[_sender][msg.sender] == 0 || expirations[_sender][msg.sender] >= _now(),
                         "expiry is in the past"
                     );
                 }
             } else {
                 // If `_sender` is `msg.sender`,
                 // the function works just like `transfer()`
             }

             return true;
         }

         /// @dev An alias for `transfer` function.
         /// @param _to The address of the recipient.
         /// @param _amount The value to transfer.
         function push(address _to, uint256 _amount) public {
             transferFrom(msg.sender, _to, _amount);
         }

         /// @dev Makes a request to transfer the specified amount
         /// from the specified address to the caller's address.
         /// @param _from The address of the holder.
         /// @param _amount The value to transfer.
         function pull(address _from, uint256 _amount) public {
             transferFrom(_from, msg.sender, _amount);
         }

         /// @dev An alias for `transferFrom` function.
         /// @param _from The address of the sender.
         /// @param _to The address of the recipient.
         /// @param _amount The value to transfer.
         function move(address _from, address _to, uint256 _amount) public {
             transferFrom(_from, _to, _amount);
         }

         /// @dev Allows to spend holder's unlimited amount by the specified spender.
         /// The function can be called by anyone, but requires having allowance parameters
         /// signed by the holder according to EIP712.
         /// @param _holder The holder's address.
         /// @param _spender The spender's address.
         /// @param _nonce The nonce taken from `nonces(_holder)` public getter.
         /// @param _expiry The allowance expiration date (unix timestamp in UTC).
         /// Can be zero for no expiration. Forced to zero if `_allowed` is `false`.
         /// @param _allowed True to enable unlimited allowance for the spender by the holder. False to disable.
         /// @param _v A final byte of signature (ECDSA component).
         /// @param _r The first 32 bytes of signature (ECDSA component).
         /// @param _s The second 32 bytes of signature (ECDSA component).
         function permit(
             address _holder,
             address _spender,
             uint256 _nonce,
             uint256 _expiry,
             bool _allowed,
             uint8 _v,
             bytes32 _r,
             bytes32 _s
         ) external {
             require(_expiry == 0 || _now() <= _expiry, "invalid expiry");

             bytes32 digest = keccak256(abi.encodePacked(
                 "\x19\x01",
                 DOMAIN_SEPARATOR,
                 keccak256(abi.encode(
                     PERMIT_TYPEHASH,
                     _holder,
                     _spender,
                     _nonce,
                     _expiry,
                     _allowed
                 ))
             ));

             require(_holder == ecrecover(digest, _v, _r, _s), "invalid signature or parameters");
             require(_nonce == nonces[_holder]++, "invalid nonce");

             uint256 amount = _allowed ? uint256(-1) : 0;
             _approve(_holder, _spender, amount);

             expirations[_holder][_spender] = _allowed ? _expiry : 0;
         }

         function _now() internal view returns(uint256) {
             return now;
         }

      }





      // This is a base staking token ERC677 contract for Ethereum Mainnet side
      // which is derived by the child ERC677MultiBridgeToken contract.
      contract ERC677BridgeToken is Ownable, ERC20Permittable {
         using SafeERC20 for ERC20;
         using Address for address;

         ///  @dev Distribution contract address.
         address public distributionAddress;
         ///  @dev The PrivateOffering contract address.
         address public privateOfferingDistributionAddress;
         ///  @dev The AdvisorsReward contract address.
         address public advisorsRewardDistributionAddress;

         /// @dev Mint event.
         /// @param to To address.
         /// @param amount Minted value.
         event Mint(address indexed to, uint256 amount);

         /// @dev Modified Transfer event with custom data.
         /// @param from From address.
         /// @param to To address.
         /// @param value Transferred value.
         /// @param data Custom data to call after transfer.
         event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

         /// @dev Emits if custom call after transfer fails.
         /// @param from From address.
         /// @param to To address.
         /// @param value Transferred value.
         event ContractFallbackCallFailed(address from, address to, uint256 value);

         /// @dev Checks that the recipient address is valid.
         /// @param _recipient Recipient address.
         modifier validRecipient(address _recipient) {
             require(_recipient != address(0) && _recipient != address(this), "not a valid recipient");
             _;
         }

         /// @dev Reverts if called by any account other than the bridge.
         modifier onlyBridge() {
             require(isBridge(msg.sender), "caller is not the bridge");
             _;
         }

         /// @dev Creates a token and mints the whole supply for the Distribution contract.
         /// @param _name Token name.
         /// @param _symbol Token symbol.
         /// @param _distributionAddress The address of the deployed Distribution contract.
         /// @param _privateOfferingDistributionAddress The address of the PrivateOffering contract.
         /// @param _advisorsRewardDistributionAddress The address of the AdvisorsReward contract.
         constructor(
             string memory _name,
             string memory _symbol,
             address _distributionAddress,
             address _privateOfferingDistributionAddress,
             address _advisorsRewardDistributionAddress
         ) ERC20Permittable(_name, _symbol, 18) public {
             require(
                 _distributionAddress.isContract() &&
                 _privateOfferingDistributionAddress.isContract() &&
                 _advisorsRewardDistributionAddress.isContract(),
                 "not a contract address"
             );
             uint256 supply = IDistribution(_distributionAddress).supply();
             require(supply > 0, "the supply must be more than 0");
             _mint(_distributionAddress, supply);
             distributionAddress = _distributionAddress;
             privateOfferingDistributionAddress = _privateOfferingDistributionAddress;
             advisorsRewardDistributionAddress = _advisorsRewardDistributionAddress;
             emit Mint(_distributionAddress, supply);
         }

         /// @dev Checks if given address is included into bridge contracts list.
         /// Implemented by a child contract.
         /// @param _address Bridge contract address.
         /// @return bool true, if given address is a known bridge contract.
         function isBridge(address _address) public view returns (bool);

         /// @dev Extends transfer method with callback.
         /// @param _to The address of the recipient.
         /// @param _value The value to transfer.
         /// @param _data Custom data.
         /// @return Success status.
         function transferAndCall(
             address _to,
             uint256 _value,
             bytes calldata _data
         ) external validRecipient(_to) returns (bool) {
             _superTransfer(_to, _value);
             emit Transfer(msg.sender, _to, _value, _data);

             if (_to.isContract()) {
                 require(_contractFallback(msg.sender, _to, _value, _data), "contract call failed");
             }
             return true;
         }

         /// @dev Extends transfer method with event when the callback failed.
         /// @param _to The address of the recipient.
         /// @param _value The value to transfer.
         /// @return Success status.
         function transfer(address _to, uint256 _value) public returns (bool) {
             _superTransfer(_to, _value);
             _callAfterTransfer(msg.sender, _to, _value);
             return true;
         }

         /// @dev This is a copy of `transfer` function which can only be called by distribution contracts.
         /// Made to get rid of `onTokenTransfer` calling to save gas when distributing tokens.
         /// @param _to The address of the recipient.
         /// @param _value The value to transfer.
         /// @return Success status.
         function transferDistribution(address _to, uint256 _value) public returns (bool) {
             require(
                 msg.sender == distributionAddress ||
                 msg.sender == privateOfferingDistributionAddress ||
                 msg.sender == advisorsRewardDistributionAddress,
                 "wrong sender"
             );
             _superTransfer(_to, _value);
             return true;
         }

         /// @dev Extends transferFrom method with event when the callback failed.
         /// @param _from The address of the sender.
         /// @param _to The address of the recipient.
         /// @param _value The value to transfer.
         /// @return Success status.
         function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
             _superTransferFrom(_from, _to, _value);
             _callAfterTransfer(_from, _to, _value);
             return true;
         }

         /// @dev If someone sent eth/tokens to the contract mistakenly then the owner can send them back.
         /// @param _token The token address to transfer.
         /// @param _to The address of the recipient.
         function claimTokens(address _token, address payable _to) public onlyOwner validRecipient(_to) {
             if (_token == address(0)) {
                 uint256 value = address(this).balance;
                 if (!_to.send(value)) { // solium-disable-line security/no-send
                     // We use the `Sacrifice` trick to be sure the coins can be 100% sent to the receiver.
                     // Otherwise, if the receiver is a contract which has a revert in its fallback function,
                     // the sending will fail.
                     (new Sacrifice).value(value)(_to);
                 }
             } else {
                 ERC20 token = ERC20(_token);
                 uint256 balance = token.balanceOf(address(this));
                 token.safeTransfer(_to, balance);
             }
         }

         /// @dev Creates `amount` tokens and assigns them to `account`, increasing
         /// the total supply. Emits a `Transfer` event with `from` set to the zero address.
         /// Can only be called by a bridge contract which address is set with `addBridge`.
         /// @param _account The address to mint tokens for. Cannot be zero address.
         /// @param _amount The amount of tokens to mint.
         function mint(address _account, uint256 _amount) external onlyBridge returns(bool) {
             _mint(_account, _amount);
             emit Mint(_account, _amount);
             return true;
         }

         /// @dev The removed implementation of the ownership renouncing.
         function renounceOwnership() public onlyOwner {
             revert("not implemented");
         }

         /// @dev Calls transfer method and reverts if it fails.
         /// @param _to The address of the recipient.
         /// @param _value The value to transfer.
         function _superTransfer(address _to, uint256 _value) internal {
             bool success;
             if (
                 msg.sender == distributionAddress ||
                 msg.sender == privateOfferingDistributionAddress ||
                 msg.sender == advisorsRewardDistributionAddress
             ) {
                 // Allow sending tokens to `address(0)` by
                 // Distribution, PrivateOffering, or AdvisorsReward contract
                 _balances[msg.sender] = _balances[msg.sender].sub(_value);
                 _balances[_to] = _balances[_to].add(_value);
                 emit Transfer(msg.sender, _to, _value);
                 success = true;
             } else {
                 success = super.transfer(_to, _value);
             }
             require(success, "transfer failed");
         }

         /// @dev Calls transferFrom method and reverts if it fails.
         /// @param _from The address of the sender.
         /// @param _to The address of the recipient.
         /// @param _value The value to transfer.
         function _superTransferFrom(address _from, address _to, uint256 _value) internal {
             bool success = super.transferFrom(_from, _to, _value);
             require(success, "transfer failed");
         }

         /// @dev Emits an event when the callback failed.
         /// @param _from The address of the sender.
         /// @param _to The address of the recipient.
         /// @param _value The transferred value.
         function _callAfterTransfer(address _from, address _to, uint256 _value) internal {
             if (_to.isContract() && !_contractFallback(_from, _to, _value, new bytes(0))) {
                 require(!isBridge(_to), "you can't transfer to bridge contract");
                 require(_to != distributionAddress, "you can't transfer to Distribution contract");
                 require(_to != privateOfferingDistributionAddress, "you can't transfer to PrivateOffering contract");
                 require(_to != advisorsRewardDistributionAddress, "you can't transfer to AdvisorsReward contract");
                 emit ContractFallbackCallFailed(_from, _to, _value);
             }
         }

         /// @dev Makes a callback after the transfer of tokens.
         /// @param _from The address of the sender.
         /// @param _to The address of the recipient.
         /// @param _value The transferred value.
         /// @param _data Custom data.
         /// @return Success status.
         function _contractFallback(
             address _from,
             address _to,
             uint256 _value,
             bytes memory _data
         ) private returns (bool) {
             string memory signature = "onTokenTransfer(address,uint256,bytes)";
             // solium-disable-next-line security/no-low-level-calls
             (bool success, ) = _to.call(abi.encodeWithSignature(signature, _from, _value, _data));
             return success;
         }
      }




      /**
      * @title ERC677MultiBridgeToken
      * @dev This contract extends ERC677BridgeToken to support several bridges simultaneously.
      */
      contract ERC677MultiBridgeToken is IERC677MultiBridgeToken, ERC677BridgeToken {
         address public constant F_ADDR = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
         uint256 internal constant MAX_BRIDGES = 50;
         mapping(address => address) public bridgePointers;
         uint256 public bridgeCount;

         event BridgeAdded(address indexed bridge);
         event BridgeRemoved(address indexed bridge);

         constructor(
             string memory _name,
             string memory _symbol,
             address _distributionAddress,
             address _privateOfferingDistributionAddress,
             address _advisorsRewardDistributionAddress
         ) public ERC677BridgeToken(
             _name,
             _symbol,
             _distributionAddress,
             _privateOfferingDistributionAddress,
             _advisorsRewardDistributionAddress
         ) {
             bridgePointers[F_ADDR] = F_ADDR; // empty bridge contracts list
         }

         /// @dev Adds one more bridge contract into the list.
         /// @param _bridge Bridge contract address.
         function addBridge(address _bridge) external onlyOwner {
             require(bridgeCount < MAX_BRIDGES, "can't add one more bridge due to a limit");
             require(_bridge.isContract(), "not a contract address");
             require(!isBridge(_bridge), "bridge already exists");

             address firstBridge = bridgePointers[F_ADDR];
             require(firstBridge != address(0), "first bridge is zero address");
             bridgePointers[F_ADDR] = _bridge;
             bridgePointers[_bridge] = firstBridge;
             bridgeCount = bridgeCount.add(1);

             emit BridgeAdded(_bridge);
         }

         /// @dev Removes one existing bridge contract from the list.
         /// @param _bridge Bridge contract address.
         function removeBridge(address _bridge) external onlyOwner {
             require(isBridge(_bridge), "bridge isn't existed");

             address nextBridge = bridgePointers[_bridge];
             address index = F_ADDR;
             address next = bridgePointers[index];
             require(next != address(0), "zero address found");

             while (next != _bridge) {
                 index = next;
                 next = bridgePointers[index];

                 require(next != F_ADDR && next != address(0), "invalid address found");
             }

             bridgePointers[index] = nextBridge;
             delete bridgePointers[_bridge];
             bridgeCount = bridgeCount.sub(1);

             emit BridgeRemoved(_bridge);
         }

         /// @dev Returns all recorded bridge contract addresses.
         /// @return address[] Bridge contract addresses.
         function bridgeList() external view returns (address[] memory) {
             address[] memory list = new address[](bridgeCount);
             uint256 counter = 0;
             address nextBridge = bridgePointers[F_ADDR];
             require(nextBridge != address(0), "zero address found");

             while (nextBridge != F_ADDR) {
                 list[counter] = nextBridge;
                 nextBridge = bridgePointers[nextBridge];
                 counter++;

                 require(nextBridge != address(0), "zero address found");
             }

             return list;
         }

         /// @dev Checks if given address is included into bridge contracts list.
         /// @param _address Bridge contract address.
         /// @return bool true, if given address is a known bridge contract.
         function isBridge(address _address) public view returns (bool) {
             return _address != F_ADDR && bridgePointers[_address] != address(0);
         }
      }
      """

      constructor_arguments =
        "00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000009bc4a93883c522d3c79c81c2999aab52e2268d030000000000000000000000003cfe51b61e25750ab1426b0072e5d0cc5c30aafa0000000000000000000000000218b706898d234b85d2494df21eb0677eaea91800000000000000000000000000000000000000000000000000000000000000055354414b4500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055354414b45000000000000000000000000000000000000000000000000000000"

      # dirty one: "454950373132446f6d61696e28737472696e67206e616d652c737472696e672076657273696f6e2c75696e7432353620636861696e49642c6164647265737320766572696679696e67436f6e74726163742900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000009bc4a93883c522d3c79c81c2999aab52e2268d030000000000000000000000003cfe51b61e25750ab1426b0072e5d0cc5c30aafa0000000000000000000000000218b706898d234b85d2494df21eb0677eaea91800000000000000000000000000000000000000000000000000000000000000055354414b4500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055354414b45000000000000000000000000000000000000000000000000000000"

      input =
        "60806040523480156200001157600080fd5b506040516200301638038062003016833981810160405260a08110156200003757600080fd5b8101908080516401000000008111156200005057600080fd5b820160208101848111156200006457600080fd5b81516401000000008111828201871017156200007f57600080fd5b505092919060200180516401000000008111156200009c57600080fd5b82016020810184811115620000b057600080fd5b8151640100000000811182820187101715620000cb57600080fd5b50506020820151604080840151606090940151600080546001600160a01b031916331780825592519497509295509287928792879287928792879287926012928592859285926001600160a01b0316917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0908290a382516200015590600490602086019062000664565b5081516200016b90600590602085019062000664565b506006805460ff191660ff92909216919091179055505060405180605262002fc48239604080519182900360520182208651602097880120838301835260018085527f310000000000000000000000000000000000000000000000000000000000000094890194909452825180890192909252818301527fc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6606082015260808101929092523060a0808401919091528151808403909101815260c090920190528051908501206007555062000257926001600160a01b038716925062001e46620004c3821b17901c9050565b80156200027e57506200027e826001600160a01b0316620004c360201b62001e461760201c565b8015620002a55750620002a5816001600160a01b0316620004c360201b62001e461760201c565b6200031157604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601660248201527f6e6f74206120636f6e7472616374206164647265737300000000000000000000604482015290519081900360640190fd5b6000836001600160a01b031663047fc9aa6040518163ffffffff1660e01b815260040160206040518083038186803b1580156200034d57600080fd5b505afa15801562000362573d6000803e3d6000fd5b505050506040513d60208110156200037957600080fd5b5051905080620003ea57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601e60248201527f74686520737570706c79206d757374206265206d6f7265207468616e20300000604482015290519081900360640190fd5b620003ff84826001600160e01b03620004c916565b600a80546001600160a01b038087166001600160a01b03199283168117909355600b8054878316908416179055600c8054918616919092161790556040805183815290517f0f6798a560793a54c3bcfe86a93cde1e73087d944c0ea20544137d41213968859181900360200190a250506001600160a01b036000819052600d6020527fa934977eb9828ba1f50591af02c98441645b4f0e916e0fecb4cc8e9c633dade280546001600160a01b03191690911790555062000709975050505050505050565b3b151590565b6001600160a01b0382166200053f57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f206164647265737300604482015290519081900360640190fd5b6200055b81600354620005e860201b62001de51790919060201c565b6003556001600160a01b0382166000908152600160209081526040909120546200059091839062001de5620005e8821b17901c565b6001600160a01b03831660008181526001602090815260408083209490945583518581529351929391927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a35050565b6000828201838110156200065d57604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601b60248201527f536166654d6174683a206164646974696f6e206f766572666c6f770000000000604482015290519081900360640190fd5b9392505050565b828054600181600116156101000203166002900490600052602060002090601f016020900481019282601f10620006a757805160ff1916838001178555620006d7565b82800160010185558215620006d7579182015b82811115620006d7578251825591602001919060010190620006ba565b50620006e5929150620006e9565b5090565b6200070691905b80821115620006e55760008155600101620006f0565b90565b6128ab80620007196000396000f3fe608060405234801561001057600080fd5b50600436106102325760003560e01c8063726600ce11610130578063a457c2d7116100b8578063dd62ed3e1161007c578063dd62ed3e1461075f578063f2d5d56b1461078d578063f2fde38b146107b9578063fbb2a53f146107df578063ff9e884d146107e757610232565b8063a457c2d71461069d578063a9059cbb146106c9578063b753a98c146106f5578063bb35783b14610721578063c794c7691461075757610232565b80638f32d59b116100ff5780638f32d59b146105b55780638fcbaf0c146105bd57806395d89b41146106175780639712fdf81461061f5780639da38e2f1461064557610232565b8063726600ce146105595780637a13685a1461057f5780637ecebe00146105875780638da5cb5b146105ad57610232565b806337fb7e21116101be57806354fd4d501161018257806354fd4d50146104ed57806369ffa08a146104f55780636e15d21b1461052357806370a082311461052b578063715018a61461055157610232565b806337fb7e21146103c657806339509351146103ea5780634000aea01461041657806340c10f191461049b5780634bcb88bc146104c757610232565b8063238a3fe111610205578063238a3fe11461033657806323b872dd1461036257806330adf81f14610398578063313ce567146103a05780633644e515146103be57610232565b806304df017d1461023757806306fdde031461025f578063095ea7b3146102dc57806318160ddd1461031c575b600080fd5b61025d6004803603602081101561024d57600080fd5b50356001600160a01b0316610815565b005b610267610a56565b6040805160208082528351818301528351919283929083019185019080838360005b838110156102a1578181015183820152602001610289565b50505050905090810190601f1680156102ce5780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b610308600480360360408110156102f257600080fd5b506001600160a01b038135169060200135610aec565b604080519115158252519081900360200190f35b610324610b02565b60408051918252519081900360200190f35b6103086004803603604081101561034c57600080fd5b506001600160a01b038135169060200135610b08565b6103086004803603606081101561037857600080fd5b506001600160a01b03813581169160208101359091169060400135610b8d565b610324610baf565b6103a8610bd3565b6040805160ff9092168252519081900360200190f35b610324610bdc565b6103ce610be2565b604080516001600160a01b039092168252519081900360200190f35b6103086004803603604081101561040057600080fd5b506001600160a01b038135169060200135610bf1565b6103086004803603606081101561042c57600080fd5b6001600160a01b038235169160208101359181019060608101604082013564010000000081111561045c57600080fd5b82018360208201111561046e57600080fd5b8035906020019184600183028401116401000000008311171561049057600080fd5b509092509050610c32565b610308600480360360408110156104b157600080fd5b506001600160a01b038135169060200135610dd2565b6103ce600480360360208110156104dd57600080fd5b50356001600160a01b0316610e80565b610267610e9b565b61025d6004803603604081101561050b57600080fd5b506001600160a01b0381358116916020013516610eb8565b6103ce611083565b6103246004803603602081101561054157600080fd5b50356001600160a01b0316611092565b61025d6110ad565b6103086004803603602081101561056f57600080fd5b50356001600160a01b0316611133565b6103ce61116d565b6103246004803603602081101561059d57600080fd5b50356001600160a01b031661117c565b6103ce61118e565b61030861119d565b61025d60048036036101008110156105d457600080fd5b506001600160a01b038135811691602081013590911690604081013590606081013590608081013515159060ff60a0820135169060c08101359060e001356111ae565b610267611446565b61025d6004803603602081101561063557600080fd5b50356001600160a01b03166114a7565b61064d6116e6565b60408051602080825283518183015283519192839290830191858101910280838360005b83811015610689578181015183820152602001610671565b505050509050019250505060405180910390f35b610308600480360360408110156106b357600080fd5b506001600160a01b03813516906020013561182a565b610308600480360360408110156106df57600080fd5b506001600160a01b038135169060200135611866565b61025d6004803603604081101561070b57600080fd5b506001600160a01b03813516906020013561187d565b61025d6004803603606081101561073757600080fd5b506001600160a01b03813581169160208101359091169060400135611888565b6103ce611899565b6103246004803603604081101561077557600080fd5b506001600160a01b03813581169160200135166118a4565b61025d600480360360408110156107a357600080fd5b506001600160a01b0381351690602001356118cf565b61025d600480360360208110156107cf57600080fd5b50356001600160a01b03166118da565b61032461192d565b610324600480360360408110156107fd57600080fd5b506001600160a01b0381358116916020013516611933565b61081d61119d565b61085c576040805162461bcd60e51b8152602060048201819052602482015260008051602061273b833981519152604482015290519081900360640190fd5b61086581611133565b6108ad576040805162461bcd60e51b8152602060048201526014602482015273189c9a5919d9481a5cdb89dd08195e1a5cdd195960621b604482015290519081900360640190fd5b6001600160a01b038082166000908152600d6020526040812054908290526000805160206126cb833981519152549082169190811680610929576040805162461bcd60e51b81526020600482015260126024820152711e995c9bc81859191c995cdcc8199bdd5b9960721b604482015290519081900360640190fd5b836001600160a01b0316816001600160a01b0316146109c8576001600160a01b038082166000908152600d602052604090205491925090811690811480159061097a57506001600160a01b03811615155b6109c3576040805162461bcd60e51b81526020600482015260156024820152741a5b9d985b1a59081859191c995cdcc8199bdd5b99605a1b604482015290519081900360640190fd5b610929565b6001600160a01b038083166000908152600d602052604080822080548488166001600160a01b0319918216179091559287168252902080549091169055600e54610a1990600163ffffffff61195016565b600e556040516001600160a01b038516907f5d9d5034656cb3ebfb0655057cd7f9b4077a9b42ff42ce223cbac5bc586d212690600090a250505050565b60048054604080516020601f6002600019610100600188161502019095169490940493840181900481028201810190925282815260609390929091830182828015610ae25780601f10610ab757610100808354040283529160200191610ae2565b820191906000526020600020905b815481529060010190602001808311610ac557829003601f168201915b5050505050905090565b6000610af93384846119ad565b50600192915050565b60035490565b600a546000906001600160a01b0316331480610b2e5750600b546001600160a01b031633145b80610b435750600c546001600160a01b031633145b610b83576040805162461bcd60e51b815260206004820152600c60248201526b3bb937b7339039b2b73232b960a11b604482015290519081900360640190fd5b610af98383611a99565b6000610b9a848484611bd9565b610ba5848484611c2c565b5060019392505050565b7fea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb81565b60065460ff1690565b60075481565b600a546001600160a01b031681565b3360008181526002602090815260408083206001600160a01b03871684529091528120549091610af9918590610c2d908663ffffffff611de516565b6119ad565b6000846001600160a01b03811615801590610c5657506001600160a01b0381163014155b610c9f576040805162461bcd60e51b81526020600482015260156024820152741b9bdd0818481d985b1a59081c9958da5c1a595b9d605a1b604482015290519081900360640190fd5b610ca98686611a99565b856001600160a01b0316336001600160a01b03167fe19260aff97b920c7df27010903aeb9c8d2be5d310a2c67824cf3f15396e4c1687878760405180848152602001806020018281038252848482818152602001925080828437600083820152604051601f909101601f1916909201829003965090945050505050a3610d37866001600160a01b0316611e46565b15610dc657610d7e33878787878080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250611e4c92505050565b610dc6576040805162461bcd60e51b815260206004820152601460248201527318dbdb9d1c9858dd0818d85b1b0819985a5b195960621b604482015290519081900360640190fd5b50600195945050505050565b6000610ddd33611133565b610e2e576040805162461bcd60e51b815260206004820152601860248201527f63616c6c6572206973206e6f7420746865206272696467650000000000000000604482015290519081900360640190fd5b610e388383612039565b6040805183815290516001600160a01b038516917f0f6798a560793a54c3bcfe86a93cde1e73087d944c0ea20544137d4121396885919081900360200190a250600192915050565b600d602052600090815260409020546001600160a01b031681565b604051806040016040528060018152602001603160f81b81525081565b610ec061119d565b610eff576040805162461bcd60e51b8152602060048201819052602482015260008051602061273b833981519152604482015290519081900360640190fd5b806001600160a01b03811615801590610f2157506001600160a01b0381163014155b610f6a576040805162461bcd60e51b81526020600482015260156024820152741b9bdd0818481d985b1a59081c9958da5c1a595b9d605a1b604482015290519081900360640190fd5b6001600160a01b038316610fe8576040513031906001600160a01b0384169082156108fc029083906000818181858888f19350505050610fe2578083604051610fb290612621565b6001600160a01b039091168152604051908190036020019082f080158015610fde573d6000803e3d6000fd5b5050505b5061107e565b604080516370a0823160e01b8152306004820152905184916000916001600160a01b038416916370a08231916024808301926020929190829003018186803b15801561103357600080fd5b505afa158015611047573d6000803e3d6000fd5b505050506040513d602081101561105d57600080fd5b5051905061107b6001600160a01b038316858363ffffffff61212b16565b50505b505050565b600c546001600160a01b031681565b6001600160a01b031660009081526001602052604090205490565b6110b561119d565b6110f4576040805162461bcd60e51b8152602060048201819052602482015260008051602061273b833981519152604482015290519081900360640190fd5b6040805162461bcd60e51b815260206004820152600f60248201526e1b9bdd081a5b5c1b195b595b9d1959608a1b604482015290519081900360640190fd5b60006001600160a01b038281161480159061116757506001600160a01b038281166000908152600d60205260409020541615155b92915050565b600b546001600160a01b031681565b60086020526000908152604090205481565b6000546001600160a01b031690565b6000546001600160a01b0316331490565b8415806111c25750846111bf61217d565b11155b611204576040805162461bcd60e51b815260206004820152600e60248201526d696e76616c69642065787069727960901b604482015290519081900360640190fd5b600754604080517fea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb6020808301919091526001600160a01b03808d16838501528b166060830152608082018a905260a0820189905287151560c0808401919091528351808403909101815260e08301845280519082012061190160f01b610100840152610102830194909452610122808301949094528251808303909401845261014282018084528451948201949094206000909452610162820180845284905260ff87166101828301526101a282018690526101c2820185905291516001926101e2808401939192601f1981019281900390910190855afa15801561130e573d6000803e3d6000fd5b505050602060405103516001600160a01b0316896001600160a01b03161461137d576040805162461bcd60e51b815260206004820152601f60248201527f696e76616c6964207369676e6174757265206f7220706172616d657465727300604482015290519081900360640190fd5b6001600160a01b038916600090815260086020526040902080546001810190915587146113e1576040805162461bcd60e51b815260206004820152600d60248201526c696e76616c6964206e6f6e636560981b604482015290519081900360640190fd5b6000856113ef5760006113f3565b6000195b90506114008a8a836119ad565b8561140c57600061140e565b865b6001600160a01b039a8b1660009081526009602090815260408083209c909d1682529a909a5299909820989098555050505050505050565b60058054604080516020601f6002600019610100600188161502019095169490940493840181900481028201810190925282815260609390929091830182828015610ae25780601f10610ab757610100808354040283529160200191610ae2565b6114af61119d565b6114ee576040805162461bcd60e51b8152602060048201819052602482015260008051602061273b833981519152604482015290519081900360640190fd5b6032600e541061152f5760405162461bcd60e51b81526004018080602001828103825260288152602001806127816028913960400191505060405180910390fd5b611541816001600160a01b0316611e46565b61158b576040805162461bcd60e51b81526020600482015260166024820152756e6f74206120636f6e7472616374206164647265737360501b604482015290519081900360640190fd5b61159481611133565b156115de576040805162461bcd60e51b815260206004820152601560248201527462726964676520616c72656164792065786973747360581b604482015290519081900360640190fd5b6001600160a01b036000819052600d6020526000805160206126cb833981519152541680611653576040805162461bcd60e51b815260206004820152601c60248201527f666972737420627269646765206973207a65726f206164647265737300000000604482015290519081900360640190fd5b600d6020526000805160206126cb83398151915280546001600160a01b03199081166001600160a01b038581169182179093556000908152604090208054909116918316919091179055600e546116ab906001611de5565b600e556040516001600160a01b038316907f3cda433c5679ae4c6a5dea50840e222a42cba3695e4663de4366be899348422190600090a25050565b606080600e54604051908082528060200260200182016040528015611715578160200160208202803883390190505b506001600160a01b036000818152600d6020526000805160206126cb83398151915254929350911680611784576040805162461bcd60e51b81526020600482015260126024820152711e995c9bc81859191c995cdcc8199bdd5b9960721b604482015290519081900360640190fd5b6001600160a01b038181161461182257808383815181106117a157fe5b6001600160a01b039283166020918202929092018101919091529181166000908152600d90925260409091205460019290920191168061181d576040805162461bcd60e51b81526020600482015260126024820152711e995c9bc81859191c995cdcc8199bdd5b9960721b604482015290519081900360640190fd5b611784565b509091505090565b3360008181526002602090815260408083206001600160a01b03871684529091528120549091610af9918590610c2d908663ffffffff61195016565b60006118728383611a99565b610af9338484611c2c565b61107e338383610b8d565b611893838383610b8d565b50505050565b6001600160a01b0381565b6001600160a01b03918216600090815260026020908152604080832093909416825291909152205490565b61107e823383610b8d565b6118e261119d565b611921576040805162461bcd60e51b8152602060048201819052602482015260008051602061273b833981519152604482015290519081900360640190fd5b61192a81612181565b50565b600e5481565b600960209081526000928352604080842090915290825290205481565b6000828211156119a7576040805162461bcd60e51b815260206004820152601e60248201527f536166654d6174683a207375627472616374696f6e206f766572666c6f770000604482015290519081900360640190fd5b50900390565b6001600160a01b0383166119f25760405162461bcd60e51b81526004018080602001828103825260248152602001806127ce6024913960400191505060405180910390fd5b6001600160a01b038216611a375760405162461bcd60e51b81526004018080602001828103825260228152602001806126a96022913960400191505060405180910390fd5b6001600160a01b03808416600081815260026020908152604080832094871680845294825291829020859055815185815291517f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9259281900390910190a3505050565b600a546000906001600160a01b0316331480611abf5750600b546001600160a01b031633145b80611ad45750600c546001600160a01b031633145b15611b885733600090815260016020526040902054611af9908363ffffffff61195016565b33600090815260016020526040808220929092556001600160a01b03851681522054611b2b908363ffffffff611de516565b6001600160a01b0384166000818152600160209081526040918290209390935580518581529051919233927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a3506001611b95565b611b928383612221565b90505b8061107e576040805162461bcd60e51b815260206004820152600f60248201526e1d1c985b9cd9995c8819985a5b1959608a1b604482015290519081900360640190fd5b6000611be684848461222e565b905080611893576040805162461bcd60e51b815260206004820152600f60248201526e1d1c985b9cd9995c8819985a5b1959608a1b604482015290519081900360640190fd5b611c3e826001600160a01b0316611e46565b8015611c655750604080516000815260208101909152611c6390849084908490611e4c565b155b1561107e57611c7382611133565b15611caf5760405162461bcd60e51b81526004018080602001828103825260258152602001806127166025913960400191505060405180910390fd5b600a546001600160a01b0383811691161415611cfc5760405162461bcd60e51b815260040180806020018281038252602b8152602001806126eb602b913960400191505060405180910390fd5b600b546001600160a01b0383811691161415611d495760405162461bcd60e51b815260040180806020018281038252602e815260200180612849602e913960400191505060405180910390fd5b600c546001600160a01b0383811691161415611d965760405162461bcd60e51b815260040180806020018281038252602d81526020018061281c602d913960400191505060405180910390fd5b604080516001600160a01b0380861682528416602082015280820183905290517f11249f0fc79fc134a15a10d1da8291b79515bf987e036ced05b9ec119614070b9181900360600190a1505050565b600082820183811015611e3f576040805162461bcd60e51b815260206004820152601b60248201527f536166654d6174683a206164646974696f6e206f766572666c6f770000000000604482015290519081900360640190fd5b9392505050565b3b151590565b6000606060405180606001604052806026815260200161275b6026913990506000856001600160a01b03168288878760405160240180846001600160a01b03166001600160a01b0316815260200183815260200180602001828103825283818151815260200191508051906020019080838360005b83811015611ed9578181015183820152602001611ec1565b50505050905090810190601f168015611f065780820380516001836020036101000a031916815260200191505b50945050505050604051602081830303815290604052906040518082805190602001908083835b60208310611f4c5780518252601f199092019160209182019101611f2d565b51815160001960209485036101000a01908116901991909116179052604080519490920184900390932092860180516001600160e01b03166001600160e01b031990941693909317835251855190945084935090508083835b60208310611fc45780518252601f199092019160209182019101611fa5565b6001836020036101000a0380198251168184511680821785525050505050509050019150506000604051808303816000865af19150503d8060008114612026576040519150601f19603f3d011682016040523d82523d6000602084013e61202b565b606091505b509098975050505050505050565b6001600160a01b038216612094576040805162461bcd60e51b815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f206164647265737300604482015290519081900360640190fd5b6003546120a7908263ffffffff611de516565b6003556001600160a01b0382166000908152600160205260409020546120d3908263ffffffff611de516565b6001600160a01b03831660008181526001602090815260408083209490945583518581529351929391927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9281900390910190a35050565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b17905261107e908490612325565b4290565b6001600160a01b0381166121c65760405162461bcd60e51b81526004018080602001828103825260268152602001806126836026913960400191505060405180910390fd5b600080546040516001600160a01b03808516939216917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e091a3600080546001600160a01b0319166001600160a01b0392909216919091179055565b6000610af93384846124dd565b600061223b8484846124dd565b6001600160a01b0384163314610ba557600061225785336118a4565b9050600019811461227c576122778533610c2d848763ffffffff61195016565b61231f565b6001600160a01b038516600090815260096020908152604080832033845290915290205415806122d657506122af61217d565b6001600160a01b038616600090815260096020908152604080832033845290915290205410155b61231f576040805162461bcd60e51b8152602060048201526015602482015274195e1c1a5c9e481a5cc81a5b881d1a19481c185cdd605a1b604482015290519081900360640190fd5b50610ba5565b612337826001600160a01b0316611e46565b612388576040805162461bcd60e51b815260206004820152601f60248201527f5361666545524332303a2063616c6c20746f206e6f6e2d636f6e747261637400604482015290519081900360640190fd5b60006060836001600160a01b0316836040518082805190602001908083835b602083106123c65780518252601f1990920191602091820191016123a7565b6001836020036101000a0380198251168184511680821785525050505050509050019150506000604051808303816000865af19150503d8060008114612428576040519150601f19603f3d011682016040523d82523d6000602084013e61242d565b606091505b509150915081612484576040805162461bcd60e51b815260206004820181905260248201527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564604482015290519081900360640190fd5b805115611893578080602001905160208110156124a057600080fd5b50516118935760405162461bcd60e51b815260040180806020018281038252602a8152602001806127f2602a913960400191505060405180910390fd5b6001600160a01b0383166125225760405162461bcd60e51b81526004018080602001828103825260258152602001806127a96025913960400191505060405180910390fd5b6001600160a01b0382166125675760405162461bcd60e51b81526004018080602001828103825260238152602001806126606023913960400191505060405180910390fd5b6001600160a01b038316600090815260016020526040902054612590908263ffffffff61195016565b6001600160a01b0380851660009081526001602052604080822093909355908416815220546125c5908263ffffffff611de516565b6001600160a01b0380841660008181526001602090815260409182902094909455805185815290519193928716927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef92918290030190a3505050565b60328061262e8339019056fe60806040526040516032380380603283398181016040526020811015602357600080fd5b50516001600160a01b038116fffe45524332303a207472616e7366657220746f20746865207a65726f20616464726573734f776e61626c653a206e6577206f776e657220697320746865207a65726f206164647265737345524332303a20617070726f766520746f20746865207a65726f2061646472657373a934977eb9828ba1f50591af02c98441645b4f0e916e0fecb4cc8e9c633dade2796f752063616e2774207472616e7366657220746f20446973747269627574696f6e20636f6e7472616374796f752063616e2774207472616e7366657220746f2062726964676520636f6e74726163744f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e65726f6e546f6b656e5472616e7366657228616464726573732c75696e743235362c62797465732963616e277420616464206f6e65206d6f7265206272696467652064756520746f2061206c696d697445524332303a207472616e736665722066726f6d20746865207a65726f206164647265737345524332303a20617070726f76652066726f6d20746865207a65726f20616464726573735361666545524332303a204552433230206f7065726174696f6e20646964206e6f742073756363656564796f752063616e2774207472616e7366657220746f2041647669736f727352657761726420636f6e7472616374796f752063616e2774207472616e7366657220746f20507269766174654f66666572696e6720636f6e7472616374a265627a7a723058200ad8413827775c27ddf491b436341ef313c21b1aad827a04e4e91991f6ee4cd764736f6c634300050a0032454950373132446f6d61696e28737472696e67206e616d652c737472696e672076657273696f6e2c75696e7432353620636861696e49642c6164647265737320766572696679696e67436f6e74726163742900000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000009bc4a93883c522d3c79c81c2999aab52e2268d030000000000000000000000003cfe51b61e25750ab1426b0072e5d0cc5c30aafa0000000000000000000000000218b706898d234b85d2494df21eb0677eaea91800000000000000000000000000000000000000000000000000000000000000055354414b4500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055354414b45000000000000000000000000000000000000000000000000000000"

      input_data = %Data{
        bytes: Base.decode16!(input, case: :lower)
      }

      :transaction
      |> insert(created_contract_address_hash: address.hash, input: input_data)
      |> with_block()

      assert ConstructorArguments.verify(
               address.hash,
               input,
               constructor_arguments,
               source_code,
               "ERC677MultiBridgeToken"
             )
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
