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
        uint256 supply = 123; //IDistribution(_distributionAddress).supply();
        require(true, "the supply must be more than 0");
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