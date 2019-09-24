import { openQuestionModal } from '../../lib/modals'
import { makeContractCall, isSupportedNetwork } from './utils'

export function openRemovePoolModal (store) {
  if (!isSupportedNetwork(store)) return
  openQuestionModal('Remove my Pool', 'Do you really want to remove your pool?', () => removePool(store))
}

async function removePool (store) {
  const contract = store.getState().stakingContract
  makeContractCall(contract.methods.removeMyPool(), store)
}
