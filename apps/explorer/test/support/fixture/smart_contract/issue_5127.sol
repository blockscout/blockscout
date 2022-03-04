// Sources flattened with hardhat v2.7.0 https://hardhat.org
 
// File contracts/modules/pause/interfaces/IPauseable.sol
 
// SPDX-License-Identifier: MIT
 
pragma solidity >=0.5.0;
 
interface IPauseable {
  event Paused(address account);
  event Unpaused(address account);
 
  function paused() external view returns (bool);
 
  function pause() external;
  function unpause() external;
}
 
 
// File contracts/modules/blacklist/interfaces/IBlacklist.sol
 
pragma solidity >=0.5.0;
 
interface IBlacklist {
 
  event AddBlacklist(address indexed account, address indexed caller);
  event RevokeBlacklist(address indexed account, address indexed caller);
 
  function blacklist(address account) external view returns (bool);
 
  function addBlacklist(address account) external;
 
  function revokeBlacklist(address account) external;
}
 
 
// File contracts/modules/committee/interfaces/IKAP20Committee.sol
 
pragma solidity >=0.5.0;
 
interface IKAP20Committee {
  event SetCommittee(address oldCommittee, address newComittee);
 
  function committee() external view returns (address);
 
  function setCommittee(address _committee) external;
}
 
 
// File contracts/modules/kyc/interfaces/IKYCBitkubChain.sol
 
pragma solidity >=0.6.0;
 
interface IKYCBitkubChain {
  function kycsLevel(address _addr) external view returns (uint256);
}
 
 
// File contracts/modules/kyc/interfaces/IKAP20KYC.sol
 
pragma solidity >=0.5.0;
 
interface IKAP20KYC {
  event ActivateOnlyKYCAddress();
  event SetKYC(address oldKyc, address newKyc);
  event SetAccecptedKycLevel(uint256 oldKycLevel, uint256 newKycLevel);
 
  function activateOnlyKycAddress() external;
  function setKYC(address _kyc) external;
  function setAcceptedKycLevel(uint256 _kycLevel) external;
 
  function kyc() external returns(IKYCBitkubChain);
  function acceptedKycLevel() external returns(uint256);
  function isActivatedOnlyKycAddress() external returns(bool);
}
 
 
// File contracts/modules/kap20/interfaces/IKAP20.sol
 
pragma solidity >=0.5.0;
 
 
 
 
interface IKAP20 is IPauseable, IBlacklist, IKAP20Committee, IKAP20KYC {
    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
 
    function name() external view returns (string memory);
 
    function symbol() external view returns (string memory);
 
    function decimals() external view returns (uint8);
 
    function totalSupply() external view returns (uint256);
   
    function balanceOf(address tokenOwner) external view returns (uint256 balance);
 
    function allowance(address tokenOwner, address spender) external view returns (uint256 remaining);
 
    function transfer(address to, uint256 tokens) external returns (bool success);
 
    function approve(address spender, uint256 tokens) external returns (bool success);
 
    function transferFrom(address from, address to, uint256 tokens) external returns (bool success);
   
    function adminTransfer(address _from, address _to, uint256 _value) external returns (bool success);
   
}
 
 
// File contracts/modules/kap20/interfaces/IKToken.sol
 
pragma solidity >=0.5.0;
 
interface IKToken {
  function internalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);
 
  function externalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);
}
 
 
// File contracts/modules/misc/Context.sol
 
pragma solidity ^0.8.0;
 
abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }
 
  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}
 
 
// File contracts/modules/pause/Pausable.sol
 
pragma solidity ^0.8.0;
 
 
abstract contract Pausable is IPauseable, Context {
 
  bool private _paused;
 
  constructor() {
    _paused = false;
  }
 
  function paused() public view override virtual returns (bool) {
    return _paused;
  }
 
  modifier whenNotPaused() {
    require(!paused(), "P");
    _;
  }
 
  modifier whenPaused() {
    require(paused(), "NP");
    _;
  }
 
  function _pause() internal virtual whenNotPaused {
    _paused = true;
    emit Paused(_msgSender());
  }
 
  function _unpause() internal virtual whenPaused {
    _paused = false;
    emit Unpaused(_msgSender());
  }
}
 
 
// File contracts/modules/committee/KAP20Committee.sol
 
pragma solidity ^0.8.0;
 
abstract contract KAP20Committee is IKAP20Committee {
 
  address public override committee;
 
  modifier onlyCommittee() {
    require(msg.sender == committee, "Restricted only committee");
    _;
  }
 
  constructor(address committee_) {
    committee = committee_;
  }
 
  function _setCommittee(address _committee) internal {
    address oldCommittee = _committee;
    committee = _committee;
    emit SetCommittee(oldCommittee, committee);
  }
 
}
 
 
// File contracts/modules/admin/interfaces/IAdminProjectRouter.sol
 
pragma solidity >=0.5.0;
 
interface IAdminProjectRouter {
  function isSuperAdmin(address _addr, string calldata _project) external view returns (bool);
 
  function isAdmin(address _addr, string calldata _project) external view returns (bool);
}
 
 
// File contracts/modules/admin/Authorization.sol
 
pragma solidity >=0.5.0;
 
abstract contract Authorization {
    IAdminProjectRouter public adminRouter;
    string public constant PROJECT = "yuemmai";
 
    modifier onlySuperAdmin() {
        require(
            adminRouter.isSuperAdmin(msg.sender, PROJECT),
            "Restricted only super admin"
        );
        _;
    }
 
    modifier onlyAdmin() {
        require(
            adminRouter.isAdmin(msg.sender, PROJECT),
            "Restricted only admin"
        );
        _;
    }
 
    modifier onlySuperAdminOrAdmin() {
        require(
            adminRouter.isSuperAdmin(msg.sender, PROJECT) ||
                adminRouter.isAdmin(msg.sender, PROJECT),
            "Restricted only super admin or admin"
        );
        _;
    }
 
    constructor(address adminRouter_) {
        adminRouter = IAdminProjectRouter(adminRouter_);
    }
 
    function setAdmin(address _adminRouter) external onlySuperAdmin {
        adminRouter = IAdminProjectRouter(_adminRouter);
    }
}
 
 
// File contracts/modules/kyc/KYCHandler.sol
 
pragma solidity ^0.8.0;
 
 
abstract contract KYCHandler is IKAP20KYC {
  IKYCBitkubChain public override kyc;
 
  uint256 public override acceptedKycLevel;
  bool public override isActivatedOnlyKycAddress;
 
  constructor(address kyc_, uint256 acceptedKycLevel_) {
    kyc = IKYCBitkubChain(kyc_);
    acceptedKycLevel = acceptedKycLevel_;
  }
 
  function _activateOnlyKycAddress() internal virtual {
    isActivatedOnlyKycAddress = true;
    emit ActivateOnlyKYCAddress();
  }
 
  function _setKYC(IKYCBitkubChain _kyc) internal virtual {
    IKYCBitkubChain oldKyc = kyc;
    kyc = _kyc;
    emit SetKYC(address(oldKyc), address(kyc));
  }
 
  function _setAcceptedKycLevel(uint256 _kycLevel) internal virtual {
    uint256 oldKycLevel = acceptedKycLevel;
    acceptedKycLevel = _kycLevel;
    emit SetAccecptedKycLevel(oldKycLevel, acceptedKycLevel);
  }
}
 
 
// File contracts/modules/blacklist/Blacklist.sol
 
pragma solidity ^0.8.0;
 
abstract contract Blacklist is IBlacklist {
  mapping(address => bool) public override blacklist;
 
  modifier notInBlacklist(address account) {
    require(!blacklist[account], "Address is in blacklist");
    _;
  }
 
  modifier inBlacklist(address account) {
    require(blacklist[account], "Address is not in blacklist");
    _;
  }
 
  function _addBlacklist(address account) internal virtual notInBlacklist(account) {
    blacklist[account] = true;
    emit AddBlacklist(account, msg.sender);
  }
 
  function _revokeBlacklist(address account) internal virtual inBlacklist(account) {
    blacklist[account] = false;
    emit RevokeBlacklist(account, msg.sender);
  }
}
 
 
// File contracts/modules/kap20/KAP20.sol
 
pragma solidity ^0.8.0;
 
 
 
 
 
 
contract KAP20 is IKAP20, IKToken, Pausable, KAP20Committee, Authorization, KYCHandler, Blacklist {
 
  mapping(address => uint256) _balances;
 
  mapping(address => mapping(address => uint256)) internal _allowance;
 
  uint256 public override totalSupply;
 
  string public override name;
  string public override symbol;
  uint8 public override decimals;
 
  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    address committee_,
    address adminRouter_,
    address kyc_,
    uint256 acceptedKycLevel_
  ) KAP20Committee(committee_) Authorization(adminRouter_) KYCHandler(kyc_, acceptedKycLevel_) {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
  }
 
  function balanceOf(address account) public view virtual override returns (uint256) {
    return _balances[account];
  }
 
  function transfer(address recipient, uint256 amount) public virtual override whenNotPaused notInBlacklist(msg.sender) returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }
 
  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return _allowance[owner][spender];
  }
 
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }
 
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override whenNotPaused notInBlacklist(sender) returns (bool) {
    _transfer(sender, recipient, amount);
 
    uint256 currentAllowance = _allowance[sender][msg.sender];
    require(currentAllowance >= amount, "KAP20: transfer amount exceeds allowance");
    unchecked { _approve(sender, msg.sender, currentAllowance - amount); }
 
    return true;
  }
 
  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(msg.sender, spender, _allowance[msg.sender][spender] + addedValue);
    return true;
  }
 
  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    uint256 currentAllowance = _allowance[msg.sender][spender];
    require(currentAllowance >= subtractedValue, "KAP20: decreased allowance below zero");
    unchecked { _approve(msg.sender, spender, currentAllowance - subtractedValue); }
 
    return true;
  }
 
  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual {
    require(sender != address(0), "KAP20: transfer from the zero address");
    require(recipient != address(0), "KAP20: transfer to the zero address");
 
    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "KAP20: transfer amount exceeds balance");
    unchecked { _balances[sender] = senderBalance - amount; }
    _balances[recipient] += amount;
 
    emit Transfer(sender, recipient, amount);
  }
 
  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "KAP20: mint to the zero address");
 
    totalSupply += amount;
    _balances[account] += amount;
    emit Transfer(address(0), account, amount);
  }
 
  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "KAP20: burn from the zero address");
 
    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "KAP20: burn amount exceeds balance");
    unchecked { _balances[account] = accountBalance - amount; }
    totalSupply -= amount;
 
    emit Transfer(account, address(0), amount);
  }
 
  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal virtual {
    require(owner != address(0), "KAP20: approve from the zero address");
    require(spender != address(0), "KAP20: approve to the zero address");
 
    _allowance[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
 
  function adminTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override onlyCommittee returns (bool) {
    require(_balances[sender] >= amount, "KAP20: transfer amount exceed balance");
    require(recipient != address(0), "KAP20: transfer to zero address");
    _balances[sender] -= amount;
    _balances[recipient] += amount;
    emit Transfer(sender, recipient, amount);
 
    return true;
  }
 
  function internalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external override whenNotPaused onlySuperAdmin returns (bool) {
    require(
      kyc.kycsLevel(sender) >= acceptedKycLevel && kyc.kycsLevel(recipient) >= acceptedKycLevel,
      "Only internal purpose"
    );
 
    _transfer(sender, recipient, amount);
    return true;
  }
 
  function externalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external override whenNotPaused onlySuperAdmin returns (bool) {
    require(kyc.kycsLevel(sender) >= acceptedKycLevel, "Only internal purpose");
 
    _transfer(sender, recipient, amount);
    return true;
  }
 
  function activateOnlyKycAddress() public override onlyCommittee {
    _activateOnlyKycAddress();
  }
 
  function setKYC(address _kyc) public override onlyCommittee {
    _setKYC(IKYCBitkubChain(_kyc));
  }
 
  function setAcceptedKycLevel(uint256 _kycLevel) public override onlyCommittee {
    _setAcceptedKycLevel(_kycLevel);
  }
 
  function setCommittee(address _committee) external override onlyCommittee {
    _setCommittee(_committee);
  }
 
  function pause() external override onlyCommittee {
    _pause();
  }
 
  function unpause() external override onlyCommittee {
    _unpause();
  }
 
  function addBlacklist(address account) external override onlyCommittee {
    _addBlacklist(account);
  }
 
  function revokeBlacklist(address account) external override onlyCommittee {
    _revokeBlacklist(account);
  }
 
}
 
 
// File contracts/YESToken.sol
 
pragma solidity ^0.8.0;
 
contract YESToken is KAP20 {
    constructor(
        uint256 totalSupply_,
        address committee_,
        address adminRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    )
        KAP20(
            "YES Token",
            "YES",
            18,
            committee_,
            adminRouter_,
            kyc_,
            acceptedKycLevel_
        )
    {
        _mint(msg.sender, totalSupply_);
    }
}