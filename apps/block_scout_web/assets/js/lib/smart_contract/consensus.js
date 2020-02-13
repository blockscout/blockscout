import Web3 from 'web3'

const PROVIDER_URL = process.env.PROVIDER_URL
const CONSENSUS_ABI = [{'constant': true, 'inputs': [], 'name': 'getLastSnapshotTakenAtBlock', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [{'name': '_p', 'type': 'uint256'}], 'name': 'pendingValidatorsAtPosition', 'outputs': [{'name': '', 'type': 'address'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [{'name': '_snapshotId', 'type': 'uint256'}], 'name': 'getSnapshotAddresses', 'outputs': [{'name': '', 'type': 'address[]'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': false, 'inputs': [{'name': '_newAddress', 'type': 'address'}], 'name': 'setProxyStorage', 'outputs': [], 'payable': false, 'stateMutability': 'nonpayable', 'type': 'function'}, {'constant': true, 'inputs': [{'name': '_address', 'type': 'address'}, {'name': '_validator', 'type': 'address'}], 'name': 'delegatedAmount', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'SNAPSHOTS_PER_CYCLE', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'pendingValidatorsLength', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'newValidatorSetLength', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'DECIMALS', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'isInitialized', 'outputs': [{'name': '', 'type': 'bool'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'currentValidatorsLength', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'getMinStake', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'pure', 'type': 'function'}, {'constant': true, 'inputs': [{'name': '_p', 'type': 'uint256'}], 'name': 'currentValidatorsAtPosition', 'outputs': [{'name': '', 'type': 'address'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'newValidatorSet', 'outputs': [{'name': '', 'type': 'address[]'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'CYCLE_DURATION_BLOCKS', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'getSnapshotsPerCycle', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'pure', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'requiredSignatures', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'isFinalized', 'outputs': [{'name': '', 'type': 'bool'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'getCurrentCycleStartBlock', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'currentValidators', 'outputs': [{'name': '', 'type': 'address[]'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'getCycleDurationBlocks', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'pure', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'pendingValidators', 'outputs': [{'name': '', 'type': 'address[]'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'getCurrentCycleEndBlock', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [{'name': '_address', 'type': 'address'}], 'name': 'stakeAmount', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'MIN_STAKE', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'getNextSnapshotId', 'outputs': [{'name': '', 'type': 'uint256'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'getProxyStorage', 'outputs': [{'name': '', 'type': 'address'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'shouldEmitInitiateChange', 'outputs': [{'name': '', 'type': 'bool'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [{'name': '_address', 'type': 'address'}], 'name': 'isValidator', 'outputs': [{'name': '', 'type': 'bool'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': true, 'inputs': [{'name': '_address', 'type': 'address'}], 'name': 'isPendingValidator', 'outputs': [{'name': '', 'type': 'bool'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'payable': true, 'stateMutability': 'payable', 'type': 'fallback'}, {'anonymous': false, 'inputs': [{'indexed': false, 'name': 'newSet', 'type': 'address[]'}], 'name': 'ChangeFinalized', 'type': 'event'}, {'anonymous': false, 'inputs': [], 'name': 'ShouldEmitInitiateChange', 'type': 'event'}, {'anonymous': false, 'inputs': [{'indexed': true, 'name': 'parentHash', 'type': 'bytes32'}, {'indexed': false, 'name': 'newSet', 'type': 'address[]'}], 'name': 'InitiateChange', 'type': 'event'}, {'constant': false, 'inputs': [{'name': '_initialValidator', 'type': 'address'}], 'name': 'initialize', 'outputs': [], 'payable': false, 'stateMutability': 'nonpayable', 'type': 'function'}, {'constant': true, 'inputs': [], 'name': 'getValidators', 'outputs': [{'name': '', 'type': 'address[]'}], 'payable': false, 'stateMutability': 'view', 'type': 'function'}, {'constant': false, 'inputs': [], 'name': 'finalizeChange', 'outputs': [], 'payable': false, 'stateMutability': 'nonpayable', 'type': 'function'}, {'constant': false, 'inputs': [], 'name': 'stake', 'outputs': [], 'payable': true, 'stateMutability': 'payable', 'type': 'function'}, {'constant': false, 'inputs': [{'name': '_validator', 'type': 'address'}], 'name': 'delegate', 'outputs': [], 'payable': true, 'stateMutability': 'payable', 'type': 'function'}, {'constant': false, 'inputs': [{'name': '_amount', 'type': 'uint256'}], 'name': 'withdraw', 'outputs': [], 'payable': false, 'stateMutability': 'nonpayable', 'type': 'function'}, {'constant': false, 'inputs': [{'name': '_validator', 'type': 'address'}, {'name': '_amount', 'type': 'uint256'}], 'name': 'withdraw', 'outputs': [], 'payable': false, 'stateMutability': 'nonpayable', 'type': 'function'}, {'constant': false, 'inputs': [], 'name': 'cycle', 'outputs': [], 'payable': false, 'stateMutability': 'nonpayable', 'type': 'function'}, {'constant': false, 'inputs': [], 'name': 'emitInitiateChange', 'outputs': [], 'payable': false, 'stateMutability': 'nonpayable', 'type': 'function'}]
const CONSENSUS_ADDRESS = process.env.CONSENSUS_ADDRESS

const web3 = new Web3(new Web3.providers.HttpProvider(PROVIDER_URL))
const consensus = new web3.eth.Contract(CONSENSUS_ABI, CONSENSUS_ADDRESS)

async function currentBlockNumber () {
  const blockNumber = await web3.eth.getBlockNumber()
  return blockNumber
}

async function currentCycleStartBlock () {
  const block = await consensus.methods.getCurrentCycleStartBlock.call()
  return block
}

async function decimals () {
  const d = await consensus.methods.DECIMALS.call()
  return d
}

async function currentCycleEndBlock () {
  const block = await consensus.methods.getCurrentCycleEndBlock.call()
  return block
}

export async function getActiveValidators () {
  const validators = await consensus.methods.getValidators.call()
  return validators && validators.length
}

export async function getTotalStaked () {
  const total = await web3.eth.getBalance(CONSENSUS_ADDRESS)
  const dec = await decimals()
  return total / dec
}

export async function getCycleEnd () {
  const cycleEndInBlocks = await currentCycleEndBlock() - await currentBlockNumber()
  const cycleEndInSeconds = cycleEndInBlocks * 5
  return cycleEndInSeconds
}

export async function getCurrentCycleBlocks () {
  const startBlock = await currentCycleStartBlock()
  const endBlock = await currentCycleEndBlock()
  return [startBlock, endBlock]
}
