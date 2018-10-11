import { reducer, initialState } from '../../js/pages/block'

test('CHANNEL_DISCONNECTED', () => {
  const state = initialState
  const action = {
    type: 'CHANNEL_DISCONNECTED'
  }
  const output = reducer(state, action)

  expect(output.channelDisconnected).toBe(true)
})

describe('PAGE_LOAD', () => {
  test('page 1 loads block numbers', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      beyondPageOne: false,
      blockNumbers: [2, 1]
    }
    const output = reducer(state, action)

    expect(output.beyondPageOne).toBe(false)
    expect(output.blockNumbers).toEqual([2, 1])
    expect(output.skippedBlockNumbers).toEqual([])
  })
  test('page 2 loads block numbers', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      beyondPageOne: true,
      blockNumbers: [2, 1]
    }
    const output = reducer(state, action)

    expect(output.beyondPageOne).toBe(true)
    expect(output.blockNumbers).toEqual([2, 1])
    expect(output.skippedBlockNumbers).toEqual([])
  })
  test('page 1 with skipped blocks', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      beyondPageOne: false,
      blockNumbers: [4, 1]
    }
    const output = reducer(state, action)

    expect(output.beyondPageOne).toBe(false)
    expect(output.blockNumbers).toEqual([4, 3, 2, 1])
    expect(output.skippedBlockNumbers).toEqual([3, 2])
  })
  test('page 2 with skipped blocks', () => {
    const state = initialState
    const action = {
      type: 'PAGE_LOAD',
      beyondPageOne: true,
      blockNumbers: [4, 1]
    }
    const output = reducer(state, action)

    expect(output.beyondPageOne).toBe(true)
    expect(output.blockNumbers).toEqual([4, 3, 2, 1])
    expect(output.skippedBlockNumbers).toEqual([3, 2])
  })
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
    expect(output.skippedBlockNumbers).toEqual([4, 3])
  })
  test('replaces skipped block', () => {
    const state = Object.assign({}, initialState, {
      blockNumbers: [5, 4, 3, 2, 1],
      skippedBlockNumbers: [4, 3, 1]
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
    expect(output.skippedBlockNumbers).toEqual([4, 1])
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
