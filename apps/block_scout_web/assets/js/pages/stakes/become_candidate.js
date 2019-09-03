import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import { openModal, openErrorModal, openWarningModal, lockModal } from '../../lib/modals'
import { setupValidation } from '../../lib/validation'
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

      setupValidation(
        $modal.find('form'),
        {
          'candidate-stake': value => isCandidateStakeValid(value, store, msg),
          'mining-address': value => isMiningAddressValid(value, store)
        },
        $modal.find('form button')
      )

      $modal.find('form').submit(() => {
        becomeCandidate($modal, store, msg)
        return false
      })

      openModal($modal)
    })
}

async function becomeCandidate ($modal, store, msg) {
  lockModal($modal)

  const stakingContract = store.getState().stakingContract
  const blockRewardContract = store.getState().blockRewardContract
  const decimals = store.getState().tokenDecimals
  const stake = new BigNumber($modal.find('[candidate-stake]').val().replace(',', '.').trim()).shiftedBy(decimals).integerValue()
  const miningAddress = $modal.find('[mining-address]').val().trim().toLowerCase()

  try {
    if (!await stakingContract.methods.areStakeAndWithdrawAllowed().call()) {
      if (await blockRewardContract.methods.isSnapshotting().call()) {
        openErrorModal('Error', 'Staking actions are temporarily restricted. Please try again in a few blocks.')
      } else {
        openErrorModal('Error', 'The current staking epoch is ending, and staking actions are temporarily restricted. Please try again when the new epoch starts.')
      }
      return false
    }

    makeContractCall(stakingContract.methods.addPool(stake.toString(), miningAddress), store)
  } catch (err) {
    openErrorModal('Error', err.message)
  }
}

function isCandidateStakeValid (value, store, msg) {
  const decimals = store.getState().tokenDecimals
  const minStake = new BigNumber(msg.min_candidate_stake)
  const balance = new BigNumber(msg.balance)
  const stake = new BigNumber(value.replace(',', '.').trim()).shiftedBy(decimals).integerValue()

  if (!stake.isPositive()) {
    return 'Invalid amount'
  } else if (stake.isLessThan(minStake)) {
    return `Minimum candidate stake is ${minStake.shiftedBy(-decimals)} ${store.getState().tokenSymbol}`
  } else if (stake.isGreaterThan(balance)) {
    return 'Insufficient funds'
  }

  return true
}

function isMiningAddressValid (value, store) {
  const web3 = store.getState().web3
  const miningAddress = value.trim().toLowerCase()

  if (miningAddress === store.getState().account || !web3.utils.isAddress(miningAddress)) {
    return 'Invalid mining address'
  }

  return true
}
