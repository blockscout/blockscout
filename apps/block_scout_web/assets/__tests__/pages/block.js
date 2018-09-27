import { reducer, initialState } from '../../js/pages/block'


test('CHANNEL_DISCONNECTED', () => {
  const state = initialState
  const action = {
    type: 'CHANNEL_DISCONNECTED'
  }
  const output = reducer(state, action)

  expect(output.channelDisconnected).toBe(true)
})

describe('RECEIVED_NEW_BLOCK', () => {
  test('receives new block', () => {
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: 'test',
        blockNumber: 1
      }
    }
    const output = reducer(initialState, action)

    expect(output.newBlock).toBe('test')
    expect(output.currentBlockNumber).toBe(1)
  })
  test('on page 2+', () => {
    const state = Object.assign({}, initialState, {
      beyondPageOne: true
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msgs: [{
        blockHtml: 'test'
      }]
    }
    const output = reducer(state, action)

    expect(output.newBlock).toBe(null)
  })
  test('inserts place holders if block received out of order', () => {
    const state = Object.assign({}, initialState, {
      currentBlockNumber: 2
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: 'test5',
        blockNumber: 5
      }
    }
    const output = reducer(state, action)

    expect(output.newBlock).toBe('test5')
    expect(output.currentBlockNumber).toBe(5)
    expect(output.skippedBlockNumbers).toEqual([3, 4])
  })
})
