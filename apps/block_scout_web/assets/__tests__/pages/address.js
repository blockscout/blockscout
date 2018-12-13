import { reducer, initialState } from '../../js/pages/address'

describe('RECEIVED_NEW_BLOCK', () => {
  test('increases validation count', () => {
    const state = Object.assign({}, initialState, { validationCount: 30 })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      blockHtml: 'test 2'
    }
    const output = reducer(state, action)

    expect(output.validationCount).toEqual(31)
  })
  test('when channel has been disconnected does not increase validation count', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      validationCount: 30
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      blockHtml: 'test 2'
    }
    const output = reducer(state, action)

    expect(output.validationCount).toEqual(30)
  })
})

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('increment the transactions count', () => {
    const state = Object.assign({}, initialState, {
      addressHash: "0x001",
      transactionCount: 1
    })

    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { fromAddressHash: "0x001", transactionHash: 2, transactionHtml: 'test 2' }
    }

    const newState = reducer(state, action)

    expect(newState.transactionCount).toEqual(2)
  })

  test('does not increment the count if the channel is disconnected', () => {
    const state = Object.assign({}, initialState, {
      addressHash: "0x001",
      transactionCount: 1,
      channelDisconnected: true
    })

    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { fromAddressHash: "0x001", transactionHash: 2, transactionHtml: 'test 2' }
    }

    const newState = reducer(state, action)

    expect(newState.transactionCount).toEqual(1)
  })
})
