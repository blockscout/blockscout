import $ from 'jquery'
import humps from 'humps'
import socket from '../socket'
import router from '../router'

router.when('/addresses/:addressHash').then(({ addressHash, blockNumber, filter }) => {
  const channel = socket.channel(`addresses:${addressHash}`, {})
  channel.join()
    .receive('ok', resp => { console.log('Joined successfully', `addresses:${addressHash}`, resp) })
    .receive('error', resp => { console.log('Unable to join', `addresses:${addressHash}`, resp) })

  if (!blockNumber) {
    const $emptyTransactionsList = $('[data-selector="empty-transactions-list"]')
    if ($emptyTransactionsList) {
      channel.on('transaction', () => {
        window.location.reload()
      })
    }

    const $transactionsList = $('[data-selector="transactions-list"]')
    if ($transactionsList) {
      channel.on('transaction', (msg) => {
        const {
          toAddressHash,
          fromAddressHash,
          transactionHtml
        } = humps.camelizeKeys(msg)

        if (filter === 'to' && toAddressHash !== addressHash) {
          return
        }
        if (filter === 'from' && fromAddressHash !== addressHash) {
          return
        }

        $transactionsList.prepend(transactionHtml)
      })
    }
  }
})
