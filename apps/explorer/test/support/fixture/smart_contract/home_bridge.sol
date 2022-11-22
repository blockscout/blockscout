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