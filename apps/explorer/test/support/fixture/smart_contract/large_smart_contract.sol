/**
 *Submitted for verification at Etherscan.io on 2019-06-05
*/

pragma solidity 0.5.9; // optimization enabled, runs: 10000, evm: constantinople


/**
 * @title HomeWork Interface (version 1) - EIP165 ID 0xe5399799
 * @author 0age
 * @notice Homework is a utility to find, share, and reuse "home" addresses for
 * contracts. Anyone can work to find a new home address by searching for keys,
 * a 32-byte value with the first 20 bytes equal to the finder's calling address
 * (or derived by hashing an arbitrary 32-byte salt and the caller's address),
 * and can then deploy any contract they like (even one with a constructor) to
 * the address, or mint an ERC721 token that the owner can redeem that will then
 * allow them to do the same. Also, if the contract is `SELFDESTRUCT`ed, a new
 * contract can be redeployed by the current controller to the same address!
 * @dev This contract allows contract addresses to be located ahead of time, and
 * for arbitrary bytecode to be deployed (and redeployed if so desired, i.e.
 * metamorphic contracts) to the located address by a designated controller. To
 * enable this, the contract first deploys an "initialization-code-in-runtime"
 * contract, with the creation code of the contract you want to deploy stored in
 * RUNTIME code. Then, to deploy the actual contract, it retrieves the address
 * of the storage contract and `DELEGATECALL`s into it to execute the init code
 * and, if successful, retrieves and returns the contract runtime code. Rather
 * than using a located address directly, you can also lock it in the contract
 * and mint and ERC721 token for it, which can then be redeemed in order to gain
 * control over deployment to the address (note that tokens may not be minted if
 * the contract they control currently has a deployed contract at that address).
 * Once a contract undergoes metamorphosis, all existing storage will be deleted
 * and any existing contract code will be replaced with the deployed contract
 * code of the new implementation contract. The mechanisms behind this contract
 * are highly experimental - proceed with caution and please share any exploits
 * or optimizations you discover.
 */
interface IHomeWork {
  // Fires when a contract is deployed or redeployed to a given home address.
  event NewResident(
    address indexed homeAddress,
    bytes32 key,
    bytes32 runtimeCodeHash
  );

  // Fires when a new runtime storage contract is deployed.
  event NewRuntimeStorageContract(
    address runtimeStorageContract,
    bytes32 runtimeCodeHash
  );

  // Fires when a controller is changed from the default controller.
  event NewController(bytes32 indexed key, address newController);

  // Fires when a new high score is submitted.
  event NewHighScore(bytes32 key, address submitter, uint256 score);

  // Track total contract deploys and current controller for each home address.
  struct HomeAddress {
    bool exists;
    address controller;
    uint88 deploys;
  }

  // Track derivation of key for a given home address based on salt & submitter.
  struct KeyInformation {
    bytes32 key;
    bytes32 salt;
    address submitter;
  }

  /**
   * @notice Deploy a new contract with the desired initialization code to the
   * home address corresponding to a given key. Two conditions must be met: the
   * submitter must be designated as the controller of the home address (with
   * the initial controller set to the address corresponding to the first twenty
   * bytes of the key), and there must not be a contract currently deployed at
   * the home address. These conditions can be checked by calling
   * `getHomeAddressInformation` and `isDeployable` with the same key.
   * @param key bytes32 The unique value used to derive the home address.
   * @param initializationCode bytes The contract creation code that will be
   * used to deploy the contract to the home address.
   * @return The home address of the deployed contract.
   * @dev In order to deploy the contract to the home address, a new contract
   * will be deployed with runtime code set to the initialization code of the
   * contract that will be deployed to the home address. Then, metamorphic
   * initialization code will retrieve that initialization code and use it to
   * set up and deploy the desired contract to the home address. Bear in mind
   * that the deployed contract will interpret msg.sender as the address of THIS
   * contract, and not the address of the submitter - if the constructor of the
   * deployed contract uses msg.sender to set up ownership or other variables,
   * you must modify it to accept a constructor argument with the appropriate
   * address, or alternately to hard-code the intended address. Also, if your
   * contract DOES have constructor arguments, remember to include them as
   * ABI-encoded arguments at the end of the initialization code, just as you
   * would when performing a standard deploy. You may also want to provide the
   * key to `setReverseLookup` in order to find it again using only the home
   * address to prevent accidentally losing the key.
   */
  function deploy(bytes32 key, bytes calldata initializationCode)
    external
    payable
    returns (address homeAddress, bytes32 runtimeCodeHash);

  /**
   * @notice Mint an ERC721 token to the supplied owner that can be redeemed in
   * order to gain control of a home address corresponding to a given key. Two
   * conditions must be met: the submitter must be designated as the controller
   * of the home address (with the initial controller set to the address
   * corresponding to the first 20 bytes of the key), and there must not be a
   * contract currently deployed at the home address. These conditions can be
   * checked by calling `getHomeAddressInformation` and `isDeployable` with the
   * same key.
   * @param key bytes32 The unique value used to derive the home address.
   * @param owner address The account that will be granted ownership of the
   * ERC721 token.
   * @dev In order to mint an ERC721 token, the assocated home address cannot be
   * in use, or else the token will not be able to deploy to the home address.
   * The controller is set to this contract until the token is redeemed, at
   * which point the redeemer designates a new controller for the home address.
   * The key of the home address and the tokenID of the ERC721 token are the
   * same value, but different types (bytes32 vs. uint256).
   */
  function lock(bytes32 key, address owner) external;

  /**
   * @notice Burn an ERC721 token to allow the supplied controller to gain the
   * ability to deploy to the home address corresponding to the key matching the
   * burned token. The submitter must be designated as either the owner of the
   * token or as an approved spender.
   * @param tokenId uint256 The ID of the ERC721 token to redeem.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given token.
   * @dev The controller cannot be designated as the address of this contract,
   * the null address, or the home address (the restriction on setting the home
   * address as the controller is due to the fact that the home address will not
   * be able to deploy to itself, as it needs to be empty before a contract can
   * be deployed to it).
   */
  function redeem(uint256 tokenId, address controller) external;

  /**
   * @notice Transfer control over deployment to the home address corresponding
   * to a given key. The caller must be designated as the current controller of
   * the home address (with the initial controller set to the address
   * corresponding to the first 20 bytes of the key) - This condition can be
   * checked by calling `getHomeAddressInformation` with the same key.
   * @param key bytes32 The unique value used to derive the home address.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given key.
   * @dev The controller cannot be designated as the address of this contract,
   * the null address, or the home address (the restriction on setting the home
   * address as the controller is due to the fact that the home address will not
   * be able to deploy to itself, as it needs to be empty before a contract can
   * be deployed to it).
   */
  function assignController(bytes32 key, address controller) external;

  /**
   * @notice Transfer control over deployment to the home address corresponding
   * to a given key to the null address, which will prevent it from being
   * deployed to again in the future. The caller must be designated as the
   * current controller of the corresponding home address (with the initial
   * controller set to the address corresponding to the first 20 bytes of the
   * key) - This condition can be checked by calling `getHomeAddressInformation`
   * with the same key.
   * @param key bytes32 The unique value used to derive the home address.
   */
  function relinquishControl(bytes32 key) external;

  /**
   * @notice Burn an ERC721 token, set a supplied controller, and deploy a new
   * contract with the supplied initialization code to the corresponding home
   * address for the given token. The submitter must be designated as either the
   * owner of the token or as an approved spender.
   * @param tokenId uint256 The ID of the ERC721 token to redeem.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given token.
   * @param initializationCode bytes The contract creation code that will be
   * used to deploy the contract to the home address.
   * @return The home address and runtime code hash of the deployed contract.
   * @dev In order to deploy the contract to the home address, a new contract
   * will be deployed with runtime code set to the initialization code of the
   * contract that will be deployed to the home address. Then, metamorphic
   * initialization code will retrieve that initialization code and use it to
   * set up and deploy the desired contract to the home address. Bear in mind
   * that the deployed contract will interpret msg.sender as the address of THIS
   * contract, and not the address of the submitter - if the constructor of the
   * deployed contract uses msg.sender to set up ownership or other variables,
   * you must modify it to accept a constructor argument with the appropriate
   * address, or alternately to hard-code the intended address. Also, if your
   * contract DOES have constructor arguments, remember to include them as
   * ABI-encoded arguments at the end of the initialization code, just as you
   * would when performing a standard deploy. You may also want to provide the
   * key to `setReverseLookup` in order to find it again using only the home
   * address to prevent accidentally losing the key. The controller cannot be
   * designated as the address of this contract, the null address, or the home
   * address (the restriction on setting the home address as the controller is
   * due to the fact that the home address will not be able to deploy to itself,
   * as it needs to be empty before a contract can be deployed to it). Also,
   * checks on the contract at the home address being empty or not having the
   * correct controller are unnecessary, as they are performed when minting the
   * token and cannot be altered until the token is redeemed.
   */
  function redeemAndDeploy(
    uint256 tokenId,
    address controller,
    bytes calldata initializationCode
  )
    external
    payable
    returns (address homeAddress, bytes32 runtimeCodeHash);

  /**
   * @notice Derive a new key by concatenating an arbitrary 32-byte salt value
   * and the address of the caller and performing a keccak256 hash. This allows
   * for the creation of keys with additional entropy where desired while also
   * preventing collisions with standard keys. The caller will be set as the
   * controller of the derived key.
   * @param salt bytes32 The desired salt value to use (along with the address
   * of the caller) when deriving the resultant key and corresponding home
   * address.
   * @return The derived key.
   * @dev Home addresses from derived keys will take longer to "mine" or locate,
   * as an additional hash must be performed when computing the corresponding
   * home address for each given salt input. Each caller will derive a different
   * key even if they are supplying the same salt value.
   */
  function deriveKey(bytes32 salt) external returns (bytes32 key);

  /**
   * @notice Mint an ERC721 token to the supplied owner that can be redeemed in
   * order to gain control of a home address corresponding to a given derived
   * key. Two conditions must be met: the submitter must be designated as the
   * current controller of the home address, and there must not be a contract
   * currently deployed at the home address. These conditions can be checked by
   * calling `getHomeAddressInformation` and `isDeployable` with the key
   * determined by calling `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param owner address The account that will be granted ownership of the
   * ERC721 token.
   * @return The derived key.
   * @dev In order to mint an ERC721 token, the assocated home address cannot be
   * in use, or else the token will not be able to deploy to the home address.
   * The controller is set to this contract until the token is redeemed, at
   * which point the redeemer designates a new controller for the home address.
   * The key of the home address and the tokenID of the ERC721 token are the
   * same value, but different types (bytes32 vs. uint256).
   */
  function deriveKeyAndLock(bytes32 salt, address owner)
    external
    returns (bytes32 key);

  /**
   * @notice Transfer control over deployment to the home address corresponding
   * to a given derived key. The caller must be designated as the current
   * controller of the home address - This condition can be checked by calling
   * `getHomeAddressInformation` with the key obtained via `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given derived key.
   * @return The derived key.
   * @dev The controller cannot be designated as the address of this contract,
   * the null address, or the home address (the restriction on setting the home
   * address as the controller is due to the fact that the home address will not
   * be able to deploy to itself, as it needs to be empty before a contract can
   * be deployed to it).
   */
  function deriveKeyAndAssignController(bytes32 salt, address controller)
    external
    returns (bytes32 key);

  /**
   * @notice Transfer control over deployment to the home address corresponding
   * to a given derived key to the null address, which will prevent it from
   * being deployed to again in the future. The caller must be designated as the
   * current controller of the home address - This condition can be checked by
   * calling `getHomeAddressInformation` with the key determined by calling
   * `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @return The derived key.
   */
  function deriveKeyAndRelinquishControl(bytes32 salt)
    external
    returns (bytes32 key);

  /**
   * @notice Record a key that corresponds to a given home address by supplying
   * said key and using it to derive the address. This enables reverse lookup
   * of a key using only the home address in question. This method may be called
   * by anyone - control of the key is not required.
   * @param key bytes32 The unique value used to derive the home address.
   * @dev This does not set the salt or submitter fields, as those apply only to
   * derived keys (although a derived key may also be set with this method, just
   * without the derived fields).
   */
  function setReverseLookup(bytes32 key) external;

  /**
   * @notice Record the derived key that corresponds to a given home address by
   * supplying the salt and submitter that were used to derive the key. This
   * facititates reverse lookup of the derivation method of a key using only the
   * home address in question. This method may be called by anyone - control of
   * the derived key is not required.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param submitter address The account that submits the salt that is used to
   * derive the key.
   */
  function setDerivedReverseLookup(bytes32 salt, address submitter) external;

  /**
   * @notice Deploy a new storage contract with the supplied code as runtime
   * code without deploying a contract to a home address. This can be used to
   * store the contract creation code for use in future deployments of contracts
   * to home addresses.
   * @param codePayload bytes The code to set as the runtime code of the
   * deployed contract.
   * @return The address of the deployed storage contract.
   * @dev Consider placing adequate protections on the storage contract to
   * prevent unwanted callers from modifying or destroying it. Also, if you are
   * placing contract contract creation code into the runtime storage contract,
   * remember to include any constructor parameters as ABI-encoded arguments at
   * the end of the contract creation code, similar to how you would perform a
   * standard deployment.
   */
  function deployRuntimeStorageContract(bytes calldata codePayload)
    external
    returns (address runtimeStorageContract);

  /**
   * @notice Deploy a new contract with the initialization code stored in the
   * runtime code at the specified initialization runtime storage contract to
   * the home address corresponding to a given key. Two conditions must be met:
   * the submitter must be designated as the controller of the home address
   * (with the initial controller set to the address corresponding to the first
   * 20 bytes of the key), and there must not be a contract currently deployed
   * at the home address. These conditions can be checked by calling
   * `getHomeAddressInformation` and `isDeployable` with the same key.
   * @param key bytes32 The unique value used to derive the home address.
   * @param initializationRuntimeStorageContract address The storage contract
   * with runtime code equal to the contract creation code that will be used to
   * deploy the contract to the home address.
   * @return The home address and runtime code hash of the deployed contract.
   * @dev When deploying a contract to a home address via this method, the
   * metamorphic initialization code will retrieve whatever initialization code
   * currently resides at the specified address and use it to set up and deploy
   * the desired contract to the home address. Bear in mind that the deployed
   * contract will interpret msg.sender as the address of THIS contract, and not
   * the address of the submitter - if the constructor of the deployed contract
   * uses msg.sender to set up ownership or other variables, you must modify it
   * to accept a constructor argument with the appropriate address, or
   * alternately to hard-code the intended address. Also, if your contract DOES
   * have constructor arguments, remember to include them as ABI-encoded
   * arguments at the end of the initialization code, just as you would when
   * performing a standard deploy. You may also want to provide the key to
   * `setReverseLookup` in order to find it again using only the home address to
   * prevent accidentally losing the key.
   */
  function deployViaExistingRuntimeStorageContract(
    bytes32 key,
    address initializationRuntimeStorageContract
  )
    external
    payable
    returns (address homeAddress, bytes32 runtimeCodeHash);

  /**
   * @notice Burn an ERC721 token, set a supplied controller, and deploy a new
   * contract with the initialization code stored in the runtime code at the
   * specified initialization runtime storage contract to the home address
   * corresponding to a given key. The submitter must be designated as either
   * the owner of the token or as an approved spender.
   * @param tokenId uint256 The ID of the ERC721 token to redeem.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given token.
   * @param initializationRuntimeStorageContract address The storage contract
   * with runtime code equal to the contract creation code that will be used to
   * deploy the contract to the home address.
   * @return The home address and runtime code hash of the deployed contract.
   * @dev When deploying a contract to a home address via this method, the
   * metamorphic initialization code will retrieve whatever initialization code
   * currently resides at the specified address and use it to set up and deploy
   * the desired contract to the home address. Bear in mind that the deployed
   * contract will interpret msg.sender as the address of THIS contract, and not
   * the address of the submitter - if the constructor of the deployed contract
   * uses msg.sender to set up ownership or other variables, you must modify it
   * to accept a constructor argument with the appropriate address, or
   * alternately to hard-code the intended address. Also, if your contract DOES
   * have constructor arguments, remember to include them as ABI-encoded
   * arguments at the end of the initialization code, just as you would when
   * performing a standard deploy. You may also want to provide the key to
   * `setReverseLookup` in order to find it again using only the home address to
   * prevent accidentally losing the key. The controller cannot be designated as
   * the address of this contract, the null address, or the home address (the
   * restriction on setting the home address as the controller is due to the
   * fact that the home address will not be able to deploy to itself, as it
   * needs to be empty before a contract can be deployed to it). Also, checks on
   * the contract at the home address being empty or not having the correct
   * controller are unnecessary, as they are performed when minting the token
   * and cannot be altered until the token is redeemed.
   */
  function redeemAndDeployViaExistingRuntimeStorageContract(
    uint256 tokenId,
    address controller,
    address initializationRuntimeStorageContract
  )
    external
    payable
    returns (address homeAddress, bytes32 runtimeCodeHash);

  /**
   * @notice Deploy a new contract with the desired initialization code to the
   * home address corresponding to a given derived key. Two conditions must be
   * met: the submitter must be designated as the controller of the home
   * address, and there must not be a contract currently deployed at the home
   * address. These conditions can be checked by calling
   * `getHomeAddressInformation` and `isDeployable` with the key obtained by
   * calling `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param initializationCode bytes The contract creation code that will be
   * used to deploy the contract to the home address.
   * @return The home address, derived key, and runtime code hash of the
   * deployed contract.
   * @dev In order to deploy the contract to the home address, a new contract
   * will be deployed with runtime code set to the initialization code of the
   * contract that will be deployed to the home address. Then, metamorphic
   * initialization code will retrieve that initialization code and use it to
   * set up and deploy the desired contract to the home address. Bear in mind
   * that the deployed contract will interpret msg.sender as the address of THIS
   * contract, and not the address of the submitter - if the constructor of the
   * deployed contract uses msg.sender to set up ownership or other variables,
   * you must modify it to accept a constructor argument with the appropriate
   * address, or alternately to hard-code the intended address. Also, if your
   * contract DOES have constructor arguments, remember to include them as
   * ABI-encoded arguments at the end of the initialization code, just as you
   * would when performing a standard deploy. You may want to provide the salt
   * and submitter to `setDerivedReverseLookup` in order to find the salt,
   * submitter, and derived key using only the home address to prevent
   * accidentally losing them.
   */
  function deriveKeyAndDeploy(bytes32 salt, bytes calldata initializationCode)
    external
    payable
    returns (address homeAddress, bytes32 key, bytes32 runtimeCodeHash);

  /**
   * @notice Deploy a new contract with the initialization code stored in the
   * runtime code at the specified initialization runtime storage contract to
   * the home address corresponding to a given derived key. Two conditions must
   * be met: the submitter must be designated as the controller of the home
   * address, and there must not be a contract currently deployed at the home
   * address. These conditions can be checked by calling
   * `getHomeAddressInformation` and `isDeployable` with the key obtained by
   * calling `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param initializationRuntimeStorageContract address The storage contract
   * with runtime code equal to the contract creation code that will be used to
   * deploy the contract to the home address.
   * @return The home address, derived key, and runtime code hash of the
   * deployed contract.
   * @dev When deploying a contract to a home address via this method, the
   * metamorphic initialization code will retrieve whatever initialization code
   * currently resides at the specified address and use it to set up and deploy
   * the desired contract to the home address. Bear in mind that the deployed
   * contract will interpret msg.sender as the address of THIS contract, and not
   * the address of the submitter - if the constructor of the deployed contract
   * uses msg.sender to set up ownership or other variables, you must modify it
   * to accept a constructor argument with the appropriate address, or
   * alternately to hard-code the intended address. Also, if your contract DOES
   * have constructor arguments, remember to include them as ABI-encoded
   * arguments at the end of the initialization code, just as you would when
   * performing a standard deploy. You may want to provide the salt and
   * submitter to `setDerivedReverseLookup` in order to find the salt,
   * submitter, and derived key using only the home address to prevent
   * accidentally losing them.
   */
  function deriveKeyAndDeployViaExistingRuntimeStorageContract(
    bytes32 salt,
    address initializationRuntimeStorageContract
  )
    external
    payable
    returns (address homeAddress, bytes32 key, bytes32 runtimeCodeHash);

  /**
   * @notice Mint multiple ERC721 tokens, designated by their keys, to the
   * specified owner. Keys that aren't controlled, or that point to home
   * addresses that are currently deployed, will be skipped.
   * @param owner address The account that will be granted ownership of the
   * ERC721 tokens.
   * @param keys bytes32[] An array of values used to derive each home address.
   * @dev If you plan to use this method regularly or want to keep gas costs to
   * an absolute minimum, and are willing to go without standard ABI encoding,
   * see `batchLock_63efZf` for a more efficient (and unforgiving)
   * implementation. For batch token minting with *derived* keys, see
   * `deriveKeysAndBatchLock`.
   */
  function batchLock(address owner, bytes32[] calldata keys) external;

  /**
   * @notice Mint multiple ERC721 tokens, designated by salts that are hashed
   * with the caller's address to derive each key, to the specified owner.
   * Derived keys that aren't controlled, or that point to home addresses that
   * are currently deployed, will be skipped.
   * @param owner address The account that will be granted ownership of the
   * ERC721 tokens.
   * @param salts bytes32[] An array of values used to derive each key and
   * corresponding home address.
   * @dev See `batchLock` for batch token minting with standard, non-derived
   * keys.
   */
  function deriveKeysAndBatchLock(address owner, bytes32[] calldata salts)
    external;

  /**
   * @notice Efficient version of `batchLock` that uses less gas. The first 20
   * bytes of each key are automatically populated using msg.sender, and the
   * remaining key segments are passed in as a packed byte array, using twelve
   * bytes per segment, with a function selector of 0x00000000 followed by a
   * twenty-byte segment for the desired owner of the minted ERC721 tokens. Note
   * that an attempt to lock a key that is not controlled or with its contract
   * already deployed will cause the entire batch to revert. Checks on whether
   * the owner is a valid ERC721 receiver are also skipped, similar to using
   * `transferFrom` instead of `safeTransferFrom`.
   */
  function batchLock_63efZf(/* packed owner and key segments */) external;

  /**
   * @notice Submit a key to claim the "high score" - the lower the uint160
   * value of the key's home address, the higher the score. The high score
   * holder has the exclusive right to recover lost ether and tokens on this
   * contract.
   * @param key bytes32 The unique value used to derive the home address that
   * will determine the resultant score.
   * @dev The high score must be claimed by a direct key (one that is submitted
   * by setting the first 20 bytes of the key to the address of the submitter)
   * and not by a derived key, and is non-transferrable. If you want to help
   * people recover their lost tokens, you might consider deploying a contract
   * to the high score address (probably a metamorphic one so that you can use
   * the home address later) with your contact information.
   */
  function claimHighScore(bytes32 key) external;

  /**
   * @notice Transfer any ether or ERC20 tokens that have somehow ended up at
   * this contract by specifying a token address (set to the null address for
   * ether) as well as a recipient address. Only the high score holder can
   * recover lost ether and tokens on this contract.
   * @param token address The contract address of the ERC20 token to recover, or
   * the null address for recovering PMC.
   * @param recipient address payable The account where recovered funds should
   * be transferred.
   * @dev If you are trying to recover funds that were accidentally sent into
   * this contract, see if you can contact the holder of the current high score,
   * found by calling `getHighScore`. Better yet, try to find a new high score
   * yourself!
   */
  function recover(IERC20 token, address payable recipient) external;

  /**
   * @notice "View" function to determine if a contract can currently be
   * deployed to a home address given the corresponding key. A contract is only
   * deployable if no account currently exists at the address - any existing
   * contract must be destroyed via `SELFDESTRUCT` before a new contract can be
   * deployed to a home address. This method does not modify state but is
   * inaccessible via staticcall.
   * @param key bytes32 The unique value used to derive the home address.
   * @return A boolean signifying if a contract can be deployed to the home
   * address that corresponds to the provided key.
   * @dev This will not detect if a contract is not deployable due control
   * having been relinquished on the key.
   */
  function isDeployable(bytes32 key)
    external
    /* view */
    returns (bool deployable);

  /**
   * @notice View function to get the current "high score", or the lowest
   * uint160 value of a home address of all keys submitted. The high score
   * holder has the exclusive right to recover lost ether and tokens on this
   * contract.
   * @return The current high score holder, their score, and the submitted key.
   */
  function getHighScore()
    external
    view
    returns (address holder, uint256 score, bytes32 key);

  /**
   * @notice View function to get information on a home address given the
   * corresponding key.
   * @param key bytes32 The unique value used to derive the home address.
   * @return The home address, the current controller of the address, the number
   * of times the home address has been deployed to, and the code hash of the
   * runtime currently found at the home address, if any.
   * @dev There is also an `isDeployable` method for determining if a contract
   * can be deployed to the address, but in extreme cases it must actually
   * perform a dry-run to determine if the contract is deployable, which means
   * that it does not support staticcalls. There is also a convenience method,
   * `hasNeverBeenDeployed`, but the information it conveys can be determined
   * from this method alone as well.
   */
  function getHomeAddressInformation(bytes32 key)
    external
    view
    returns (
      address homeAddress,
      address controller,
      uint256 deploys,
      bytes32 currentRuntimeCodeHash
    );

  /**
   * @notice View function to determine if no contract has ever been deployed to
   * a home address given the corresponding key. This can be used to ensure that
   * a given key or corresponding token is "new" or not.
   * @param key bytes32 The unique value used to derive the home address.
   * @return A boolean signifying if a contract has never been deployed using
   * the supplied key before.
   */
  function hasNeverBeenDeployed(bytes32 key)
    external
    view
    returns (bool neverBeenDeployed);

  /**
   * @notice View function to search for a known key, salt, and/or submitter
   * given a supplied home address. Keys can be controlled directly by an
   * address that matches the first 20 bytes of the key, or they can be derived
   * from a salt and a submitter - if the key is not a derived key, the salt and
   * submitter fields will both have a value of zero.
   * @param homeAddress address The home address to check for key information.
   * @return The key, salt, and/or submitter used to deploy to the home address,
   * assuming they have been submitted to the reverse lookup.
   * @dev To populate these values, call `setReverseLookup` for cases where keys
   * are used directly or are the only value known, or `setDerivedReverseLookup`
   * for cases where keys are derived from a known salt and submitter.
   */
  function reverseLookup(address homeAddress)
    external
    view
    returns (bytes32 key, bytes32 salt, address submitter);

  /**
   * @notice Pure function to determine the key that is derived from a given
   * salt and submitting address.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param submitter address The submitter of the salt value used to derive the
   * key.
   * @return The derived key.
   */
  function getDerivedKey(bytes32 salt, address submitter)
    external
    pure
    returns (bytes32 key);

  /**
   * @notice Pure function to determine the home address that corresponds to
   * a given key.
   * @param key bytes32 The unique value used to derive the home address.
   * @return The home address.
   */
  function getHomeAddress(bytes32 key)
    external
    pure
    returns (address homeAddress);

  /**
   * @notice Pure function for retrieving the metamorphic initialization code
   * used to deploy arbitrary contracts to home addresses. Provided for easy
   * verification and for use in other applications.
   * @return The 32-byte metamorphic initialization code.
   * @dev This metamorphic init code works via the "metamorphic delegator"
   * mechanism, which is explained in greater detail at `_deployToHomeAddress`.
   */
  function getMetamorphicDelegatorInitializationCode()
    external
    pure
    returns (bytes32 metamorphicDelegatorInitializationCode);

  /**
   * @notice Pure function for retrieving the keccak256 of the metamorphic
   * initialization code used to deploy arbitrary contracts to home addresses.
   * This is the value that you should use, along with this contract's address
   * and a caller address that you control, to mine for an partucular type of
   * home address (such as one at a compact or gas-efficient address).
   * @return The keccak256 hash of the metamorphic initialization code.
   */
  function getMetamorphicDelegatorInitializationCodeHash()
    external
    pure
    returns (bytes32 metamorphicDelegatorInitializationCodeHash);

  /**
   * @notice Pure function for retrieving the prelude that will be inserted
   * ahead of the code payload in order to deploy a runtime storage contract.
   * @return The 11-byte "arbitrary runtime" prelude.
   */
  function getArbitraryRuntimeCodePrelude()
    external
    pure
    returns (bytes11 prelude);
}


/**
 * @title ERC721 Non-Fungible Token Standard basic interface
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}


/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable {
    function totalSupply() external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);
    function tokenByIndex(uint256 index) external view returns (uint256);
}


/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata {
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @notice Handle the receipt of an NFT
     * @dev The ERC721 smart contract calls this function on the recipient
     * after a `safeTransfer`. This function MUST return the function selector,
     * otherwise the caller will revert the transaction. The selector to be
     * returned can be obtained as `this.onERC721Received.selector`. This
     * function MAY throw to revert and reject the transfer.
     * Note: the ERC721 contract address is always the message sender.
     * @param operator The address which called `safeTransferFrom` function
     * @param from The address which previously owned the token
     * @param tokenId The NFT identifier which is being transferred
     * @param data Additional data with no specified format
     * @return bytes4 `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
      external
      returns (bytes4);
}


/**
 * @title ERC1412 Batch Transfers For Non-Fungible Tokens
 * @dev the ERC-165 identifier for this interface is 0x2b89bcaa
 */
interface IERC1412 {
  /// @notice Transfers the ownership of multiple NFTs from one address to another address
  /// @param _from The current owner of the NFT
  /// @param _to The new owner
  /// @param _tokenIds The NFTs to transfer
  /// @param _data Additional data with no specified format, sent in call to `_to`
  function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _tokenIds, bytes calldata _data) external;

  /// @notice Transfers the ownership of multiple NFTs from one address to another address
  /// @param _from The current owner of the NFT
  /// @param _to The new owner
  /// @param _tokenIds The NFTs to transfer
  function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _tokenIds) external;
}


/**
 * @title IERC165
 * @dev https://eips.ethereum.org/EIPS/eip-165
 */
interface IERC165 {
    /**
     * @notice Query if a contract implements an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @dev Interface identification is specified in ERC-165. This function
     * uses less than 30,000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

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
 * Utility library of inline functions on addresses
 */
library Address {
    /**
     * Returns whether the target address is a contract
     * @dev This function will return false if invoked during the constructor of a contract,
     * as the code is not actually created until after the constructor finishes.
     * @param account address of the account to check
     * @return whether the target address is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}


/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented or decremented by one. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids
 *
 * Include with `using Counters for Counters.Counter;`
 * Since it is not possible to overflow a 256 bit integer with increments of one, `increment` can skip the SafeMath
 * overflow check, thereby saving gas. This does assume however correct usage, in that the underlying `_value` is never
 * directly accessed.
 */
library Counters {
    using SafeMath for uint256;

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        counter._value += 1;
    }

    function decrement(Counter storage counter) internal {
        counter._value = counter._value.sub(1);
    }
}


/**
 * @dev Implementation of the `IERC165` interface.
 *
 * Contracts may inherit from this and call `_registerInterface` to declare
 * their support of an interface.
 */
contract ERC165 is IERC165 {
    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor () internal {
        // Derived contracts need only register support for their own interfaces,
        // we register support for ERC165 itself here
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    /**
     * @dev See `IERC165.supportsInterface`.
     *
     * Time complexity O(1), guaranteed to always use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See `IERC165.supportsInterface`.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}


/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
contract ERC721 is ERC165, IERC721 {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from token ID to owner
    mapping (uint256 => address) private _tokenOwner;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to number of owned token
    mapping (address => Counters.Counter) private _ownedTokensCount;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    /*
     * 0x80ac58cd ===
     *     bytes4(keccak256('balanceOf(address)')) ^
     *     bytes4(keccak256('ownerOf(uint256)')) ^
     *     bytes4(keccak256('approve(address,uint256)')) ^
     *     bytes4(keccak256('getApproved(uint256)')) ^
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) ^
     *     bytes4(keccak256('isApprovedForAll(address,address)')) ^
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) ^
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) ^
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
     */

    constructor () public {
        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
    }

    /**
     * @dev Gets the balance of the specified address
     * @param owner address to query the balance of
     * @return uint256 representing the amount owned by the passed address
     */
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0));
        return _ownedTokensCount[owner].current();
    }

    /**
     * @dev Gets the owner of the specified token ID
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _tokenOwner[tokenId];
        require(owner != address(0));
        return owner;
    }

    /**
     * @dev Approves another address to transfer the given token ID
     * The zero address indicates there is no approved address.
     * There can only be one approved address per token at a given time.
     * Can only be called by the token owner or an approved operator.
     * @param to address to be approved for the given token ID
     * @param tokenId uint256 ID of the token to be approved
     */
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner);
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender));

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Gets the approved address for a token ID, or zero if no address set
     * Reverts if the token ID does not exist.
     * @param tokenId uint256 ID of the token to query the approval of
     * @return address currently approved for the given token ID
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId));
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Sets or unsets the approval of a given operator
     * An operator is allowed to transfer all tokens of the sender on their behalf
     * @param to operator address to set the approval
     * @param approved representing the status of the approval to be set
     */
    function setApprovalForAll(address to, bool approved) public {
        require(to != msg.sender);
        _operatorApprovals[msg.sender][to] = approved;
        emit ApprovalForAll(msg.sender, to, approved);
    }

    /**
     * @dev Tells whether an operator is approved by a given owner
     * @param owner owner address which you want to query the approval of
     * @param operator operator address which you want to query the approval of
     * @return bool whether the given operator is approved by the given owner
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Transfers the ownership of a given token ID to another address
     * Usage of this method is discouraged, use `safeTransferFrom` whenever possible
     * Requires the msg.sender to be the owner, approved, or operator
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId));

        _transferFrom(from, to, tokenId);
    }

    /**
     * @dev Safely transfers the ownership of a given token ID to another address
     * If the target address is a contract, it must implement `onERC721Received`,
     * which is called upon a safe transfer, and return the magic value
     * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
     * the transfer is reverted.
     * Requires the msg.sender to be the owner, approved, or operator
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev Safely transfers the ownership of a given token ID to another address
     * If the target address is a contract, it must implement `onERC721Received`,
     * which is called upon a safe transfer, and return the magic value
     * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
     * the transfer is reverted.
     * Requires the msg.sender to be the owner, approved, or operator
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes data to send along with a safe transfer check
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data));
    }

    /**
     * @dev Returns whether the specified token exists
     * @param tokenId uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        address owner = _tokenOwner[tokenId];
        return owner != address(0);
    }

    /**
     * @dev Returns whether the given spender can transfer a given token ID
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether the msg.sender is approved for the given token ID,
     * is an operator of the owner, or is the owner of the token
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Internal function to mint a new token
     * Reverts if the given token ID already exists
     * @param to The address that will own the minted token
     * @param tokenId uint256 ID of the token to be minted
     */
    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0));
        require(!_exists(tokenId));

        _tokenOwner[tokenId] = to;
        _ownedTokensCount[to].increment();

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Internal function to burn a specific token
     * Reverts if the token does not exist
     * Deprecated, use _burn(uint256) instead.
     * @param owner owner of the token to burn
     * @param tokenId uint256 ID of the token being burned
     */
    function _burn(address owner, uint256 tokenId) internal {
        require(ownerOf(tokenId) == owner);

        _clearApproval(tokenId);

        _ownedTokensCount[owner].decrement();
        _tokenOwner[tokenId] = address(0);

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Internal function to burn a specific token
     * Reverts if the token does not exist
     * @param tokenId uint256 ID of the token being burned
     */
    function _burn(uint256 tokenId) internal {
        _burn(ownerOf(tokenId), tokenId);
    }

    /**
     * @dev Internal function to transfer ownership of a given token ID to another address.
     * As opposed to transferFrom, this imposes no restrictions on msg.sender.
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     */
    function _transferFrom(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from);
        require(to != address(0));

        _clearApproval(tokenId);

        _ownedTokensCount[from].decrement();
        _ownedTokensCount[to].increment();

        _tokenOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Internal function to invoke `onERC721Received` on a target address
     * The call is not executed if the target address is not a contract
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        internal returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }

        bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data);
        return (retval == _ERC721_RECEIVED);
    }

    /**
     * @dev Private function to clear current approval of a given token ID
     * @param tokenId uint256 ID of the token to be transferred
     */
    function _clearApproval(uint256 tokenId) private {
        if (_tokenApprovals[tokenId] != address(0)) {
            _tokenApprovals[tokenId] = address(0);
        }
    }
}


/**
 * @title ERC-721 Non-Fungible Token with optional enumeration extension logic
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
contract ERC721Enumerable is ERC165, ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => uint256[]) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    /**
     * @dev Constructor function.
     */
    constructor () public {
        // register the supported interface to conform to ERC721Enumerable via ERC165
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    /**
     * @dev Gets the token ID at a given index of the tokens list of the requested owner.
     * @param owner address owning the tokens list to be accessed
     * @param index uint256 representing the index to be accessed of the requested tokens list
     * @return uint256 token ID at the given index of the tokens list owned by the requested address
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        require(index < balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev Gets the total amount of tokens stored by the contract.
     * @return uint256 representing the total amount of tokens
     */
    function totalSupply() public view returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev Gets the token ID at a given index of all the tokens in this contract
     * Reverts if the index is greater or equal to the total number of tokens.
     * @param index uint256 representing the index to be accessed of the tokens list
     * @return uint256 token ID at the given index of the tokens list
     */
    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Internal function to transfer ownership of a given token ID to another address.
     * As opposed to transferFrom, this imposes no restrictions on msg.sender.
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     */
    function _transferFrom(address from, address to, uint256 tokenId) internal {
        super._transferFrom(from, to, tokenId);

        _removeTokenFromOwnerEnumeration(from, tokenId);

        _addTokenToOwnerEnumeration(to, tokenId);
    }

    /**
     * @dev Internal function to mint a new token.
     * Reverts if the given token ID already exists.
     * @param to address the beneficiary that will own the minted token
     * @param tokenId uint256 ID of the token to be minted
     */
    function _mint(address to, uint256 tokenId) internal {
        super._mint(to, tokenId);

        _addTokenToOwnerEnumeration(to, tokenId);

        _addTokenToAllTokensEnumeration(tokenId);
    }

    /**
     * @dev Internal function to burn a specific token.
     * Reverts if the token does not exist.
     * Deprecated, use _burn(uint256) instead.
     * @param owner owner of the token to burn
     * @param tokenId uint256 ID of the token being burned
     */
    function _burn(address owner, uint256 tokenId) internal {
        super._burn(owner, tokenId);

        _removeTokenFromOwnerEnumeration(owner, tokenId);
        // Since tokenId will be deleted, we can clear its slot in _ownedTokensIndex to trigger a gas refund
        _ownedTokensIndex[tokenId] = 0;

        _removeTokenFromAllTokensEnumeration(tokenId);
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the _ownedTokensIndex mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _ownedTokens[from].length.sub(1);
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        _ownedTokens[from].length--;

        // Note that _ownedTokensIndex[tokenId] hasn't been cleared: it still points to the old slot (now occupied by
        // lastTokenId, or just over the end of the array if the token was the last one).
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length.sub(1);
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        _allTokens.length--;
        _allTokensIndex[tokenId] = 0;
    }
}


/**
 * @title HomeWork (version 1)
 * @author 0age
 * @notice Homework is a utility to find, share, and reuse "home" addresses for
 * contracts. Anyone can work to find a new home address by searching for keys,
 * a 32-byte value with the first 20 bytes equal to the finder's calling address
 * (or derived by hashing an arbitrary 32-byte salt and the caller's address),
 * and can then deploy any contract they like (even one with a constructor) to
 * the address, or mint an ERC721 token that the owner can redeem that will then
 * allow them to do the same. Also, if the contract is `SELFDESTRUCT`ed, a new
 * contract can be redeployed by the current controller to the same address!
 * @dev This contract allows contract addresses to be located ahead of time, and
 * for arbitrary bytecode to be deployed (and redeployed if so desired, i.e.
 * metamorphic contracts) to the located address by a designated controller. To
 * enable this, the contract first deploys an "initialization-code-in-runtime"
 * contract, with the creation code of the contract you want to deploy stored in
 * RUNTIME code. Then, to deploy the actual contract, it retrieves the address
 * of the storage contract and `DELEGATECALL`s into it to execute the init code
 * and, if successful, retrieves and returns the contract runtime code. Rather
 * than using a located address directly, you can also lock it in the contract
 * and mint and ERC721 token for it, which can then be redeemed in order to gain
 * control over deployment to the address (note that tokens may not be minted if
 * the contract they control currently has a deployed contract at that address).
 * Once a contract undergoes metamorphosis, all existing storage will be deleted
 * and any existing contract code will be replaced with the deployed contract
 * code of the new implementation contract. The mechanisms behind this contract
 * are highly experimental - proceed with caution and please share any exploits
 * or optimizations you discover.
 */
contract HomeWork is IHomeWork, ERC721Enumerable, IERC721Metadata, IERC1412 {
  // Allocate storage to track the current initialization-in-runtime contract.
  address private _initializationRuntimeStorageContract;

  // Finder of home address with lowest uint256 value can recover lost funds.
  bytes32 private _highScoreKey;

  // Track information on the Home address corresponding to each key.
  mapping (bytes32 => HomeAddress) private _home;

  // Provide optional reverse-lookup for key derivation of a given home address.
  mapping (address => KeyInformation) private _key;

  // Set 0xff + address(this) as a constant to use when deriving home addresses.
  bytes21 private constant _FF_AND_THIS_CONTRACT = bytes21(
    0xff0000000000001b84b1cb32787B0D64758d019317
  );

  // Set the address of the tokenURI runtime storage contract as a constant.
  address private constant _URI_END_SEGMENT_STORAGE = address(
    0x000000000071C1c84915c17BF21728BfE4Dac3f3
  );

  // Deploy arbitrary contracts to home addresses using metamorphic init code.
  bytes32 private constant _HOME_INIT_CODE = bytes32(
    0x5859385958601c335a585952fa1582838382515af43d3d93833e601e57fd5bf3
  );

  // Compute hash of above metamorphic init code in order to compute addresses.
  bytes32 private constant _HOME_INIT_CODE_HASH = bytes32(
    0x7816562e7f85866cae07183593075f3b5ec32aeff914a0693e20aaf39672babc
  );

  // Write arbitrary code to a contract's runtime using the following prelude.
  bytes11 private constant _ARBITRARY_RUNTIME_PRELUDE = bytes11(
    0x600b5981380380925939f3
  );

  // Set EIP165 interface IDs as constants (already set 165 and 721+enumerable).
  bytes4 private constant _INTERFACE_ID_HOMEWORK = 0xe5399799;
  /* this.deploy.selector ^ this.lock.selector ^ this.redeem.selector ^
     this.assignController.selector ^ this.relinquishControl.selector ^
     this.redeemAndDeploy.selector ^ this.deriveKey.selector ^
     this.deriveKeyAndLock.selector ^
     this.deriveKeyAndAssignController.selector ^
     this.deriveKeyAndRelinquishControl.selector ^
     this.setReverseLookup.selector ^ this.setDerivedReverseLookup.selector ^
     this.deployRuntimeStorageContract.selector ^
     this.deployViaExistingRuntimeStorageContract.selector ^
     this.redeemAndDeployViaExistingRuntimeStorageContract.selector ^
     this.deriveKeyAndDeploy.selector ^
     this.deriveKeyAndDeployViaExistingRuntimeStorageContract.selector ^
     this.batchLock.selector ^ this.deriveKeysAndBatchLock.selector ^
     this.batchLock_63efZf.selector ^ this.claimHighScore.selector ^
     this.recover.selector ^ this.isDeployable.selector ^
     this.getHighScore.selector ^ this.getHomeAddressInformation.selector ^
     this.hasNeverBeenDeployed.selector ^ this.reverseLookup.selector ^
     this.getDerivedKey.selector ^ this.getHomeAddress.selector ^
     this.getMetamorphicDelegatorInitializationCode.selector ^
     this.getMetamorphicDelegatorInitializationCodeHash.selector ^
     this.getArbitraryRuntimeCodePrelude.selector == 0xe5399799
  */

  bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

  bytes4 private constant _INTERFACE_ID_ERC1412_BATCH_TRANSFERS = 0x2b89bcaa;

  // Set name of this contract as a constant (hex encoding is to support emoji).
  string private constant _NAME = (
    hex"486f6d65576f726b20f09f8fa0f09f9ba0efb88f"
  );

  // Set symbol of this contract as a constant.
  string private constant _SYMBOL = "HWK";

  // Set the start of each token URI for issued ERC721 tokens as a constant.
  bytes private constant _URI_START_SEGMENT = abi.encodePacked(
    hex"646174613a6170706c69636174696f6e2f6a736f6e2c7b226e616d65223a22486f6d65",
    hex"253230416464726573732532302d2532303078"
  ); /* data:application/json,{"name":"Home%20Address%20-%200x */

  // Store reused revert messages as constants.
  string private constant _ACCOUNT_EXISTS = string(
    "Only non-existent accounts can be deployed or used to mint tokens."
  );

  string private constant _ONLY_CONTROLLER = string(
    "Only the designated controller can call this function."
  );

  string private constant _NO_INIT_CODE_SUPPLIED = string(
    "Cannot deploy a contract with no initialization code supplied."
  );

  /**
   * @notice In the constructor, verify that deployment addresses are correct
   * and that supplied constant hash value of the contract creation code used to
   * deploy arbitrary contracts to home addresses is valid, and set an initial
   * high score key with the null address as the high score "holder". ERC165
   * supported interfaces are all registered during initizialization as well.
   */
  constructor() public {
    // Verify that the deployment address is set correctly as a constant.
    assert(address(this) == address(uint160(uint168(_FF_AND_THIS_CONTRACT))));

    // Verify the derivation of the deployment address.
    bytes32 initialDeployKey = bytes32(
      0x486f6d65576f726b20f09f8fa0f09f9ba0efb88faa3c548a76f9bd3c000c0000
    );
    assert(address(this) == address(
      uint160(                      // Downcast to match the address type.
        uint256(                    // Convert to uint to truncate upper digits.
          keccak256(                // Compute the CREATE2 hash using 4 inputs.
            abi.encodePacked(       // Pack all inputs to the hash together.
              bytes1(0xff),         // Start with 0xff to distinguish from RLP.
              msg.sender,           // The deployer will be the caller.
              initialDeployKey,     // Pass in the supplied key as the salt.
              _HOME_INIT_CODE_HASH  // The metamorphic initialization code hash.
            )
          )
        )
      )
    ));

    // Verify the derivation of the tokenURI runtime storage address.
    bytes32 uriDeployKey = bytes32(
      0x486f6d65576f726b202d20746f6b656e55524920c21352fee5a62228db000000
    );
    bytes32 uriInitCodeHash = bytes32(
      0xdea98294867e3fdc48eb5975ecc53a79e2e1ea6e7e794137a9c34c4dd1565ba2
    );
    assert(_URI_END_SEGMENT_STORAGE == address(
      uint160(                      // Downcast to match the address type.
        uint256(                    // Convert to uint to truncate upper digits.
          keccak256(                // Compute the CREATE2 hash using 4 inputs.
            abi.encodePacked(       // Pack all inputs to the hash together.
              bytes1(0xff),         // Start with 0xff to distinguish from RLP.
              msg.sender,           // The deployer will be the caller.
              uriDeployKey,         // Pass in the supplied key as the salt.
              uriInitCodeHash       // The storage contract init code hash.
            )
          )
        )
      )
    ));

    // Verify that the correct runtime code is at the tokenURI storage contract.
    bytes32 expectedRuntimeStorageHash = bytes32(
      0x8834602968080bb1df9c44c9834c0a93533b72bbfa3865ee2c5be6a0c4125fc3
    );
    address runtimeStorage = _URI_END_SEGMENT_STORAGE;
    bytes32 runtimeStorageHash;
    assembly { runtimeStorageHash := extcodehash(runtimeStorage) }
    assert(runtimeStorageHash == expectedRuntimeStorageHash);

    // Verify that the supplied hash for the metamorphic init code is valid.
    assert(keccak256(abi.encode(_HOME_INIT_CODE)) == _HOME_INIT_CODE_HASH);

    // Set an initial high score key with the null address as the submitter.
    _highScoreKey = bytes32(
      0x0000000000000000000000000000000000000000ffffffffffffffffffffffff
    );

    // Register EIP165 interface for HomeWork.
    _registerInterface(_INTERFACE_ID_HOMEWORK);

    // Register EIP165 interface for ERC721 metadata.
    _registerInterface(_INTERFACE_ID_ERC721_METADATA);

    // Register EIP165 interface for ERC1412 (batch transfers).
    _registerInterface(_INTERFACE_ID_ERC1412_BATCH_TRANSFERS);
  }

  /**
   * @notice Deploy a new contract with the desired initialization code to the
   * home address corresponding to a given key. Two conditions must be met: the
   * submitter must be designated as the controller of the home address (with
   * the initial controller set to the address corresponding to the first twenty
   * bytes of the key), and there must not be a contract currently deployed at
   * the home address. These conditions can be checked by calling
   * `getHomeAddressInformation` and `isDeployable` with the same key.
   * @param key bytes32 The unique value used to derive the home address.
   * @param initializationCode bytes The contract creation code that will be
   * used to deploy the contract to the home address.
   * @return The home address of the deployed contract.
   * @dev In order to deploy the contract to the home address, a new contract
   * will be deployed with runtime code set to the initialization code of the
   * contract that will be deployed to the home address. Then, metamorphic
   * initialization code will retrieve that initialization code and use it to
   * set up and deploy the desired contract to the home address. Bear in mind
   * that the deployed contract will interpret msg.sender as the address of THIS
   * contract, and not the address of the submitter - if the constructor of the
   * deployed contract uses msg.sender to set up ownership or other variables,
   * you must modify it to accept a constructor argument with the appropriate
   * address, or alternately to hard-code the intended address. Also, if your
   * contract DOES have constructor arguments, remember to include them as
   * ABI-encoded arguments at the end of the initialization code, just as you
   * would when performing a standard deploy. You may also want to provide the
   * key to `setReverseLookup` in order to find it again using only the home
   * address to prevent accidentally losing the key.
   */
  function deploy(bytes32 key, bytes calldata initializationCode)
    external
    payable
    onlyEmpty(key)
    onlyControllerDeployer(key)
    returns (address homeAddress, bytes32 runtimeCodeHash)
  {
    // Ensure that initialization code was supplied.
    require(initializationCode.length > 0, _NO_INIT_CODE_SUPPLIED);

    // Deploy the initialization storage contract and set address in storage.
    _initializationRuntimeStorageContract = _deployRuntimeStorageContract(
      initializationCode
    );

    // Use metamorphic initialization code to deploy contract to home address.
    (homeAddress, runtimeCodeHash) = _deployToHomeAddress(key);
  }

  /**
   * @notice Mint an ERC721 token to the supplied owner that can be redeemed in
   * order to gain control of a home address corresponding to a given key. Two
   * conditions must be met: the submitter must be designated as the controller
   * of the home address (with the initial controller set to the address
   * corresponding to the first 20 bytes of the key), and there must not be a
   * contract currently deployed at the home address. These conditions can be
   * checked by calling `getHomeAddressInformation` and `isDeployable` with the
   * same key.
   * @param key bytes32 The unique value used to derive the home address.
   * @param owner address The account that will be granted ownership of the
   * ERC721 token.
   * @dev In order to mint an ERC721 token, the assocated home address cannot be
   * in use, or else the token will not be able to deploy to the home address.
   * The controller is set to this contract until the token is redeemed, at
   * which point the redeemer designates a new controller for the home address.
   * The key of the home address and the tokenID of the ERC721 token are the
   * same value, but different types (bytes32 vs. uint256).
   */
  function lock(bytes32 key, address owner)
    external
    onlyEmpty(key)
    onlyController(key)
  {
    // Ensure that the specified owner is a valid ERC721 receiver.
    _validateOwner(owner, key);

    // Get the HomeAddress storage struct from the mapping using supplied key.
    HomeAddress storage home = _home[key];

    // Set the exists flag to true and the controller to this contract.
    home.exists = true;
    home.controller = address(this);

    // Emit an event signifying that this contract is now the controller.
    emit NewController(key, address(this));

    // Mint the ERC721 token to the designated owner.
    _mint(owner, uint256(key));
  }

  /**
   * @notice Burn an ERC721 token to allow the supplied controller to gain the
   * ability to deploy to the home address corresponding to the key matching the
   * burned token. The submitter must be designated as either the owner of the
   * token or as an approved spender.
   * @param tokenId uint256 The ID of the ERC721 token to redeem.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given token.
   * @dev The controller cannot be designated as the address of this contract,
   * the null address, or the home address (the restriction on setting the home
   * address as the controller is due to the fact that the home address will not
   * be able to deploy to itself, as it needs to be empty before a contract can
   * be deployed to it).
   */
  function redeem(uint256 tokenId, address controller)
    external
    onlyTokenOwnerOrApprovedSpender(tokenId)
  {
    // Convert the token ID to a bytes32 key.
    bytes32 key = bytes32(tokenId);

    // Prevent the controller from being set to prohibited account values.
    _validateController(controller, key);

    // Burn the ERC721 token in question.
    _burn(tokenId);

    // Assign the new controller to the corresponding home address.
    _home[key].controller = controller;

    // Emit an event with the new controller.
    emit NewController(key, controller);
  }

  /**
   * @notice Transfer control over deployment to the home address corresponding
   * to a given key. The caller must be designated as the current controller of
   * the home address (with the initial controller set to the address
   * corresponding to the first 20 bytes of the key) - This condition can be
   * checked by calling `getHomeAddressInformation` with the same key.
   * @param key bytes32 The unique value used to derive the home address.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given key.
   * @dev The controller cannot be designated as the address of this contract,
   * the null address, or the home address (the restriction on setting the home
   * address as the controller is due to the fact that the home address will not
   * be able to deploy to itself, as it needs to be empty before a contract can
   * be deployed to it).
   */
  function assignController(bytes32 key, address controller)
    external
    onlyController(key)
  {
    // Prevent the controller from being set to prohibited account values.
    _validateController(controller, key);

    // Assign the new controller to the corresponding home address.
    HomeAddress storage home = _home[key];
    home.exists = true;
    home.controller = controller;

    // Emit an event with the new controller.
    emit NewController(key, controller);
  }

  /**
   * @notice Transfer control over deployment to the home address corresponding
   * to a given key to the null address, which will prevent it from being
   * deployed to again in the future. The caller must be designated as the
   * current controller of the corresponding home address (with the initial
   * controller set to the address corresponding to the first 20 bytes of the
   * key) - This condition can be checked by calling `getHomeAddressInformation`
   * with the same key.
   * @param key bytes32 The unique value used to derive the home address.
   */
  function relinquishControl(bytes32 key)
    external
    onlyController(key)
  {
    // Assign the null address as the controller of the given key.
    HomeAddress storage home = _home[key];
    home.exists = true;
    home.controller = address(0);

    // Emit an event with the null address as the controller.
    emit NewController(key, address(0));
  }

  /**
   * @notice Burn an ERC721 token, set a supplied controller, and deploy a new
   * contract with the supplied initialization code to the corresponding home
   * address for the given token. The submitter must be designated as either the
   * owner of the token or as an approved spender.
   * @param tokenId uint256 The ID of the ERC721 token to redeem.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given token.
   * @param initializationCode bytes The contract creation code that will be
   * used to deploy the contract to the home address.
   * @return The home address and runtime code hash of the deployed contract.
   * @dev In order to deploy the contract to the home address, a new contract
   * will be deployed with runtime code set to the initialization code of the
   * contract that will be deployed to the home address. Then, metamorphic
   * initialization code will retrieve that initialization code and use it to
   * set up and deploy the desired contract to the home address. Bear in mind
   * that the deployed contract will interpret msg.sender as the address of THIS
   * contract, and not the address of the submitter - if the constructor of the
   * deployed contract uses msg.sender to set up ownership or other variables,
   * you must modify it to accept a constructor argument with the appropriate
   * address, or alternately to hard-code the intended address. Also, if your
   * contract DOES have constructor arguments, remember to include them as
   * ABI-encoded arguments at the end of the initialization code, just as you
   * would when performing a standard deploy. You may also want to provide the
   * key to `setReverseLookup` in order to find it again using only the home
   * address to prevent accidentally losing the key. The controller cannot be
   * designated as the address of this contract, the null address, or the home
   * address (the restriction on setting the home address as the controller is
   * due to the fact that the home address will not be able to deploy to itself,
   * as it needs to be empty before a contract can be deployed to it). Also,
   * checks on the contract at the home address being empty or not having the
   * correct controller are unnecessary, as they are performed when minting the
   * token and cannot be altered until the token is redeemed.
   */
  function redeemAndDeploy(
    uint256 tokenId,
    address controller,
    bytes calldata initializationCode
  )
    external
    payable
    onlyTokenOwnerOrApprovedSpender(tokenId)
    returns (address homeAddress, bytes32 runtimeCodeHash)
  {
    // Ensure that initialization code was supplied.
    require(initializationCode.length > 0, _NO_INIT_CODE_SUPPLIED);

    // Convert the token ID to a bytes32 key.
    bytes32 key = bytes32(tokenId);

    // Prevent the controller from being set to prohibited account values.
    _validateController(controller, key);

    // Burn the ERC721 token in question.
    _burn(tokenId);

    // Deploy the initialization storage contract and set address in storage.
    _initializationRuntimeStorageContract = _deployRuntimeStorageContract(
      initializationCode
    );

    // Set provided controller and increment contract deploy count at once.
    HomeAddress storage home = _home[key];
    home.exists = true;
    home.controller = controller;
    home.deploys += 1;

    // Emit an event with the new controller.
    emit NewController(key, controller);

    // Use metamorphic initialization code to deploy contract to home address.
    (homeAddress, runtimeCodeHash) = _deployToHomeAddress(key);
  }

  /**
   * @notice Derive a new key by concatenating an arbitrary 32-byte salt value
   * and the address of the caller and performing a keccak256 hash. This allows
   * for the creation of keys with additional entropy where desired while also
   * preventing collisions with standard keys. The caller will be set as the
   * controller of the derived key.
   * @param salt bytes32 The desired salt value to use (along with the address
   * of the caller) when deriving the resultant key and corresponding home
   * address.
   * @return The derived key.
   * @dev Home addresses from derived keys will take longer to "mine" or locate,
   * as an additional hash must be performed when computing the corresponding
   * home address for each given salt input. Each caller will derive a different
   * key even if they are supplying the same salt value.
   */
  function deriveKey(bytes32 salt) external returns (bytes32 key) {
    // Derive the key using the supplied salt and the calling address.
    key = _deriveKey(salt, msg.sender);

    // Register key and set caller as controller if it is not yet registered.
    HomeAddress storage home = _home[key];
    if (!home.exists) {
      home.exists = true;
      home.controller = msg.sender;

      // Emit an event with the sender as the new controller.
      emit NewController(key, msg.sender);
    }
  }

  /**
   * @notice Mint an ERC721 token to the supplied owner that can be redeemed in
   * order to gain control of a home address corresponding to a given derived
   * key. Two conditions must be met: the submitter must be designated as the
   * current controller of the home address, and there must not be a contract
   * currently deployed at the home address. These conditions can be checked by
   * calling `getHomeAddressInformation` and `isDeployable` with the key
   * determined by calling `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param owner address The account that will be granted ownership of the
   * ERC721 token.
   * @return The derived key.
   * @dev In order to mint an ERC721 token, the assocated home address cannot be
   * in use, or else the token will not be able to deploy to the home address.
   * The controller is set to this contract until the token is redeemed, at
   * which point the redeemer designates a new controller for the home address.
   * The key of the home address and the tokenID of the ERC721 token are the
   * same value, but different types (bytes32 vs. uint256).
   */
  function deriveKeyAndLock(bytes32 salt, address owner)
    external
    returns (bytes32 key)
  {
    // Derive the key using the supplied salt and the calling address.
    key = _deriveKey(salt, msg.sender);

    // Ensure that the specified owner is a valid ERC721 receiver.
    _validateOwner(owner, key);

    // Ensure that a contract is not currently deployed to the home address.
    require(_isNotDeployed(key), _ACCOUNT_EXISTS);

    // Ensure that the caller is the controller of the derived key.
    HomeAddress storage home = _home[key];
    if (home.exists) {
      require(home.controller == msg.sender, _ONLY_CONTROLLER);
    }

    // Set the exists flag to true and the controller to this contract.
    home.exists = true;
    home.controller = address(this);

    // Mint the ERC721 token to the designated owner.
    _mint(owner, uint256(key));

    // Emit an event signifying that this contract is now the controller.
    emit NewController(key, address(this));
  }

  /**
   * @notice Transfer control over deployment to the home address corresponding
   * to a given derived key. The caller must be designated as the current
   * controller of the home address - This condition can be checked by calling
   * `getHomeAddressInformation` with the key obtained via `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given derived key.
   * @return The derived key.
   * @dev The controller cannot be designated as the address of this contract,
   * the null address, or the home address (the restriction on setting the home
   * address as the controller is due to the fact that the home address will not
   * be able to deploy to itself, as it needs to be empty before a contract can
   * be deployed to it).
   */
  function deriveKeyAndAssignController(bytes32 salt, address controller)
    external
    returns (bytes32 key)
  {
    // Derive the key using the supplied salt and the calling address.
    key = _deriveKey(salt, msg.sender);

    // Prevent the controller from being set to prohibited account values.
    _validateController(controller, key);

    // Ensure that the caller is the controller of the derived key.
    HomeAddress storage home = _home[key];
    if (home.exists) {
      require(home.controller == msg.sender, _ONLY_CONTROLLER);
    }

    // Assign the new controller to the corresponding home address.
    home.exists = true;
    home.controller = controller;

    // Emit an event with the new controller.
    emit NewController(key, controller);
  }

  /**
   * @notice Transfer control over deployment to the home address corresponding
   * to a given derived key to the null address, which will prevent it from
   * being deployed to again in the future. The caller must be designated as the
   * current controller of the home address - This condition can be checked by
   * calling `getHomeAddressInformation` with the key determined by calling
   * `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @return The derived key.
   */
  function deriveKeyAndRelinquishControl(bytes32 salt)
    external
    returns (bytes32 key)
  {
    // Derive the key using the supplied salt and the calling address.
    key = _deriveKey(salt, msg.sender);

    // Ensure that the caller is the controller of the derived key.
    HomeAddress storage home = _home[key];
    if (home.exists) {
      require(home.controller == msg.sender, _ONLY_CONTROLLER);
    }

    // Assign the null address as the controller of the given derived key.
    home.exists = true;
    home.controller = address(0);

    // Emit an event with the null address as the controller.
    emit NewController(key, address(0));
  }

  /**
   * @notice Record a key that corresponds to a given home address by supplying
   * said key and using it to derive the address. This enables reverse lookup
   * of a key using only the home address in question. This method may be called
   * by anyone - control of the key is not required.
   * @param key bytes32 The unique value used to derive the home address.
   * @dev This does not set the salt or submitter fields, as those apply only to
   * derived keys (although a derived key may also be set with this method, just
   * without the derived fields).
   */
  function setReverseLookup(bytes32 key) external {
    // Derive home address of given key and set home address and key in mapping.
    _key[_getHomeAddress(key)].key = key;
  }

  /**
   * @notice Record the derived key that corresponds to a given home address by
   * supplying the salt and submitter that were used to derive the key. This
   * facititates reverse lookup of the derivation method of a key using only the
   * home address in question. This method may be called by anyone - control of
   * the derived key is not required.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param submitter address The account that submits the salt that is used to
   * derive the key.
   */
  function setDerivedReverseLookup(bytes32 salt, address submitter) external {
    // Derive the key using the supplied salt and submitter.
    bytes32 key = _deriveKey(salt, submitter);

    // Derive home address and set it along with all other relevant information.
    _key[_getHomeAddress(key)] = KeyInformation({
      key: key,
      salt: salt,
      submitter: submitter
    });
  }

  /**
   * @notice Deploy a new storage contract with the supplied code as runtime
   * code without deploying a contract to a home address. This can be used to
   * store the contract creation code for use in future deployments of contracts
   * to home addresses.
   * @param codePayload bytes The code to set as the runtime code of the
   * deployed contract.
   * @return The address of the deployed storage contract.
   * @dev Consider placing adequate protections on the storage contract to
   * prevent unwanted callers from modifying or destroying it. Also, if you are
   * placing contract contract creation code into the runtime storage contract,
   * remember to include any constructor parameters as ABI-encoded arguments at
   * the end of the contract creation code, similar to how you would perform a
   * standard deployment.
   */
  function deployRuntimeStorageContract(bytes calldata codePayload)
    external
    returns (address runtimeStorageContract)
  {
    // Ensure that a code payload was supplied.
    require(codePayload.length > 0, "No runtime code payload supplied.");

    // Deploy payload to the runtime storage contract and return the address.
    runtimeStorageContract = _deployRuntimeStorageContract(codePayload);
  }

  /**
   * @notice Deploy a new contract with the initialization code stored in the
   * runtime code at the specified initialization runtime storage contract to
   * the home address corresponding to a given key. Two conditions must be met:
   * the submitter must be designated as the controller of the home address
   * (with the initial controller set to the address corresponding to the first
   * 20 bytes of the key), and there must not be a contract currently deployed
   * at the home address. These conditions can be checked by calling
   * `getHomeAddressInformation` and `isDeployable` with the same key.
   * @param key bytes32 The unique value used to derive the home address.
   * @param initializationRuntimeStorageContract address The storage contract
   * with runtime code equal to the contract creation code that will be used to
   * deploy the contract to the home address.
   * @return The home address and runtime code hash of the deployed contract.
   * @dev When deploying a contract to a home address via this method, the
   * metamorphic initialization code will retrieve whatever initialization code
   * currently resides at the specified address and use it to set up and deploy
   * the desired contract to the home address. Bear in mind that the deployed
   * contract will interpret msg.sender as the address of THIS contract, and not
   * the address of the submitter - if the constructor of the deployed contract
   * uses msg.sender to set up ownership or other variables, you must modify it
   * to accept a constructor argument with the appropriate address, or
   * alternately to hard-code the intended address. Also, if your contract DOES
   * have constructor arguments, remember to include them as ABI-encoded
   * arguments at the end of the initialization code, just as you would when
   * performing a standard deploy. You may also want to provide the key to
   * `setReverseLookup` in order to find it again using only the home address to
   * prevent accidentally losing the key.
   */
  function deployViaExistingRuntimeStorageContract(
    bytes32 key,
    address initializationRuntimeStorageContract
  )
    external
    payable
    onlyEmpty(key)
    onlyControllerDeployer(key)
    returns (address homeAddress, bytes32 runtimeCodeHash)
  {
    // Ensure that the supplied runtime storage contract is not empty.
    _validateRuntimeStorageIsNotEmpty(initializationRuntimeStorageContract);

    // Set initialization runtime storage contract address in contract storage.
    _initializationRuntimeStorageContract = initializationRuntimeStorageContract;

    // Use metamorphic initialization code to deploy contract to home address.
    (homeAddress, runtimeCodeHash) = _deployToHomeAddress(key);
  }

  /**
   * @notice Burn an ERC721 token, set a supplied controller, and deploy a new
   * contract with the initialization code stored in the runtime code at the
   * specified initialization runtime storage contract to the home address
   * corresponding to a given key. The submitter must be designated as either
   * the owner of the token or as an approved spender.
   * @param tokenId uint256 The ID of the ERC721 token to redeem.
   * @param controller address The account that will be granted control of the
   * home address corresponding to the given token.
   * @param initializationRuntimeStorageContract address The storage contract
   * with runtime code equal to the contract creation code that will be used to
   * deploy the contract to the home address.
   * @return The home address and runtime code hash of the deployed contract.
   * @dev When deploying a contract to a home address via this method, the
   * metamorphic initialization code will retrieve whatever initialization code
   * currently resides at the specified address and use it to set up and deploy
   * the desired contract to the home address. Bear in mind that the deployed
   * contract will interpret msg.sender as the address of THIS contract, and not
   * the address of the submitter - if the constructor of the deployed contract
   * uses msg.sender to set up ownership or other variables, you must modify it
   * to accept a constructor argument with the appropriate address, or
   * alternately to hard-code the intended address. Also, if your contract DOES
   * have constructor arguments, remember to include them as ABI-encoded
   * arguments at the end of the initialization code, just as you would when
   * performing a standard deploy. You may also want to provide the key to
   * `setReverseLookup` in order to find it again using only the home address to
   * prevent accidentally losing the key. The controller cannot be designated as
   * the address of this contract, the null address, or the home address (the
   * restriction on setting the home address as the controller is due to the
   * fact that the home address will not be able to deploy to itself, as it
   * needs to be empty before a contract can be deployed to it). Also, checks on
   * the contract at the home address being empty or not having the correct
   * controller are unnecessary, as they are performed when minting the token
   * and cannot be altered until the token is redeemed.
   */
  function redeemAndDeployViaExistingRuntimeStorageContract(
    uint256 tokenId,
    address controller,
    address initializationRuntimeStorageContract
  )
    external
    payable
    onlyTokenOwnerOrApprovedSpender(tokenId)
    returns (address homeAddress, bytes32 runtimeCodeHash)
  {
    // Ensure that the supplied runtime storage contract is not empty.
    _validateRuntimeStorageIsNotEmpty(initializationRuntimeStorageContract);

    // Convert the token ID to a bytes32 key.
    bytes32 key = bytes32(tokenId);

    // Prevent the controller from being set to prohibited account values.
    _validateController(controller, key);

    // Burn the ERC721 token in question.
    _burn(tokenId);

    // Set initialization runtime storage contract address in contract storage.
    _initializationRuntimeStorageContract = initializationRuntimeStorageContract;

    // Set provided controller and increment contract deploy count at once.
    HomeAddress storage home = _home[key];
    home.exists = true;
    home.controller = controller;
    home.deploys += 1;

    // Emit an event with the new controller.
    emit NewController(key, controller);

    // Use metamorphic initialization code to deploy contract to home address.
    (homeAddress, runtimeCodeHash) = _deployToHomeAddress(key);
  }

  /**
   * @notice Deploy a new contract with the desired initialization code to the
   * home address corresponding to a given derived key. Two conditions must be
   * met: the submitter must be designated as the controller of the home
   * address, and there must not be a contract currently deployed at the home
   * address. These conditions can be checked by calling
   * `getHomeAddressInformation` and `isDeployable` with the key obtained by
   * calling `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param initializationCode bytes The contract creation code that will be
   * used to deploy the contract to the home address.
   * @return The home address, derived key, and runtime code hash of the
   * deployed contract.
   * @dev In order to deploy the contract to the home address, a new contract
   * will be deployed with runtime code set to the initialization code of the
   * contract that will be deployed to the home address. Then, metamorphic
   * initialization code will retrieve that initialization code and use it to
   * set up and deploy the desired contract to the home address. Bear in mind
   * that the deployed contract will interpret msg.sender as the address of THIS
   * contract, and not the address of the submitter - if the constructor of the
   * deployed contract uses msg.sender to set up ownership or other variables,
   * you must modify it to accept a constructor argument with the appropriate
   * address, or alternately to hard-code the intended address. Also, if your
   * contract DOES have constructor arguments, remember to include them as
   * ABI-encoded arguments at the end of the initialization code, just as you
   * would when performing a standard deploy. You may want to provide the salt
   * and submitter to `setDerivedReverseLookup` in order to find the salt,
   * submitter, and derived key using only the home address to prevent
   * accidentally losing them.
   */
  function deriveKeyAndDeploy(bytes32 salt, bytes calldata initializationCode)
    external
    payable
    returns (address homeAddress, bytes32 key, bytes32 runtimeCodeHash)
  {
    // Ensure that initialization code was supplied.
    require(initializationCode.length > 0, _NO_INIT_CODE_SUPPLIED);

    // Derive key and prepare to deploy using supplied salt and calling address.
    key = _deriveKeyAndPrepareToDeploy(salt);

    // Deploy the initialization storage contract and set address in storage.
    _initializationRuntimeStorageContract = _deployRuntimeStorageContract(
      initializationCode
    );

    // Use metamorphic initialization code to deploy contract to home address.
    (homeAddress, runtimeCodeHash) = _deployToHomeAddress(key);
  }

  /**
   * @notice Deploy a new contract with the initialization code stored in the
   * runtime code at the specified initialization runtime storage contract to
   * the home address corresponding to a given derived key. Two conditions must
   * be met: the submitter must be designated as the controller of the home
   * address, and there must not be a contract currently deployed at the home
   * address. These conditions can be checked by calling
   * `getHomeAddressInformation` and `isDeployable` with the key obtained by
   * calling `getDerivedKey`.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param initializationRuntimeStorageContract address The storage contract
   * with runtime code equal to the contract creation code that will be used to
   * deploy the contract to the home address.
   * @return The home address, derived key, and runtime code hash of the
   * deployed contract.
   * @dev When deploying a contract to a home address via this method, the
   * metamorphic initialization code will retrieve whatever initialization code
   * currently resides at the specified address and use it to set up and deploy
   * the desired contract to the home address. Bear in mind that the deployed
   * contract will interpret msg.sender as the address of THIS contract, and not
   * the address of the submitter - if the constructor of the deployed contract
   * uses msg.sender to set up ownership or other variables, you must modify it
   * to accept a constructor argument with the appropriate address, or
   * alternately to hard-code the intended address. Also, if your contract DOES
   * have constructor arguments, remember to include them as ABI-encoded
   * arguments at the end of the initialization code, just as you would when
   * performing a standard deploy. You may want to provide the salt and
   * submitter to `setDerivedReverseLookup` in order to find the salt,
   * submitter, and derived key using only the home address to prevent
   * accidentally losing them.
   */
  function deriveKeyAndDeployViaExistingRuntimeStorageContract(
    bytes32 salt,
    address initializationRuntimeStorageContract
  )
    external
    payable
    returns (address homeAddress, bytes32 key, bytes32 runtimeCodeHash)
  {
    // Ensure that the supplied runtime storage contract is not empty.
    _validateRuntimeStorageIsNotEmpty(initializationRuntimeStorageContract);

    // Derive key and prepare to deploy using supplied salt and calling address.
    key = _deriveKeyAndPrepareToDeploy(salt);

    // Set the initialization runtime storage contract in contract storage.
    _initializationRuntimeStorageContract = initializationRuntimeStorageContract;

    // Use metamorphic initialization code to deploy contract to home address.
    (homeAddress, runtimeCodeHash) = _deployToHomeAddress(key);
  }

  /**
   * @notice Mint multiple ERC721 tokens, designated by their keys, to the
   * specified owner. Keys that aren't controlled, or that point to home
   * addresses that are currently deployed, will be skipped.
   * @param owner address The account that will be granted ownership of the
   * ERC721 tokens.
   * @param keys bytes32[] An array of values used to derive each home address.
   * @dev If you plan to use this method regularly or want to keep gas costs to
   * an absolute minimum, and are willing to go without standard ABI encoding,
   * see `batchLock_63efZf` for a more efficient (and unforgiving)
   * implementation. For batch token minting with *derived* keys, see
   * `deriveKeysAndBatchLock`.
   */
  function batchLock(address owner, bytes32[] calldata keys) external {
    // Track each key in the array of keys.
    bytes32 key;

    // Ensure that the specified owner is a valid ERC721 receiver.
    if (keys.length > 0) {
      _validateOwner(owner, keys[0]);
    }

    // Iterate through each provided key argument.
    for (uint256 i; i < keys.length; i++) {
      key = keys[i];

      // Skip if the key currently has a contract deployed to its home address.
      if (!_isNotDeployed(key)) {
        continue;
      }

      // Skip if the caller is not the controller.
      if (_getController(key) != msg.sender) {
        continue;
      }

      // Set the exists flag to true and the controller to this contract.
      HomeAddress storage home = _home[key];
      home.exists = true;
      home.controller = address(this);

      // Emit an event signifying that this contract is now the controller.
      emit NewController(key, address(this));

      // Mint the ERC721 token to the designated owner.
      _mint(owner, uint256(key));
    }
  }

  /**
   * @notice Mint multiple ERC721 tokens, designated by salts that are hashed
   * with the caller's address to derive each key, to the specified owner.
   * Derived keys that aren't controlled, or that point to home addresses that
   * are currently deployed, will be skipped.
   * @param owner address The account that will be granted ownership of the
   * ERC721 tokens.
   * @param salts bytes32[] An array of values used to derive each key and
   * corresponding home address.
   * @dev See `batchLock` for batch token minting with standard, non-derived
   * keys.
   */
  function deriveKeysAndBatchLock(address owner, bytes32[] calldata salts)
    external
  {
    // Track each key derived from the array of salts.
    bytes32 key;

    // Ensure that the specified owner is a valid ERC721 receiver.
    if (salts.length > 0) {
      _validateOwner(owner, _deriveKey(salts[0], msg.sender));
    }

    // Iterate through each provided salt argument.
    for (uint256 i; i < salts.length; i++) {
      // Derive the key using the supplied salt and the calling address.
      key = _deriveKey(salts[i], msg.sender);

      // Skip if the key currently has a contract deployed to its home address.
      if (!_isNotDeployed(key)) {
        continue;
      }

      // Skip if the caller is not the controller.
      HomeAddress storage home = _home[key];
      if (home.exists && home.controller != msg.sender) {
        continue;
      }

      // Set the exists flag to true and the controller to this contract.
      home.exists = true;
      home.controller = address(this);

      // Emit an event signifying that this contract is now the controller.
      emit NewController(key, address(this));

      // Mint the ERC721 token to the designated owner.
      _mint(owner, uint256(key));
    }
  }

  /**
   * @notice Safely transfers the ownership of a group of token IDs to another
   * address in a batch. If the target address is a contract, it must implement
   * `onERC721Received`, called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`;
   * otherwise, or if another error occurs, the entire batch is reverted.
   * Requires msg.sender to be the owner, approved, or operator of the tokens.
   * @param from address The current owner of the tokens.
   * @param to address The account to receive ownership of the given tokens.
   * @param tokenIds uint256[] ID of the tokens to be transferred.
   */
  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] calldata tokenIds
  )
    external
  {
    // Track each token ID in the batch.
    uint256 tokenId;

    // Iterate over each supplied token ID.
    for (uint256 i = 0; i < tokenIds.length; i++) {
      // Set the current token ID.
      tokenId = tokenIds[i];

      // Perform the token transfer.
      safeTransferFrom(from, to, tokenId);
    }
  }

  /**
   * @notice Safely transfers the ownership of a group of token IDs to another
   * address in a batch. If the target address is a contract, it must implement
   * `onERC721Received`, called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`;
   * otherwise, or if another error occurs, the entire batch is reverted.
   * Requires msg.sender to be the owner, approved, or operator of the tokens.
   * @param from address The current owner of the tokens.
   * @param to address The account to receive ownership of the given tokens.
   * @param tokenIds uint256[] ID of the tokens to be transferred.
   * @param data bytes A data payload to include with each transfer.
   */
  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] calldata tokenIds,
    bytes calldata data
  )
    external
  {
    // Track each token ID in the batch.
    uint256 tokenId;

    // Iterate over each supplied token ID.
    for (uint256 i = 0; i < tokenIds.length; i++) {
      // Set the current token ID.
      tokenId = tokenIds[i];

      // Perform the token transfer.
      safeTransferFrom(from, to, tokenId, data);
    }
  }

  /**
   * @notice Efficient version of `batchLock` that uses less gas. The first 20
   * bytes of each key are automatically populated using msg.sender, and the
   * remaining key segments are passed in as a packed byte array, using twelve
   * bytes per segment, with a function selector of 0x00000000 followed by a
   * twenty-byte segment for the desired owner of the minted ERC721 tokens. Note
   * that an attempt to lock a key that is not controlled or with its contract
   * already deployed will cause the entire batch to revert. Checks on whether
   * the owner is a valid ERC721 receiver are also skipped, similar to using
   * `transferFrom` instead of `safeTransferFrom`.
   */
  function batchLock_63efZf(/* packed owner and key segments */) external {
    // Get the owner from calldata, located at bytes 4-23 (sig is bytes 0-3).
    address owner;

    // Determine number of 12-byte key segments in calldata from byte 24 on.
    uint256 passedSaltSegments;

    // Get the owner and calculate the total number of key segments.
    assembly {
      owner := shr(0x60, calldataload(4))                  // comes after sig
      passedSaltSegments := div(sub(calldatasize, 24), 12) // after sig & owner
    }

    // Track each key, located at each 12-byte segment from byte 24 on.
    bytes32 key;

    // Iterate through each provided key segment argument.
    for (uint256 i; i < passedSaltSegments; i++) {
      // Construct keys by concatenating msg.sender with each key segment.
      assembly {
        key := add(                   // Combine msg.sender & provided key.
          shl(0x60, caller),          // Place msg.sender at start of word.
          shr(0xa0, calldataload(add(24, mul(i, 12))))   // Segment at end.
        )
      }

      // Ensure that the key does not currently have a deployed contract.
      require(_isNotDeployed(key), _ACCOUNT_EXISTS);

      // Ensure that the caller is the controller of the key.
      HomeAddress storage home = _home[key];
      if (home.exists) {
        require(home.controller == msg.sender, _ONLY_CONTROLLER);
      }

      // Set the exists flag to true and the controller to this contract.
      home.exists = true;
      home.controller = address(this);

      // Emit an event signifying that this contract is now the controller.
      emit NewController(key, address(this));

      // Mint the ERC721 token to the designated owner.
      _mint(owner, uint256(key));
    }
  }

  /**
   * @notice Perform a dry-run of the deployment of a contract using a given key
   * and revert on successful deployment. It cannot be called from outside the
   * contract (even though it is marked as external).
   * @param key bytes32 The unique value used to derive the home address.
   * @dev This contract is called by `_isNotDeployable` in extreme cases where
   * the deployability of the contract cannot be determined conclusively.
   */
  function staticCreate2Check(bytes32 key) external {
    require(
      msg.sender == address(this),
      "This function can only be called by this contract."
    );

    assembly {
      // Write the 32-byte metamorphic initialization code to scratch space.
      mstore(
        0,
        0x5859385958601c335a585952fa1582838382515af43d3d93833e601e57fd5bf3
      )

      // Call `CREATE2` using metamorphic init code with supplied key as salt.
      let deploymentAddress := create2(0, 0, 32, key)

      // Revert and return the metamorphic init code on successful deployment.
      if deploymentAddress {
        revert(0, 32)
      }
    }
  }

  /**
   * @notice Submit a key to claim the "high score" - the lower the uint160
   * value of the key's home address, the higher the score. The high score
   * holder has the exclusive right to recover lost ether and tokens on this
   * contract.
   * @param key bytes32 The unique value used to derive the home address that
   * will determine the resultant score.
   * @dev The high score must be claimed by a direct key (one that is submitted
   * by setting the first 20 bytes of the key to the address of the submitter)
   * and not by a derived key, and is non-transferrable. If you want to help
   * people recover their lost tokens, you might consider deploying a contract
   * to the high score address (probably a metamorphic one so that you can use
   * the home address later) with your contact information.
   */
  function claimHighScore(bytes32 key) external {
    require(
      msg.sender == address(bytes20(key)),
      "Only submitters directly encoded in a given key may claim a high score."
    );

    // Derive the "home address" of the current high score key.
    address currentHighScore = _getHomeAddress(_highScoreKey);

    // Derive the "home address" of the new high score key.
    address newHighScore = _getHomeAddress(key);

    // Use addresses to ensure that supplied key is in fact a new high score.
    require(
      uint160(newHighScore) < uint160(currentHighScore),
      "Submitted high score is not better than the current high score."
    );

    // Set the new high score to the supplied key.
    _highScoreKey = key;

    // The score is equal to (2^160 - 1) - ("home address" of high score key).
    uint256 score = uint256(uint160(-1) - uint160(newHighScore));

    // Emit an event to signify that a new high score has been reached.
    emit NewHighScore(key, msg.sender, score);
  }

  /**
   * @notice Transfer any ether or ERC20 tokens that have somehow ended up at
   * this contract by specifying a token address (set to the null address for
   * ether) as well as a recipient address. Only the high score holder can
   * recover lost ether and tokens on this contract.
   * @param token address The contract address of the ERC20 token to recover, or
   * the null address for recovering PMC.
   * @param recipient address payable The account where recovered funds should
   * be transferred.
   * @dev If you are trying to recover funds that were accidentally sent into
   * this contract, see if you can contact the holder of the current high score,
   * found by calling `getHighScore`. Better yet, try to find a new high score
   * yourself!
   */
  function recover(IERC20 token, address payable recipient) external {
    require(
      msg.sender == address(bytes20(_highScoreKey)),
      "Only the current high score holder may recover tokens."
    );

    if (address(token) == address(0)) {
      // Recover ETH if the token's contract address is set to the null address.
      recipient.transfer(address(this).balance);
    } else {
      // Determine the given ERC20 token balance and transfer to the recipient.
      uint256 balance = token.balanceOf(address(this));
      token.transfer(recipient, balance);
    }
  }

  /**
   * @notice "View" function to determine if a contract can currently be
   * deployed to a home address given the corresponding key. A contract is only
   * deployable if no account currently exists at the address - any existing
   * contract must be destroyed via `SELFDESTRUCT` before a new contract can be
   * deployed to a home address. This method does not modify state but is
   * inaccessible via staticcall.
   * @param key bytes32 The unique value used to derive the home address.
   * @return A boolean signifying if a contract can be deployed to the home
   * address that corresponds to the provided key.
   * @dev This will not detect if a contract is not deployable due control
   * having been relinquished on the key.
   */
  function isDeployable(bytes32 key)
    external
    /* view */
    returns (bool deployable)
  {
    deployable = _isNotDeployed(key);
  }

  /**
   * @notice View function to get the current "high score", or the lowest
   * uint160 value of a home address of all keys submitted. The high score
   * holder has the exclusive right to recover lost ether and tokens on this
   * contract.
   * @return The current high score holder, their score, and the submitted key.
   */
  function getHighScore()
    external
    view
    returns (address holder, uint256 score, bytes32 key)
  {
    // Get the key and subbmitter holding the current high score.
    key = _highScoreKey;
    holder = address(bytes20(key));

    // The score is equal to (2^160 - 1) - ("home address" of high score key).
    score = uint256(uint160(-1) - uint160(_getHomeAddress(key)));
  }

  /**
   * @notice View function to get information on a home address given the
   * corresponding key.
   * @param key bytes32 The unique value used to derive the home address.
   * @return The home address, the current controller of the address, the number
   * of times the home address has been deployed to, and the code hash of the
   * runtime currently found at the home address, if any.
   * @dev There is also an `isDeployable` method for determining if a contract
   * can be deployed to the address, but in extreme cases it must actually
   * perform a dry-run to determine if the contract is deployable, which means
   * that it does not support staticcalls. There is also a convenience method,
   * `hasNeverBeenDeployed`, but the information it conveys can be determined
   * from this method alone as well.
   */
  function getHomeAddressInformation(bytes32 key)
    external
    view
    returns (
      address homeAddress,
      address controller,
      uint256 deploys,
      bytes32 currentRuntimeCodeHash
    )
  {
    // Derive home address and retrieve other information using supplied key.
    homeAddress = _getHomeAddress(key);
    HomeAddress memory home = _home[key];

    // If the home address has not been seen before, use the default controller.
    if (!home.exists) {
      controller = address(bytes20(key));
    } else {
      controller = home.controller;
    }

    // Retrieve the count of total deploys to the home address.
    deploys = home.deploys;

    // Retrieve keccak256 hash of runtime code currently at the home address.
    assembly { currentRuntimeCodeHash := extcodehash(homeAddress) }
  }

  /**
   * @notice View function to determine if no contract has ever been deployed to
   * a home address given the corresponding key. This can be used to ensure that
   * a given key or corresponding token is "new" or not.
   * @param key bytes32 The unique value used to derive the home address.
   * @return A boolean signifying if a contract has never been deployed using
   * the supplied key before.
   */
  function hasNeverBeenDeployed(bytes32 key)
    external
    view
    returns (bool neverBeenDeployed)
  {
    neverBeenDeployed = (_home[key].deploys == 0);
  }

  /**
   * @notice View function to search for a known key, salt, and/or submitter
   * given a supplied home address. Keys can be controlled directly by an
   * address that matches the first 20 bytes of the key, or they can be derived
   * from a salt and a submitter - if the key is not a derived key, the salt and
   * submitter fields will both have a value of zero.
   * @param homeAddress address The home address to check for key information.
   * @return The key, salt, and/or submitter used to deploy to the home address,
   * assuming they have been submitted to the reverse lookup.
   * @dev To populate these values, call `setReverseLookup` for cases where keys
   * are used directly or are the only value known, or `setDerivedReverseLookup`
   * for cases where keys are derived from a known salt and submitter.
   */
  function reverseLookup(address homeAddress)
    external
    view
    returns (bytes32 key, bytes32 salt, address submitter)
  {
    KeyInformation memory keyInformation = _key[homeAddress];
    key = keyInformation.key;
    salt = keyInformation.salt;
    submitter = keyInformation.submitter;
  }

  /**
   * @notice View function used by the metamorphic initialization code when
   * deploying a contract to a home address. It returns the address of the
   * runtime storage contract that holds the contract creation code, which the
   * metamorphic creation code then `DELEGATECALL`s into in order to set up the
   * contract and deploy the target runtime code.
   * @return The current runtime storage contract that contains the target
   * contract creation code.
   * @dev This method is not meant to be part of the user-facing contract API,
   * but is rather a mechanism for enabling the deployment of arbitrary code via
   * fixed initialization code. The odd naming is chosen so that function
   * selector will be 0x00000009 - that way, the metamorphic contract can simply
   * use the `PC` opcode in order to push the selector to the stack.
   */
  function getInitializationCodeFromContractRuntime_6CLUNS()
    external
    view
    returns (address initializationRuntimeStorageContract)
  {
    // Return address of contract with initialization code set as runtime code.
    initializationRuntimeStorageContract = _initializationRuntimeStorageContract;
  }

  /**
   * @notice View function to return an URI for a given token ID. Throws if the
   * token ID does not exist.
   * @param tokenId uint256 ID of the token to query.
   * @return String representing the URI data encoding of JSON metadata.
   * @dev The URI returned by this method takes the following form (with all
   * returns and initial whitespace removed - it's just here for clarity):
   *
   * data:application/json,{
   *   "name":"Home%20Address%20-%200x********************",
   *   "description":"< ... HomeWork NFT desription ... >",
   *   "image":"data:image/svg+xml;charset=utf-8;base64,< ... Image ... >"}
   *
   * where ******************** represents the checksummed home address that the
   * token confers control over.
   */
  function tokenURI(uint256 tokenId)
    external
    view
    returns (string memory)
  {
    // Only return a URI for tokens that exist.
    require(_exists(tokenId), "A token with the given ID does not exist.");

    // Get the home address that the given tokenId corresponds to.
    address homeAddress = _getHomeAddress(bytes32(tokenId));

    // Get the checksummed, ascii-encoded representation of the home address.
    string memory asciiHomeAddress = _toChecksummedAsciiString(homeAddress);

    bytes memory uriEndSegment = _getTokenURIStorageRuntime();

    // Insert checksummed address into URI in name and image fields and return.
    return string(
      abi.encodePacked(      // Concatenate all the string segments together.
        _URI_START_SEGMENT,  // Data URI ID and initial formatting is constant.
        asciiHomeAddress,    // Checksummed home address is in the name field.
        uriEndSegment        // Description, image, and formatting is constant.
      )
    );
  }

  /**
   * @notice Pure function to get the token name.
   * @return String representing the token name.
   */
  function name() external pure returns (string memory) {
    return _NAME;
  }

  /**
   * @notice Pure function to get the token symbol.
   * @return String representing the token symbol.
   */
  function symbol() external pure returns (string memory) {
    return _SYMBOL;
  }

  /**
   * @notice Pure function to determine the key that is derived from a given
   * salt and submitting address.
   * @param salt bytes32 The salt value that is used to derive the key.
   * @param submitter address The submitter of the salt value used to derive the
   * key.
   * @return The derived key.
   */
  function getDerivedKey(bytes32 salt, address submitter)
    external
    pure
    returns (bytes32 key)
  {
    // Derive the key using the supplied salt and submitter.
    key = _deriveKey(salt, submitter);
  }

  /**
   * @notice Pure function to determine the home address that corresponds to
   * a given key.
   * @param key bytes32 The unique value used to derive the home address.
   * @return The home address.
   */
  function getHomeAddress(bytes32 key)
    external
    pure
    returns (address homeAddress)
  {
    // Derive the home address using the supplied key.
    homeAddress = _getHomeAddress(key);
  }

  /**
   * @notice Pure function for retrieving the metamorphic initialization code
   * used to deploy arbitrary contracts to home addresses. Provided for easy
   * verification and for use in other applications.
   * @return The 32-byte metamorphic initialization code.
   * @dev This metamorphic init code works via the "metamorphic delegator"
   * mechanism, which is explained in greater detail at `_deployToHomeAddress`.
   */
  function getMetamorphicDelegatorInitializationCode()
    external
    pure
    returns (bytes32 metamorphicDelegatorInitializationCode)
  {
    metamorphicDelegatorInitializationCode = _HOME_INIT_CODE;
  }

  /**
   * @notice Pure function for retrieving the keccak256 of the metamorphic
   * initialization code used to deploy arbitrary contracts to home addresses.
   * This is the value that you should use, along with this contract's address
   * and a caller address that you control, to mine for an partucular type of
   * home address (such as one at a compact or gas-efficient address).
   * @return The keccak256 hash of the metamorphic initialization code.
   */
  function getMetamorphicDelegatorInitializationCodeHash()
    external
    pure
    returns (bytes32 metamorphicDelegatorInitializationCodeHash)
  {
    metamorphicDelegatorInitializationCodeHash = _HOME_INIT_CODE_HASH;
  }

  /**
   * @notice Pure function for retrieving the prelude that will be inserted
   * ahead of the code payload in order to deploy a runtime storage contract.
   * @return The 11-byte "arbitrary runtime" prelude.
   */
  function getArbitraryRuntimeCodePrelude()
    external
    pure
    returns (bytes11 prelude)
  {
    prelude = _ARBITRARY_RUNTIME_PRELUDE;
  }

  /**
   * @notice Internal function for deploying a runtime storage contract given a
   * particular payload.
   * @return The address of the runtime storage contract.
   * @dev To take the provided code payload and deploy a contract with that
   * payload as its runtime code, use the following prelude:
   *
   * 0x600b5981380380925939f3...
   *
   * 00  60  push1 0b      [11 -> offset]
   * 02  59  msize         [offset, 0]
   * 03  81  dup2          [offset, 0, offset]
   * 04  38  codesize      [offset, 0, offset, codesize]
   * 05  03  sub           [offset, 0, codesize - offset]
   * 06  80  dup1          [offset, 0, codesize - offset, codesize - offset]
   * 07  92  swap3         [codesize - offset, 0, codesize - offset, offset]
   * 08  59  msize         [codesize - offset, 0, codesize - offset, offset, 0]
   * 09  39  codecopy      [codesize - offset, 0] <init_code_in_runtime>
   * 10  f3  return        [] *init_code_in_runtime*
   * ... init_code
   */
  function _deployRuntimeStorageContract(bytes memory payload)
    internal
    returns (address runtimeStorageContract)
  {
    // Construct the contract creation code using the prelude and the payload.
    bytes memory runtimeStorageContractCreationCode = abi.encodePacked(
      _ARBITRARY_RUNTIME_PRELUDE,
      payload
    );

    assembly {
      // Get the location and length of the newly-constructed creation code.
      let encoded_data := add(0x20, runtimeStorageContractCreationCode)
      let encoded_size := mload(runtimeStorageContractCreationCode)

      // Deploy the runtime storage contract via standard `CREATE`.
      runtimeStorageContract := create(0, encoded_data, encoded_size)

      // Pass along revert message if the contract did not deploy successfully.
      if iszero(runtimeStorageContract) {
        returndatacopy(0, 0, returndatasize)
        revert(0, returndatasize)
      }
    }

    // Emit an event with address of newly-deployed runtime storage contract.
    emit NewRuntimeStorageContract(runtimeStorageContract, keccak256(payload));
  }

  /**
   * @notice Internal function for deploying arbitrary contract code to the home
   * address corresponding to a suppied key via metamorphic initialization code.
   * @return The home address and the hash of the deployed runtime code.
   * @dev This deployment method uses the "metamorphic delegator" pattern, where
   * it will retrieve the address of the contract that contains the target
   * initialization code, then delegatecall into it, which executes the
   * initialization code stored there and returns the runtime code (or reverts).
   * Then, the runtime code returned by the delegatecall is returned, and since
   * we are still in the initialization context, it will be set as the runtime
   * code of the metamorphic contract. The 32-byte metamorphic initialization
   * code is as follows:
   *
   * 0x5859385958601c335a585952fa1582838382515af43d3d93833e601e57fd5bf3
   *
   * 00  58  PC               [0]
   * 01  59  MSIZE            [0, 0]
   * 02  38  CODESIZE         [0, 0, codesize -> 32]
   * returndatac03  59  MSIZE            [0, 0, 32, 0]
   * 04  58  PC               [0, 0, 32, 0, 4]
   * 05  60  PUSH1 0x1c       [0, 0, 32, 0, 4, 28]
   * 07  33  CALLER           [0, 0, 32, 0, 4, 28, caller]
   * 08  5a  GAS              [0, 0, 32, 0, 4, 28, caller, gas]
   * 09  58  PC               [0, 0, 32, 0, 4, 28, caller, gas, 9 -> selector]
   * 10  59  MSIZE            [0, 0, 32, 0, 4, 28, caller, gas, selector, 0]
   * 11  52  MSTORE           [0, 0, 32, 0, 4, 28, caller, gas] <selector>
   * 12  fa  STATICCALL       [0, 0, 1 => success] <init_in_runtime_address>
   * 13  15  ISZERO           [0, 0, 0]
   * 14  82  DUP3             [0, 0, 0, 0]
   * 15  83  DUP4             [0, 0, 0, 0, 0]
   * 16  83  DUP4             [0, 0, 0, 0, 0, 0]
   * 17  82  DUP3             [0, 0, 0, 0, 0, 0, 0]
   * 18  51  MLOAD            [0, 0, 0, 0, 0, 0, init_in_runtime_address]
   * 19  5a  GAS              [0, 0, 0, 0, 0, 0, init_in_runtime_address, gas]
   * 20  f4  DELEGATECALL     [0, 0, 1 => success] {runtime_code}
   * 21  3d  RETURNDATASIZE   [0, 0, 1 => success, size]
   * 22  3d  RETURNDATASIZE   [0, 0, 1 => success, size, size]
   * 23  93  SWAP4            [size, 0, 1 => success, size, 0]
   * 24  83  DUP4             [size, 0, 1 => success, size, 0, 0]
   * 25  3e  RETURNDATACOPY   [size, 0, 1 => success] <runtime_code>
   * 26  60  PUSH1 0x1e       [size, 0, 1 => success, 30]
   * 28  57  JUMPI            [size, 0]
   * 29  fd  REVERT           [] *runtime_code*
   * 30  5b  JUMPDEST         [size, 0]
   * 31  f3  RETURN           []
   */
  function _deployToHomeAddress(bytes32 key)
    internal
    returns (address homeAddress, bytes32 runtimeCodeHash)
  {
    assembly {
      // Write the 32-byte metamorphic initialization code to scratch space.
      mstore(
        0,
        0x5859385958601c335a585952fa1582838382515af43d3d93833e601e57fd5bf3
      )

      // Call `CREATE2` using above init code with the supplied key as the salt.
      homeAddress := create2(callvalue, 0, 32, key)

      // Pass along revert message if the contract did not deploy successfully.
      if iszero(homeAddress) {
        returndatacopy(0, 0, returndatasize)
        revert(0, returndatasize)
      }

      // Get the runtime hash of the deployed contract.
      runtimeCodeHash := extcodehash(homeAddress)
    }

    // Clear the address of the runtime storage contract from storage.
    delete _initializationRuntimeStorageContract;

    // Emit an event with home address, key, and runtime hash of new contract.
    emit NewResident(homeAddress, key, runtimeCodeHash);
  }

  /**
   * @notice Internal function for deriving a key given a particular salt and
   * caller and for performing verifications of, and modifications to, the
   * information set on that key.
   * @param salt bytes32 The value used to derive the key.
   * @return The derived key.
   */
  function _deriveKeyAndPrepareToDeploy(bytes32 salt)
    internal
    returns (bytes32 key)
  {
    // Derive the key using the supplied salt and the calling address.
    key = _deriveKey(salt, msg.sender);

    // Ensure that a contract is not currently deployed to the home address.
    require(_isNotDeployed(key), _ACCOUNT_EXISTS);

    // Set appropriate controller and increment contract deploy count at once.
    HomeAddress storage home = _home[key];
    if (!home.exists) {
      home.exists = true;
      home.controller = msg.sender;
      home.deploys += 1;

      // Emit an event signifying that this contract is now the controller.
      emit NewController(key, msg.sender);

    } else {
      home.deploys += 1;
    }

    // Ensure that the caller is the designated controller before proceeding.
    require(home.controller == msg.sender, _ONLY_CONTROLLER);
  }

  /**
   * @notice Internal function for verifying that an owner that cannot accept
   * ERC721 tokens has not been supplied.
   * @param owner address The specified owner.
   * @param key bytes32 The unique value used to derive the home address.
   */
  function _validateOwner(address owner, bytes32 key) internal {
    // Ensure that the specified owner is a valid ERC721 receiver.
    require(
      _checkOnERC721Received(address(0), owner, uint256(key), bytes("")),
      "Owner must be an EOA or a contract that implements `onERC721Received`."
    );
  }

  /**
   * @notice Internal "view" function for determining if a contract currently
   * exists at a given home address corresponding to a particular key.
   * @param key bytes32 The unique value used to derive the home address.
   * @return A boolean signifying whether the home address has a contract
   * deployed or not.
   */
  function _isNotDeployed(bytes32 key)
    internal
    /* view */
    returns (bool notDeployed)
  {
    // Derive the home address using the supplied key.
    address homeAddress = _getHomeAddress(key);

    // Check whether account at home address is non-existent using EXTCODEHASH.
    bytes32 hash;
    assembly { hash := extcodehash(homeAddress) }

    // Account does not exist, and contract is not deployed, if hash equals 0.
    if (hash == bytes32(0)) {
      return true;
    }

    // Contract is deployed (notDeployed = false) if codesize is greater than 0.
    uint256 size;
    assembly { size := extcodesize(homeAddress) }
    if (size > 0) {
      return false;
    }

    // Declare variable to move current runtime storage from storage to memory.
    address currentStorage;

    // Set runtime storage contract to null address temporarily if necessary.
    if (_initializationRuntimeStorageContract != address(0)) {
      // Place the current runtime storage contract address in memory.
      currentStorage = _initializationRuntimeStorageContract;

      // Remove the existing runtime storage contract address from storage.
      delete _initializationRuntimeStorageContract;
    }

    // Set gas to use when performing dry-run deployment (future-proof a bit).
    uint256 checkGas = 27000 + (block.gaslimit / 1000);

    // As a last resort, deploy a contract to the address and revert on success.
    (bool contractExists, bytes memory code) = address(this).call.gas(checkGas)(
      abi.encodeWithSelector(this.staticCreate2Check.selector, key)
    );

    // Place runtime storage contract back in storage if necessary.
    if (currentStorage != address(0)) {
      _initializationRuntimeStorageContract = currentStorage;
    }

    // Check revert string to ensure failure is due to successful deployment.
    bytes32 revertMessage;
    assembly { revertMessage := mload(add(code, 32)) }

    // Contract is not deployed if `staticCreate2Check` reverted with message.
    notDeployed = !contractExists && revertMessage == _HOME_INIT_CODE;
  }

  /**
   * @notice Internal view function for verifying that a restricted controller
   * has not been supplied.
   * @param controller address The specified controller.
   * @param key bytes32 The unique value used to derive the home address.
   */
  function _validateController(address controller, bytes32 key) internal view {
    // Prevent the controller from being set to prohibited account values.
    require(
      controller != address(0),
      "The null address may not be set as the controller using this function."
    );
    require(
      controller != address(this),
      "This contract may not be set as the controller using this function."
    );
    require(
      controller != _getHomeAddress(key),
      "Home addresses cannot be set as the controller of themselves."
    );
  }

  /**
   * @notice Internal view function for verifying that a supplied runtime
   * storage contract is not empty.
   * @param target address The runtime storage contract.
   */
  function _validateRuntimeStorageIsNotEmpty(address target) internal view {
    // Ensure that the runtime storage contract is not empty.
    require(
      target.isContract(),
      "No runtime code found at the supplied runtime storage address."
    );
  }

  /**
   * @notice Internal view function for retrieving the controller of a home
   * address corresponding to a particular key.
   * @param key bytes32 The unique value used to derive the home address.
   * @return The controller of the home address corresponding to the supplied
   * key.
   */
  function _getController(bytes32 key)
    internal
    view
    returns (address controller)
  {
    // Get controller from mapping, defaulting to first 20 bytes of the key.
    HomeAddress memory home = _home[key];
    if (!home.exists) {
      controller = address(bytes20(key));
    } else {
      controller = home.controller;
    }
  }

  /**
   * @notice Internal view function for getting the runtime code at the tokenURI
   * data storage address.
   * @return The runtime code at the tokenURI storage address.
   */
  function _getTokenURIStorageRuntime()
    internal
    view
    returns (bytes memory runtime)
  {
    // Bring the tokenURI storage address into memory for use in assembly block.
    address target = _URI_END_SEGMENT_STORAGE;

    assembly {
      // Retrieve the size of the external code.
      let size := extcodesize(target)

      // Allocate output byte array.
      runtime := mload(0x40)

      // Set new "memory end" including padding.
      mstore(0x40, add(runtime, and(add(size, 0x3f), not(0x1f))))

      // Store length in memory.
      mstore(runtime, size)

      // Get the code using extcodecopy.
      extcodecopy(target, add(runtime, 0x20), 0, size)
    }
  }

  /**
   * @notice Internal pure function for calculating a home address given a
   * particular key.
   * @param key bytes32 The unique value used to derive the home address.
   * @return The home address corresponding to the supplied key.
   */
  function _getHomeAddress(bytes32 key)
    internal
    pure
    returns (address homeAddress)
  {
    // Determine the home address by replicating CREATE2 logic.
    homeAddress = address(
      uint160(                       // Downcast to match the address type.
        uint256(                     // Cast to uint to truncate upper digits.
          keccak256(                 // Compute CREATE2 hash using 4 inputs.
            abi.encodePacked(        // Pack all inputs to the hash together.
              _FF_AND_THIS_CONTRACT, // This contract will be the caller.
              key,                   // Pass in the supplied key as the salt.
              _HOME_INIT_CODE_HASH   // The metamorphic init code hash.
            )
          )
        )
      )
    );
  }

  /**
   * @notice Internal pure function for deriving a key given a particular salt
   * and caller.
   * @param salt bytes32 The value used to derive the key.
   * @param submitter address The submitter of the salt used to derive the key.
   * @return The derived key.
   */
  function _deriveKey(bytes32 salt, address submitter)
    internal
    pure
    returns (bytes32 key)
  {
    // Set the key as the keccak256 hash of the salt and submitter.
    key = keccak256(abi.encodePacked(salt, submitter));
  }

  /**
   * @notice Internal pure function for converting the bytes representation of
   * an address to an ASCII string. This function is derived from the function
   * at https://ethereum.stackexchange.com/a/56499/48410
   * @param data bytes20 The account address to be converted.
   * @return The account string in ASCII format. Note that leading "0x" is not
   * included.
   */
  function _toAsciiString(bytes20 data)
    internal
    pure
    returns (string memory asciiString)
  {
    // Create an in-memory fixed-size bytes array.
    bytes memory asciiBytes = new bytes(40);

    // Declare variable types.
    uint8 oneByte;
    uint8 leftNibble;
    uint8 rightNibble;

    // Iterate over bytes, processing left and right nibble in each iteration.
    for (uint256 i = 0; i < data.length; i++) {
      // locate the byte and extract each nibble.
      oneByte = uint8(uint160(data) / (2 ** (8 * (19 - i))));
      leftNibble = oneByte / 16;
      rightNibble = oneByte - 16 * leftNibble;

      // To convert to ascii characters, add 48 to 0-9 and 87 to a-f.
      asciiBytes[2 * i] = byte(leftNibble + (leftNibble < 10 ? 48 : 87));
      asciiBytes[2 * i + 1] = byte(rightNibble + (rightNibble < 10 ? 48 : 87));
    }

    asciiString = string(asciiBytes);
  }

  /**
   * @notice Internal pure function for getting a fixed-size array of whether or
   * not each character in an account will be capitalized in the checksum.
   * @param account address The account to get the checksum capitalization
   * information for.
   * @return A fixed-size array of booleans that signify if each character or
   * "nibble" of the hex encoding of the address will be capitalized by the
   * checksum.
   */
  function _getChecksumCapitalizedCharacters(address account)
    internal
    pure
    returns (bool[40] memory characterIsCapitalized)
  {
    // Convert the address to bytes.
    bytes20 addressBytes = bytes20(account);

    // Hash the address (used to calculate checksum).
    bytes32 hash = keccak256(abi.encodePacked(_toAsciiString(addressBytes)));

    // Declare variable types.
    uint8 leftNibbleAddress;
    uint8 rightNibbleAddress;
    uint8 leftNibbleHash;
    uint8 rightNibbleHash;

    // Iterate over bytes, processing left and right nibble in each iteration.
    for (uint256 i; i < addressBytes.length; i++) {
      // locate the byte and extract each nibble for the address and the hash.
      rightNibbleAddress = uint8(addressBytes[i]) % 16;
      leftNibbleAddress = (uint8(addressBytes[i]) - rightNibbleAddress) / 16;
      rightNibbleHash = uint8(hash[i]) % 16;
      leftNibbleHash = (uint8(hash[i]) - rightNibbleHash) / 16;

      // Set the capitalization flags based on the characters and the checksums.
      characterIsCapitalized[2 * i] = (
        leftNibbleAddress > 9 &&
        leftNibbleHash > 7
      );
      characterIsCapitalized[2 * i + 1] = (
        rightNibbleAddress > 9 &&
        rightNibbleHash > 7
      );
    }
  }

  /**
   * @notice Internal pure function for converting the bytes representation of
   * an address to a checksummed ASCII string.
   * @param account address The account address to be converted.
   * @return The checksummed account string in ASCII format. Note that leading
   * "0x" is not included.
   */
  function _toChecksummedAsciiString(address account)
    internal
    pure
    returns (string memory checksummedAsciiString)
  {
    // Get capitalized characters in the checksum.
    bool[40] memory caps = _getChecksumCapitalizedCharacters(account);

    // Create an in-memory fixed-size bytes array.
    bytes memory asciiBytes = new bytes(40);

    // Declare variable types.
    uint8 oneByte;
    uint8 leftNibble;
    uint8 rightNibble;
    uint8 leftNibbleOffset;
    uint8 rightNibbleOffset;

    // Convert account to bytes20.
    bytes20 data = bytes20(account);

    // Iterate over bytes, processing left and right nibble in each iteration.
    for (uint256 i = 0; i < data.length; i++) {
      // locate the byte and extract each nibble.
      oneByte = uint8(uint160(data) / (2 ** (8 * (19 - i))));
      leftNibble = oneByte / 16;
      rightNibble = oneByte - 16 * leftNibble;

      // To convert to ascii characters, add 48 to 0-9, 55 to A-F, & 87 to a-f.
      if (leftNibble < 10) {
        leftNibbleOffset = 48;
      } else if (caps[i * 2]) {
        leftNibbleOffset = 55;
      } else {
        leftNibbleOffset = 87;
      }

      if (rightNibble < 10) {
        rightNibbleOffset = 48;
      } else {
        rightNibbleOffset = caps[(i * 2) + 1] ? 55 : 87; // instrumentation fix
      }

      asciiBytes[2 * i] = byte(leftNibble + leftNibbleOffset);
      asciiBytes[2 * i + 1] = byte(rightNibble + rightNibbleOffset);
    }

    checksummedAsciiString = string(asciiBytes);
  }

  /**
   * @notice Modifier to ensure that a contract is not currently deployed to the
   * home address corresponding to a given key on the decorated function.
   * @param key bytes32 The unique value used to derive the home address.
   */
  modifier onlyEmpty(bytes32 key) {
    require(_isNotDeployed(key), _ACCOUNT_EXISTS);
    _;
  }

  /**
   * @notice Modifier to ensure that the caller of the decorated function is the
   * controller of the home address corresponding to a given key.
   * @param key bytes32 The unique value used to derive the home address.
   */
  modifier onlyController(bytes32 key) {
    require(_getController(key) == msg.sender, _ONLY_CONTROLLER);
    _;
  }

  /**
   * @notice Modifier to track initial controllers and to count deploys, and to
   * validate that only the designated controller has access to the decorated
   * function.
   * @param key bytes32 The unique value used to derive the home address.
   */
  modifier onlyControllerDeployer(bytes32 key) {
    HomeAddress storage home = _home[key];

    // Set appropriate controller and increment contract deploy count at once.
    if (!home.exists) {
      home.exists = true;
      home.controller = address(bytes20(key));
      home.deploys += 1;
    } else {
      home.deploys += 1;
    }

    require(home.controller == msg.sender, _ONLY_CONTROLLER);
    _;
  }

  /**
   * @notice Modifier to ensure that only the owner of the supplied ERC721
   * token, or an approved spender, can access the decorated function.
   * @param tokenId uint256 The ID of the ERC721 token.
   */
  modifier onlyTokenOwnerOrApprovedSpender(uint256 tokenId) {
    require(
      _isApprovedOrOwner(msg.sender, tokenId),
      "Only the token owner or an approved spender may call this function."
    );
    _;
  }
}

/**
 * @title HomeWork Deployer (alpha version)
 * @author 0age
 * @notice This contract is a stripped-down version of HomeWork that is used to
 * deploy HomeWork itself.
 *   HomeWork Deploy code at runtime: 0x7Cf7708ab4A064B14B02F34aecBd2511f3605395
 *   HomeWork Runtime code at:        0x0000000000001b84b1cb32787b0d64758d019317
 */
contract HomeWorkDeployer {
  // Fires when HomeWork has been deployed.
  event HomeWorkDeployment(address homeAddress, bytes32 key);

  // Fires HomeWork's initialization-in-runtime storage contract is deployed.
  event StorageContractDeployment(address runtimeStorageContract);

  // Allocate storage to track the current initialization-in-runtime contract.
  address private _initializationRuntimeStorageContract;

  // Once HomeWork has been deployed, disable this contract.
  bool private _disabled;

  // Write arbitrary code to a contract's runtime using the following prelude.
  bytes11 private constant _ARBITRARY_RUNTIME_PRELUDE = bytes11(
    0x600b5981380380925939f3
  );

  /**
   * @notice Perform phase one of the deployment.
   * @param code bytes The contract creation code for HomeWork.
   */
  function phaseOne(bytes calldata code) external onlyUntilDisabled {
    // Deploy payload to the runtime storage contract and set the address.
    _initializationRuntimeStorageContract = _deployRuntimeStorageContract(
      bytes32(0),
      code
    );
  }

  /**
   * @notice Perform phase two of the deployment (tokenURI data).
   * @param key bytes32 The salt to provide to create2.
   */
  function phaseTwo(bytes32 key) external onlyUntilDisabled {
    // Deploy runtime storage contract with the string used to construct end of
    // token URI for issued ERC721s (data URI with a base64-encoded jpeg image).
    bytes memory code = abi.encodePacked(
      hex"222c226465736372697074696f6e223a22546869732532304e465425323063616e25",
      hex"3230626525323072656465656d65642532306f6e253230486f6d65576f726b253230",
      hex"746f2532306772616e7425323061253230636f6e74726f6c6c657225323074686525",
      hex"32306578636c75736976652532307269676874253230746f2532306465706c6f7925",
      hex"3230636f6e7472616374732532307769746825323061726269747261727925323062",
      hex"797465636f6465253230746f25323074686525323064657369676e61746564253230",
      hex"686f6d65253230616464726573732e222c22696d616765223a22646174613a696d61",
      hex"67652f7376672b786d6c3b636861727365743d7574662d383b6261736536342c5048",
      hex"4e325a79423462577875637a30696148523063446f764c336433647935334d793576",
      hex"636d63764d6a41774d43397a646d636949485a705a58644362336739496a41674d43",
      hex"41784e4451674e7a4969506a787a64486c735a543438495674445245465551567375",
      hex"516e747a64484a766132557462476c755a57707661573436636d3931626d52394c6b",
      hex"4e37633352796232746c4c5731706447567962476c74615851364d5442394c6b5237",
      hex"633352796232746c4c5864705a48526f4f6a4a394c6b56375a6d6c7362446f6a4f57",
      hex"4935596a6c686653354765334e30636d39725a5331736157356c593246774f6e4a76",
      hex"6457356b66563164506a7776633352356247552b5047636764484a68626e4e6d6233",
      hex"4a7450534a74595852796158676f4d5334774d694177494441674d5334774d694134",
      hex"4c6a45674d436b69506a78775958526f49475a706247773949694e6d5a6d59694947",
      hex"5139496b30784f53417a4d6d677a4e4859794e4567784f586f694c7a34385a79427a",
      hex"64484a766132553949694d774d44416949474e7359584e7a50534a4349454d675243",
      hex"492b50484268644767675a6d6c7362443069493245314e7a6b7a4f5349675a443069",
      hex"545449314944517761446c324d545a6f4c546c364969382b50484268644767675a6d",
      hex"6c7362443069497a6b795a444e6d4e5349675a443069545451774944517761446832",
      hex"4e3267744f486f694c7a3438634746306143426d615778735053496a5a5745315954",
      hex"51334969426b50534a4e4e544d674d7a4a494d546c324c5446734d5459744d545967",
      hex"4d5467674d545a364969382b50484268644767675a6d6c7362443069626d39755a53",
      hex"49675a4430695454453549444d7961444d30646a49305344453565694976506a7877",
      hex"5958526f49475a706247773949694e6c595456684e44636949475139496b30794f53",
      hex"41794d5777744e53413164693035614456364969382b5043396e506a77765a7a3438",
      hex"5a794230636d467563325a76636d3039496d316864484a70654367754f4451674d43",
      hex"4177494334344e4341324e5341314b53492b50484268644767675a44306954546b75",
      hex"4e5341794d693435624451754f4341324c6a52684d7934784d69417a4c6a45794944",
      hex"41674d4341784c544d674d693479624330304c6a67744e6934305979347a4c544575",
      hex"4e4341784c6a59744d69343049444d744d693479656949675a6d6c73624430694932",
      hex"517759325a6a5a534976506a78775958526f49475a706247773949694d774d544178",
      hex"4d44456949475139496b30304d53343349444d344c6a56734e5334784c5459754e53",
      hex"4976506a78775958526f49475139496b30304d693435494449334c6a684d4d546775",
      hex"4e4341314f4334784944493049445979624449784c6a67744d6a63754d7941794c6a",
      hex"4d744d693434656949675932786863334d39496b55694c7a3438634746306143426d",
      hex"615778735053496a4d4445774d5441784969426b50534a4e4e444d754e4341794f53",
      hex"347a624330304c6a63674e5334344969382b50484268644767675a44306954545132",
      hex"4c6a67674d7a4a6a4d793479494449754e6941344c6a63674d533479494445794c6a",
      hex"45744d793479637a4d754e6930354c6a6b754d7930784d693431624330314c6a4567",
      hex"4e6934314c5449754f4330754d5330754e7930794c6a63674e5334784c5459754e57",
      hex"4d744d7934794c5449754e6930344c6a63744d5334794c5445794c6a45674d793479",
      hex"6379307a4c6a59674f5334354c53347a494445794c6a556949474e7359584e7a5053",
      hex"4a464969382b50484268644767675a6d6c7362443069493245314e7a6b7a4f534967",
      hex"5a443069545449334c6a4d674d6a5a734d5445754f4341784e53343349444d754e43",
      hex"41794c6a51674f533478494445304c6a51744d793479494449754d79307849433433",
      hex"4c5445774c6a49744d544d754e6930784c6a4d744d7934354c5445784c6a67744d54",
      hex"55754e336f694c7a3438634746306143426b50534a4e4d5449674d546b754f577731",
      hex"4c6a6b674e793435494445774c6a49744e7934324c544d754e4330304c6a567a4e69",
      hex"34344c5455754d5341784d4334334c5451754e574d77494441744e6934324c544d74",
      hex"4d544d754d7941784c6a46544d5449674d546b754f5341784d6941784f5334356569",
      hex"49675932786863334d39496b55694c7a34385a79426d6157787350534a756232356c",
      hex"4969427a64484a766132553949694d774d44416949474e7359584e7a50534a434945",
      hex"4d675243492b50484268644767675a44306954545579494455344c6a6c4d4e444175",
      hex"4f5341304d7934796243307a4c6a45744d69347a4c5445774c6a59744d5451754e79",
      hex"30794c6a6b674d693479494445774c6a59674d5451754e7941784c6a45674d793432",
      hex"494445784c6a55674d5455754e58704e4d5449754e5341784f533434624455754f43",
      hex"4134494445774c6a4d744e7934304c544d754d7930304c6a5a7a4e6934354c545567",
      hex"4d5441754f4330304c6a4e6a4d4341774c5459754e69307a4c6a45744d544d754d79",
      hex"3435637930784d43347a494463754e4330784d43347a494463754e4870744c544975",
      hex"4e6941794c6a6c734e433433494459754e574d744c6a55674d53347a4c5445754e79",
      hex"41794c6a45744d7941794c6a4a734c5451754e7930324c6a566a4c6a4d744d533430",
      hex"494445754e6930794c6a51674d7930794c6a4a364969382b50484268644767675a44",
      hex"3069545451784c6a4d674d7a67754e5777314c6a45744e6934316253307a4c6a5574",
      hex"4d693433624330304c6a59674e533434625467754d53307a4c6a466a4d7934794944",
      hex"49754e6941344c6a63674d533479494445794c6a45744d793479637a4d754e693035",
      hex"4c6a6b754d7930784d693431624330314c6a45674e6934314c5449754f4330754d53",
      hex"30754f4330794c6a63674e5334784c5459754e574d744d7934794c5449754e693034",
      hex"4c6a63744d5334794c5445794c6a45674d7934794c544d754e4341304c6a4d744d79",
      hex"343249446b754f5330754d7941784d6934314969426a6247467a637a306952694976",
      hex"506a78775958526f49475139496b307a4d433434494451304c6a524d4d546b674e54",
      hex"67754f57773049444d674d5441744d5449754e7949675932786863334d39496b5969",
      hex"4c7a34384c32632b5043396e506a777663335a6e50673d3d227d"
    ); /* ","description":"This%20NFT%20can%20be%20redeemed%20on%20HomeWork%20
          to%20grant%20a%20controller%20the%20exclusive%20right%20to%20deploy%20
          contracts%20with%20arbitrary%20bytecode%20to%20the%20designated%20home
          %20address.","image":"data:image/svg+xml;charset=utf-8;base64,..."} */

    // Deploy payload to the runtime storage contract.
    _deployRuntimeStorageContract(key, code);
  }

  /**
   * @notice Perform phase three of the deployment and disable this contract.
   * @param key bytes32 The salt to provide to create2.
   */
  function phaseThree(bytes32 key) external onlyUntilDisabled {
    // Use metamorphic initialization code to deploy contract to home address.
    _deployToHomeAddress(key);

    // Disable this contract from here on out - use HomeWork itself instead.
    _disabled = true;
  }

  /**
   * @notice View function used by the metamorphic initialization code when
   * deploying a contract to a home address. It returns the address of the
   * runtime storage contract that holds the contract creation code, which the
   * metamorphic creation code then `DELEGATECALL`s into in order to set up the
   * contract and deploy the target runtime code.
   * @return The current runtime storage contract that contains the target
   * contract creation code.
   * @dev This method is not meant to be part of the user-facing contract API,
   * but is rather a mechanism for enabling the deployment of arbitrary code via
   * fixed initialization code. The odd naming is chosen so that function
   * selector will be 0x00000009 - that way, the metamorphic contract can simply
   * use the `PC` opcode in order to push the selector to the stack.
   */
  function getInitializationCodeFromContractRuntime_6CLUNS()
    external
    view
    returns (address initializationRuntimeStorageContract)
  {
    // Return address of contract with initialization code set as runtime code.
    initializationRuntimeStorageContract = _initializationRuntimeStorageContract;
  }

  /**
   * @notice Internal function for deploying a runtime storage contract given a
   * particular payload.
   * @dev To take the provided code payload and deploy a contract with that
   * payload as its runtime code, use the following prelude:
   *
   * 0x600b5981380380925939f3...
   *
   * 00  60  push1 0b      [11 -> offset]
   * 02  59  msize         [offset, 0]
   * 03  81  dup2          [offset, 0, offset]
   * 04  38  codesize      [offset, 0, offset, codesize]
   * 05  03  sub           [offset, 0, codesize - offset]
   * 06  80  dup1          [offset, 0, codesize - offset, codesize - offset]
   * 07  92  swap3         [codesize - offset, 0, codesize - offset, offset]
   * 08  59  msize         [codesize - offset, 0, codesize - offset, offset, 0]
   * 09  39  codecopy      [codesize - offset, 0] <init_code_in_runtime>
   * 10  f3  return        [] *init_code_in_runtime*
   * ... init_code
   */
  function _deployRuntimeStorageContract(bytes32 key, bytes memory payload)
    internal
    returns (address runtimeStorageContract)
  {
    // Construct the contract creation code using the prelude and the payload.
    bytes memory runtimeStorageContractCreationCode = abi.encodePacked(
      _ARBITRARY_RUNTIME_PRELUDE,
      payload
    );

    assembly {
      // Get the location and length of the newly-constructed creation code.
      let encoded_data := add(0x20, runtimeStorageContractCreationCode)
      let encoded_size := mload(runtimeStorageContractCreationCode)

      // Deploy the runtime storage contract via `CREATE2`.
      runtimeStorageContract := create2(0, encoded_data, encoded_size, key)

      // Pass along revert message if the contract did not deploy successfully.
      if iszero(runtimeStorageContract) {
        returndatacopy(0, 0, returndatasize)
        revert(0, returndatasize)
      }
    }

    // Emit an event with address of newly-deployed runtime storage contract.
    emit StorageContractDeployment(runtimeStorageContract);
  }

  /**
   * @notice Internal function for deploying arbitrary contract code to the home
   * address corresponding to a suppied key via metamorphic initialization code.
   * @dev This deployment method uses the "metamorphic delegator" pattern, where
   * it will retrieve the address of the contract that contains the target
   * initialization code, then delegatecall into it, which executes the
   * initialization code stored there and returns the runtime code (or reverts).
   * Then, the runtime code returned by the delegatecall is returned, and since
   * we are still in the initialization context, it will be set as the runtime
   * code of the metamorphic contract. The 32-byte metamorphic initialization
   * code is as follows:
   *
   * 0x5859385958601c335a585952fa1582838382515af43d3d93833e601e57fd5bf3
   *
   * 00  58  PC               [0]
   * 01  59  MSIZE            [0, 0]
   * 02  38  CODESIZE         [0, 0, codesize -> 32]
   * returndatac03  59  MSIZE            [0, 0, 32, 0]
   * 04  58  PC               [0, 0, 32, 0, 4]
   * 05  60  PUSH1 0x1c       [0, 0, 32, 0, 4, 28]
   * 07  33  CALLER           [0, 0, 32, 0, 4, 28, caller]
   * 08  5a  GAS              [0, 0, 32, 0, 4, 28, caller, gas]
   * 09  58  PC               [0, 0, 32, 0, 4, 28, caller, gas, 9 -> selector]
   * 10  59  MSIZE            [0, 0, 32, 0, 4, 28, caller, gas, selector, 0]
   * 11  52  MSTORE           [0, 0, 32, 0, 4, 28, caller, gas] <selector>
   * 12  fa  STATICCALL       [0, 0, 1 => success] <init_in_runtime_address>
   * 13  15  ISZERO           [0, 0, 0]
   * 14  82  DUP3             [0, 0, 0, 0]
   * 15  83  DUP4             [0, 0, 0, 0, 0]
   * 16  83  DUP4             [0, 0, 0, 0, 0, 0]
   * 17  82  DUP3             [0, 0, 0, 0, 0, 0, 0]
   * 18  51  MLOAD            [0, 0, 0, 0, 0, 0, init_in_runtime_address]
   * 19  5a  GAS              [0, 0, 0, 0, 0, 0, init_in_runtime_address, gas]
   * 20  f4  DELEGATECALL     [0, 0, 1 => success] {runtime_code}
   * 21  3d  RETURNDATASIZE   [0, 0, 1 => success, size]
   * 22  3d  RETURNDATASIZE   [0, 0, 1 => success, size, size]
   * 23  93  SWAP4            [size, 0, 1 => success, size, 0]
   * 24  83  DUP4             [size, 0, 1 => success, size, 0, 0]
   * 25  3e  RETURNDATACOPY   [size, 0, 1 => success] <runtime_code>
   * 26  60  PUSH1 0x1e       [size, 0, 1 => success, 30]
   * 28  57  JUMPI            [size, 0]
   * 29  fd  REVERT           [] *runtime_code*
   * 30  5b  JUMPDEST         [size, 0]
   * 31  f3  RETURN           []
   */
  function _deployToHomeAddress(bytes32 key) internal {
    // Declare a variable for the home address.
    address homeAddress;

    assembly {
      // Write the 32-byte metamorphic initialization code to scratch space.
      mstore(
        0,
        0x5859385958601c335a585952fa1582838382515af43d3d93833e601e57fd5bf3
      )

      // Call `CREATE2` using above init code with the supplied key as the salt.
      homeAddress := create2(callvalue, 0, 32, key)

      // Pass along revert message if the contract did not deploy successfully.
      if iszero(homeAddress) {
        returndatacopy(0, 0, returndatasize)
        revert(0, returndatasize)
      }
    }

    // Clear the address of the runtime storage contract from storage.
    delete _initializationRuntimeStorageContract;

    // Emit an event with home address and key for the newly-deployed contract.
    emit HomeWorkDeployment(homeAddress, key);
  }

  /**
   * @notice Modifier to disable the contract once deployment is complete.
   */
  modifier onlyUntilDisabled() {
    require(!_disabled, "Contract is disabled.");
    _;
  }
}