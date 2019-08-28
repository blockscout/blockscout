import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, openWarningModal, lockModal } from '../../lib/modals'
import { makeContractCall } from './utils'

export function openBecomeCandidateModal (store) {
  if (!store.getState().account) {
    openWarningModal('Unauthorized', 'Please login with MetaMask')
    return
  }

  store.getState().channel
    .push('render_become_candidate')
    .receive('ok', msg => {
      const $modal = $(msg.html)
      $modal.find('form').submit(() => {
        becomeCandidate($modal, store, msg)
        return false
      })
      openModal($modal)
    })
}

async function becomeCandidate ($modal, store, msg) {
  lockModal($modal)

  const web3 = store.getState().web3
  const stakingContract = store.getState().stakingContract
  const blockRewardContract = store.getState().blockRewardContract
  const decimals = store.getState().tokenDecimals

  const minStake = new BigNumber(msg.min_candidate_stake)
  const stake = new BigNumber($modal.find('[candidate-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()
  if (!stake.isPositive() || stake.isLessThan(minStake)) {
    openErrorModal('Error', `You cannot stake less than ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`)
    return false
  }

  const miningAddress = $modal.find('[mining-address]').val().toLowerCase()
  if (miningAddress === store.getState().account || !web3.utils.isAddress(miningAddress)) {
    openErrorModal('Error', 'Invalid Mining Address')
    return false
  }

  try {
    if (!await stakingContract.methods.areStakeAndWithdrawAllowed().call()) {
      if (await blockRewardContract.methods.isSnapshotting().call()) {
        openErrorModal('Error', 'Stakes are not allowed at the moment. Please try again in a few blocks')
      } else {
        openErrorModal('Error', 'Current staking epoch is finishing now, you will be able to place a stake during the next staking epoch. Please try again in a few blocks')
      }
      return false
    }

    if (msg.pool_exists) {
      makeContractCall(stakingContract.methods.stake(store.getState().account, stake.toString()), store)
    } else {
      makeContractCall(stakingContract.methods.addPool(stake.toString(), miningAddress), store)
    }
  } catch (err) {
    openErrorModal('Error', err.message)
  }
}
