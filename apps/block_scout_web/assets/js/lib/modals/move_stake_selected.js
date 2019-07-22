import $ from 'jquery'
import humps from 'humps'
import {store} from '../pages/stakes.js'
import * as modals from './utils.js'

window.openMoveStakeSelectedModal = async function (fromAddress, toAddress, amount = null, pools = []) {
  let modal = '#moveStakeModalSelected'
  let response = await $.getJSON('/staking_pool', { 'pool_hash': fromAddress })
  let fromPool = humps.camelizeKeys(response.pool)
  let relation = humps.camelizeKeys(response.relation)
  let tokenSymbol = store.getState().tokenSymbol

  modals.setProgressInfo(modal, fromPool, '.js-pool-from-progress')

  $(`${modal} [user-staked]`).text(`${relation.stakeAmount} ${tokenSymbol}`)
  $(`${modal} [max-allowed]`).text(`${relation.maxWithdrawAllowed} ${tokenSymbol}`)
  $(`${modal} [move-amount]`).val(amount)

  response = await $.getJSON('/staking_pool', { 'pool_hash': toAddress })
  let toPool = humps.camelizeKeys(response.pool)

  modals.setProgressInfo(modal, toPool, '.js-pool-to-progress')

  $.each(pools, (_key, pool) => {
    var $option = $('<option/>', {
      value: pool.stakingAddressHash,
      text: pool.stakingAddressHash.slice(0, 13),
      selected: pool.stakingAddressHash === toAddress
    })

    $(`${modal} [pool-select]`).append($option)
  })

  $(`${modal} [pool-select]`).unbind('change')

  $(`${modal} [pool-select]`).on('change', e => {
    let selectedAddress = e.currentTarget.value
    let amount = $(`${modal} [move-amount]`).val()
    window.openMoveStakeSelectedModal(fromAddress, selectedAddress, amount)
  })

  $(`${modal} form`).unbind('submit')
  $(`${modal} form`).on('submit', e => modals.moveStake(e, modal, fromAddress, toAddress))

  $(modal).modal('show')
}
