import $ from 'jquery'
import humps from 'humps'
import socket from '../socket'
import router from '../router'
import { batchChannel } from '../utils'

const BATCH_THRESHOLD = 10

router.when('/addresses/:addressHash').then(({ addressHash, blockNumber, filter }) => {
  const channel = socket.channel(`addresses:${addressHash}`, {})
  const $channelDisconnected = $('[data-selector="channel-disconnected-message"]')
  const $channelBatching = $('[data-selector="channel-batching-message"]')
  channel.join()
    .receive('ok', resp => { console.log('Joined successfully', `addresses:${addressHash}`, resp) })
    .receive('error', resp => { console.log('Unable to join', `addresses:${addressHash}`, resp) })
  channel.onError(() => {
    $channelDisconnected.show()
    $channelBatching.hide()
  })

  const $overview = $('[data-selector="overview"]')
  if ($overview) {
    channel.on('overview', (msg) => {
      $overview.empty().append(msg.overview)
    })
  }

  if (!blockNumber) {
    const $emptyTransactionsList = $('[data-selector="empty-transactions-list"]')
    if ($emptyTransactionsList.length) {
      channel.on('transaction', () => {
        window.location.reload()
      })
    }

    const $transactionsList = $('[data-selector="transactions-list"]')
    const $channelBatchingCount = $('[data-selector="channel-batching-count"]')
    let batchCountAccumulator = 0
    if ($transactionsList.length) {
      channel.on('transaction', batchChannel((msgs) => {
        if ($channelDisconnected.is(':visible')) {
          return
        }

        if (msgs.length > BATCH_THRESHOLD || batchCountAccumulator > 0) {
          $channelBatching.show()
          batchCountAccumulator += msgs.length
          $channelBatchingCount[0].innerHTML = batchCountAccumulator
        } else {
          const transactionsHtml = humps.camelizeKeys(msgs)
            .filter(({toAddressHash, fromAddressHash}) => (
              !filter ||
              (filter === 'to' && toAddressHash === addressHash) ||
              (filter === 'from' && fromAddressHash === addressHash)
            ))
            .map(({transactionHtml}) => transactionHtml)
            .reverse()
            .join('')
          $transactionsList.prepend(transactionsHtml)
        }
      }))
    }
  }
})
