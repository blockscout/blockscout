pragma solidity 0.5.10;

interface IMultipleDistribution {
    function initialize(address _tokenAddress) external;
    function poolStake() external view returns (uint256);
}


interface IDistribution {
    function supply() external view returns(uint256);
    function poolAddress(uint8) external view returns(address);
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
 * `onlyOwner`, which can be applied to your functions to restrict their use to
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





/// @dev Distributes STAKE tokens.
contract Distribution is Ownable, IDistribution {
    using SafeMath for uint256;
    using Address for address;

    /// @dev Emits when `preInitialize` method has been called.
    /// @param token The address of ERC677MultiBridgeToken.
    /// @param caller The address of the caller.
    event PreInitialized(address token, address caller);

    /// @dev Emits when `initialize` method has been called.
    /// @param caller The address of the caller.
    event Initialized(address caller);

    /// @dev Emits when an installment for the specified pool has been made.
    /// @param pool The index of the pool.
    /// @param value The installment value.
    /// @param caller The address of the caller.
    event InstallmentMade(uint8 indexed pool, uint256 value, address caller);

    /// @dev Emits when the pool address was changed.
    /// @param pool The index of the pool.
    /// @param oldAddress Old address.
    /// @param newAddress New address.
    event PoolAddressChanged(uint8 indexed pool, address oldAddress, address newAddress);

    /// @dev The instance of ERC677MultiBridgeToken.
    IERC677MultiBridgeToken public token;

    uint8 public constant ECOSYSTEM_FUND = 1;
    uint8 public constant PUBLIC_OFFERING = 2;
    uint8 public constant PRIVATE_OFFERING = 3;
    uint8 public constant ADVISORS_REWARD = 4;
    uint8 public constant FOUNDATION_REWARD = 5;
    uint8 public constant LIQUIDITY_FUND = 6;

    /// @dev Pool address.
    mapping (uint8 => address) public poolAddress;
    /// @dev Pool total amount of tokens.
    mapping (uint8 => uint256) public stake;
    /// @dev Amount of remaining tokens to distribute for the pool.
    mapping (uint8 => uint256) public tokensLeft;
    /// @dev Pool cliff period (in seconds).
    mapping (uint8 => uint256) public cliff;
    /// @dev Total number of installments for the pool.
    mapping (uint8 => uint256) public numberOfInstallments;
    /// @dev Number of installments that were made.
    mapping (uint8 => uint256) public numberOfInstallmentsMade;
    /// @dev The value of one-time installment for the pool.
    mapping (uint8 => uint256) public installmentValue;
    /// @dev The value to transfer to the pool at cliff.
    mapping (uint8 => uint256) public valueAtCliff;
    /// @dev Boolean variable that contains whether the value for the pool at cliff was paid or not.
    mapping (uint8 => bool) public wasValueAtCliffPaid;
    /// @dev Boolean variable that contains whether all installments for the pool were made or not.
    mapping (uint8 => bool) public installmentsEnded;

    /// @dev The total token supply.
    uint256 constant public supply = 8537500 ether;

    /// @dev The timestamp of the distribution start.
    uint256 public distributionStartTimestamp;

    /// @dev The timestamp of pre-initialization.
    uint256 public preInitializationTimestamp;
    /// @dev Boolean variable that indicates whether the contract was pre-initialized.
    bool public isPreInitialized = false;
    /// @dev Boolean variable that indicates whether the contract was initialized.
    bool public isInitialized = false;

    /// @dev Checks that the contract is initialized.
    modifier initialized() {
        require(isInitialized, "not initialized");
        _;
    }

    /// @dev Checks that the installments for the given pool are started and are not finished already.
    /// @param _pool The index of the pool.
    modifier active(uint8 _pool) {
        require(
            // solium-disable-next-line security/no-block-members
            _now() >= distributionStartTimestamp.add(cliff[_pool]) && !installmentsEnded[_pool],
            "installments are not active for this pool"
        );
        _;
    }

    /// @dev Sets up constants and pools addresses that are used in distribution.
    /// @param _ecosystemFundAddress The address of the Ecosystem Fund.
    /// @param _publicOfferingAddress The address of the Public Offering.
    /// @param _privateOfferingAddress The address of the Private Offering contract.
    /// @param _advisorsRewardAddress The address of the Advisors Reward contract.
    /// @param _foundationAddress The address of the Foundation Reward.
    /// @param _liquidityFundAddress The address of the Liquidity Fund.
    constructor(
        address _ecosystemFundAddress,
        address _publicOfferingAddress,
        address _privateOfferingAddress,
        address _advisorsRewardAddress,
        address _foundationAddress,
        address _liquidityFundAddress
    ) public {
        // validate provided addresses
        require(
            _privateOfferingAddress.isContract() &&
            _advisorsRewardAddress.isContract(),
            "not a contract address"
        );
        _validateAddress(_ecosystemFundAddress);
        _validateAddress(_publicOfferingAddress);
        _validateAddress(_foundationAddress);
        _validateAddress(_liquidityFundAddress);
        poolAddress[ECOSYSTEM_FUND] = _ecosystemFundAddress;
        poolAddress[PUBLIC_OFFERING] = _publicOfferingAddress;
        poolAddress[PRIVATE_OFFERING] = _privateOfferingAddress;
        poolAddress[ADVISORS_REWARD] = _advisorsRewardAddress;
        poolAddress[FOUNDATION_REWARD] = _foundationAddress;
        poolAddress[LIQUIDITY_FUND] = _liquidityFundAddress;

        // initialize token amounts
        stake[ECOSYSTEM_FUND] = 4000000 ether;
        stake[PUBLIC_OFFERING] = 400000 ether;
        stake[PRIVATE_OFFERING] = IMultipleDistribution(poolAddress[PRIVATE_OFFERING]).poolStake();
        stake[ADVISORS_REWARD] = IMultipleDistribution(poolAddress[ADVISORS_REWARD]).poolStake();
        stake[FOUNDATION_REWARD] = 699049 ether;
        stake[LIQUIDITY_FUND] = 816500 ether;

        require(
            stake[ECOSYSTEM_FUND] // solium-disable-line operator-whitespace
                .add(stake[PUBLIC_OFFERING])
                .add(stake[PRIVATE_OFFERING])
                .add(stake[ADVISORS_REWARD])
                .add(stake[FOUNDATION_REWARD])
                .add(stake[LIQUIDITY_FUND])
            == supply,
            "wrong sum of pools stakes"
        );

        tokensLeft[ECOSYSTEM_FUND] = stake[ECOSYSTEM_FUND];
        tokensLeft[PUBLIC_OFFERING] = stake[PUBLIC_OFFERING];
        tokensLeft[PRIVATE_OFFERING] = stake[PRIVATE_OFFERING];
        tokensLeft[ADVISORS_REWARD] = stake[ADVISORS_REWARD];
        tokensLeft[FOUNDATION_REWARD] = stake[FOUNDATION_REWARD];
        tokensLeft[LIQUIDITY_FUND] = stake[LIQUIDITY_FUND];

        valueAtCliff[ECOSYSTEM_FUND] = stake[ECOSYSTEM_FUND].mul(20).div(100);       // 20%
        valueAtCliff[PRIVATE_OFFERING] = stake[PRIVATE_OFFERING].mul(10).div(100);   // 10%
        valueAtCliff[ADVISORS_REWARD] = stake[ADVISORS_REWARD].mul(20).div(100);     // 20%
        valueAtCliff[FOUNDATION_REWARD] = stake[FOUNDATION_REWARD].mul(20).div(100); // 20%

        cliff[ECOSYSTEM_FUND] = 336 days;
        cliff[PRIVATE_OFFERING] = 28 days;
        cliff[ADVISORS_REWARD] = 84 days;
        cliff[FOUNDATION_REWARD] = 84 days;

        numberOfInstallments[ECOSYSTEM_FUND] = 336; // days
        numberOfInstallments[PRIVATE_OFFERING] = 224; // days
        numberOfInstallments[ADVISORS_REWARD] = 252; // days
        numberOfInstallments[FOUNDATION_REWARD] = 252; // days

        installmentValue[ECOSYSTEM_FUND] = _calculateInstallmentValue(ECOSYSTEM_FUND);
        installmentValue[PRIVATE_OFFERING] = _calculateInstallmentValue(
            PRIVATE_OFFERING,
            stake[PRIVATE_OFFERING].mul(35).div(100) // 25% will be distributed at pre-initializing and 10% at cliff
        );
        installmentValue[ADVISORS_REWARD] = _calculateInstallmentValue(ADVISORS_REWARD);
        installmentValue[FOUNDATION_REWARD] = _calculateInstallmentValue(FOUNDATION_REWARD);
    }

    /// @dev Pre-initializes the contract after the token is created.
    /// Distributes tokens for Public Offering, Liquidity Fund, and part of Private Offering.
    /// @param _tokenAddress The address of the STAKE token contract.
    /// @param _initialStakeAmount The sum of initial stakes made on xDai chain before transitioning to POSDAO.
    /// This amount must be sent to address(0) because it is excess on Mainnet side.
    function preInitialize(address _tokenAddress, uint256 _initialStakeAmount) external onlyOwner {
        require(!isPreInitialized, "already pre-initialized");

        token = IERC677MultiBridgeToken(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance == supply, "wrong contract balance");

        preInitializationTimestamp = _now(); // solium-disable-line security/no-block-members
        isPreInitialized = true;

        IMultipleDistribution(poolAddress[PRIVATE_OFFERING]).initialize(_tokenAddress);
        IMultipleDistribution(poolAddress[ADVISORS_REWARD]).initialize(_tokenAddress);
        uint256 privateOfferingPrerelease = stake[PRIVATE_OFFERING].mul(25).div(100); // 25%

        token.transferDistribution(poolAddress[PUBLIC_OFFERING], stake[PUBLIC_OFFERING]); // 100%
        token.transfer(poolAddress[PRIVATE_OFFERING], privateOfferingPrerelease);

        uint256 liquidityFundDistribution = stake[LIQUIDITY_FUND].sub(_initialStakeAmount);
        token.transferDistribution(poolAddress[LIQUIDITY_FUND], liquidityFundDistribution);
        if (_initialStakeAmount > 0) {
            token.transferDistribution(address(0), _initialStakeAmount);
        }

        tokensLeft[PUBLIC_OFFERING] = tokensLeft[PUBLIC_OFFERING].sub(stake[PUBLIC_OFFERING]);
        tokensLeft[PRIVATE_OFFERING] = tokensLeft[PRIVATE_OFFERING].sub(privateOfferingPrerelease);
        tokensLeft[LIQUIDITY_FUND] = tokensLeft[LIQUIDITY_FUND].sub(stake[LIQUIDITY_FUND]);

        emit PreInitialized(_tokenAddress, msg.sender);
        emit InstallmentMade(PUBLIC_OFFERING, stake[PUBLIC_OFFERING], msg.sender);
        emit InstallmentMade(PRIVATE_OFFERING, privateOfferingPrerelease, msg.sender);
        emit InstallmentMade(LIQUIDITY_FUND, liquidityFundDistribution, msg.sender);

        if (_initialStakeAmount > 0) {
            emit InstallmentMade(0, _initialStakeAmount, msg.sender);
        }
    }

    /// @dev Initializes token distribution.
    function initialize() external {
        require(isPreInitialized, "not pre-initialized");
        require(!isInitialized, "already initialized");

        if (_now().sub(preInitializationTimestamp) < 90 days) { // solium-disable-line security/no-block-members
            require(isOwner(), "for now only owner can call this method");
        }

        distributionStartTimestamp = _now(); // solium-disable-line security/no-block-members
        isInitialized = true;

        emit Initialized(msg.sender);
    }

    /// @dev Changes the address of the specified pool.
    /// @param _pool The index of the pool (only ECOSYSTEM_FUND or FOUNDATION_REWARD are allowed).
    /// @param _newAddress The new address for the change.
    function changePoolAddress(uint8 _pool, address _newAddress) external {
        require(_pool == ECOSYSTEM_FUND || _pool == FOUNDATION_REWARD, "wrong pool");
        require(msg.sender == poolAddress[_pool], "not authorized");
        _validateAddress(_newAddress);
        emit PoolAddressChanged(_pool, poolAddress[_pool], _newAddress);
        poolAddress[_pool] = _newAddress;
    }

    /// @dev Makes an installment for one of the following pools:
    /// Private Offering, Advisors Reward, Ecosystem Fund, Foundation Reward.
    /// @param _pool The index of the pool.
    function makeInstallment(uint8 _pool) public initialized active(_pool) {
        require(
            _pool == PRIVATE_OFFERING ||
            _pool == ADVISORS_REWARD ||
            _pool == ECOSYSTEM_FUND ||
            _pool == FOUNDATION_REWARD,
            "wrong pool"
        );
        uint256 value = 0;
        if (!wasValueAtCliffPaid[_pool]) {
            value = valueAtCliff[_pool];
            wasValueAtCliffPaid[_pool] = true;
        }
        uint256 availableNumberOfInstallments = _calculateNumberOfAvailableInstallments(_pool);
        value = value.add(installmentValue[_pool].mul(availableNumberOfInstallments));

        require(value > 0, "no installments available");

        uint256 remainder = _updatePoolData(_pool, value, availableNumberOfInstallments);
        value = value.add(remainder);

        if (_pool == PRIVATE_OFFERING || _pool == ADVISORS_REWARD) {
            token.transfer(poolAddress[_pool], value);
        } else {
            token.transferDistribution(poolAddress[_pool], value);
        }

        emit InstallmentMade(_pool, value, msg.sender);
    }

    /// @dev This method is called after the STAKE tokens are transferred to this contract.
    function onTokenTransfer(address, uint256, bytes memory) public pure returns (bool) {
        revert("sending tokens to this contract is not allowed");
    }

    /// @dev The removed implementation of the ownership renouncing.
    function renounceOwnership() public onlyOwner {
        revert("not implemented");
    }

    function _now() internal view returns (uint256) {
        return now; // solium-disable-line security/no-block-members
    }

    /// @dev Updates the given pool data after each installment:
    /// the remaining number of tokens,
    /// the number of made installments.
    /// If the last installment are done and the tokens remained
    /// then transfers them to the pool and marks that all installments for the given pool are made.
    /// @param _pool The index of the pool.
    /// @param _value Current installment value.
    /// @param _currentNumberOfInstallments Number of installment that are made.
    function _updatePoolData(
        uint8 _pool,
        uint256 _value,
        uint256 _currentNumberOfInstallments
    ) internal returns (uint256) {
        uint256 remainder = 0;
        tokensLeft[_pool] = tokensLeft[_pool].sub(_value);
        numberOfInstallmentsMade[_pool] = numberOfInstallmentsMade[_pool].add(_currentNumberOfInstallments);
        if (numberOfInstallmentsMade[_pool] >= numberOfInstallments[_pool]) {
            if (tokensLeft[_pool] > 0) {
                remainder = tokensLeft[_pool];
                tokensLeft[_pool] = 0;
            }
            _endInstallment(_pool);
        }
        return remainder;
    }

    /// @dev Marks that all installments for the given pool are made.
    /// @param _pool The index of the pool.
    function _endInstallment(uint8 _pool) internal {
        installmentsEnded[_pool] = true;
    }

    /// @dev Calculates the value of the installment for 1 day for the given pool.
    /// @param _pool The index of the pool.
    /// @param _valueAtCliff Custom value to distribute at cliff.
    function _calculateInstallmentValue(
        uint8 _pool,
        uint256 _valueAtCliff
    ) internal view returns (uint256) {
        return stake[_pool].sub(_valueAtCliff).div(numberOfInstallments[_pool]);
    }

    /// @dev Calculates the value of the installment for 1 day for the given pool.
    /// @param _pool The index of the pool.
    function _calculateInstallmentValue(uint8 _pool) internal view returns (uint256) {
        return _calculateInstallmentValue(_pool, valueAtCliff[_pool]);
    }

    /// @dev Calculates the number of available installments for the given pool.
    /// @param _pool The index of the pool.
    /// @return The number of available installments.
    function _calculateNumberOfAvailableInstallments(
        uint8 _pool
    ) internal view returns (
        uint256 availableNumberOfInstallments
    ) {
        uint256 paidDays = numberOfInstallmentsMade[_pool].mul(1 days);
        uint256 lastTimestamp = distributionStartTimestamp.add(cliff[_pool]).add(paidDays);
        // solium-disable-next-line security/no-block-members
        availableNumberOfInstallments = _now().sub(lastTimestamp).div(1 days);
        if (numberOfInstallmentsMade[_pool].add(availableNumberOfInstallments) > numberOfInstallments[_pool]) {
            availableNumberOfInstallments = numberOfInstallments[_pool].sub(numberOfInstallmentsMade[_pool]);
        }
    }

    /// @dev Checks for an empty address.
    function _validateAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert("invalid address");
        }
    }
}
