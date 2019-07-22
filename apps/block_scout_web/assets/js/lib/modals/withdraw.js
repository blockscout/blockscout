import $ from 'jquery'
import humps from 'humps'
import {store} from '../pages/stakes.js'
import * as modals from './utils.js'

window.openWithdrawModal = async function (poolAddress) {
  let modal = '#withdrawModal'

  try {
    let response = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(response.pool)
    modals.setProgressInfo(modal, pool)
    let relation = humps.camelizeKeys(response.relation)

    let tokenSymbol = store.getState().tokenSymbol
    $(`${modal} [user-staked]`).text(`${relation.stakeAmount} ${tokenSymbol}`)

    let $withdraw = $(`${modal} .btn-full-primary.withdraw`)
    let $order = $(`${modal} .btn-full-primary.order_withdraw`)

    $withdraw.attr('disabled', true)
    $order.attr('disabled', true)
    if (relation.maxWithdrawAllowed > 0) {
      $withdraw.attr('disabled', false)
    }
    if (relation.maxOrderedWithdrawAllowed > 0) {
      $order.attr('disabled', false)
    }

    $withdraw.unbind('click')
    $withdraw.on('click', e => modals.withdrawOrOrderStake(e, modal, poolAddress, 'withdraw'))

    $order.unbind('click')
    $order.on('click', e => modals.withdrawOrOrderStake(e, modal, poolAddress, 'order'))

    $(modal).modal()
  } catch (e) {
    $(modal).modal()
    modals.openErrorModal('Error', 'Something went wrong')
  }
}
