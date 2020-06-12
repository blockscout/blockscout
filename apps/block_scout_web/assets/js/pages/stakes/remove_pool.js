import { openErrorModal, openQuestionModal } from '../../lib/modals'
import { makeContractCall, isSupportedNetwork } from './utils'

export function openRemovePoolModal (store) {
  if (!isSupportedNetwork(store)) return
  openQuestionModal('Remove my Pool', 'Do you really want to remove your pool?', () => removePool(store))
}

async function removePool (store) {
  const state = store.getState()
  const call = state.stakingContract.methods.removeMyPool()
  let gasLimit

  try {
    gasLimit = await call.estimateGas({
      from: state.account,
      gasPrice: 1000000000
    })
  } catch (err) {
    openErrorModal('Error', 'Currently you cannot remove your pool. Please try again during the next epoch.')
    return
  }

  makeContractCall(call, store, gasLimit)
}
