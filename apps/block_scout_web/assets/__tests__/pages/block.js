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
    expect(output.blockNumbers).toEqual([1])
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
    expect(output.blockNumbers).toEqual([])
    expect(output.skippedBlockNumbers).toEqual([])
  })
  test('inserts place holders if block received out of order', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [2]
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
    expect(output.blockNumbers).toEqual([5, 4, 3, 2])
    expect(output.skippedBlockNumbers).toEqual([3, 4])
  })
  test('replaces skipped block', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [5, 4, 3, 2, 1],
      skippedBlockNumbers: [1, 3, 4]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: 'test3',
        blockNumber: 3
      }
    }
    const output = reducer(state, action)

    expect(output.newBlock).toBe('test3')
    expect(output.blockNumbers).toEqual([5, 4, 3, 2, 1])
    expect(output.skippedBlockNumbers).toEqual([1, 4])
  })
  test('replaces duplicated block', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [5, 4]
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
    expect(output.blockNumbers).toEqual([5, 4])
  })
  test('skips if new block height is lower than lowest on page', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [5, 4, 3, 2]
    })
    const action = {
      type: 'RECEIVED_NEW_BLOCK',
      msg: {
        blockHtml: 'test1',
        blockNumber: 1
      }
    }
    const output = reducer(state, action)

    expect(output.newBlock).toBe(null)
    expect(output.blockNumbers).toEqual([5, 4, 3, 2])
  })
})
