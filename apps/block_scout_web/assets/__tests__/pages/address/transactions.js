import { reducer, initialState } from '../../../js/pages/address/transactions'

describe('RECEIVED_NEW_TRANSACTION', () => {
  test('with new transaction', () => {
    const state = Object.assign({}, initialState, {
      items: ['transaction html']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { transactionHtml: 'another transaction html' }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([ 'another transaction html', 'transaction html' ])
  })

  test('when channel has been disconnected', () => {
    const state = Object.assign({}, initialState, {
      channelDisconnected: true,
      items: ['transaction html']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { transactionHtml: 'another transaction html' }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['transaction html'])
  })

  test('beyond page one', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true,
      items: ['transaction html']
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: { transactionHtml: 'another transaction html' }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([ 'transaction html' ])
  })

  test('adds the new transaction to state even when it is filtered by to', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '0x001',
      filter: 'to',
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        fromAddressHash: '0x002',
        transactionHtml: 'transaction html',
        toAddressHash: '0x001'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['transaction html'])
  })

  test(
    'does nothing when it is filtered by to but the toAddressHash is different from addressHash',
    () => {
    const state = Object.assign({}, initialState, {
      addressHash: '0x001',
      filter: 'to',
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        fromAddressHash: '0x003',
        transactionHtml: 'transaction html',
        toAddressHash: '0x002'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
  })

  test('adds the new transaction to state even when it is filtered by from', () => {
    const state = Object.assign({}, initialState, {
      addressHash: '0x001',
      filter: 'from',
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        fromAddressHash: '0x001',
        transactionHtml: 'transaction html',
        toAddressHash: '0x002'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual(['transaction html'])
  })

  test(
    'does nothing when it is filtered by from but the fromAddressHash is different from addressHash',
    () => {
    const state = Object.assign({}, initialState, {
      addressHash: '0x001',
      filter: 'to',
      items: []
    })
    const action = {
      type: 'RECEIVED_NEW_TRANSACTION',
      msg: {
        addressHash: '0x001',
        transactionHtml: 'transaction html',
        fromAddressHash: '0x002'
      }
    }
    const output = reducer(state, action)

    expect(output.items).toEqual([])
  })
})
