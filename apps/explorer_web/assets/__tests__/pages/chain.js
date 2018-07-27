import { reducer, initialState } from '../../js/pages/chain'

test('CHANNEL_DISCONNECTED', () => {
  const state = initialState
  const action = {
    type: 'CHANNEL_DISCONNECTED'
  }
  const output = reducer(state, action)

  expect(output.channelDisconnected).toBe(true)
})

test('RECEIVED_NEW_BLOCK', () => {
    const state = Object.assign({}, initialState, {
      newBlock: 'last new block'
    })
  const action = {
    type: 'RECEIVED_NEW_BLOCK',
    msg: {
      homepageBlockHtml: 'new block'
    }
  }
  const output = reducer(state, action)

  expect(output.newBlock).toEqual('new block')
})
