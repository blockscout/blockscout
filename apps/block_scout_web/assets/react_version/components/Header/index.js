import React from 'react'
import styled from 'styled-components'

import Dropdown from '../Dropdown';
import Button from '../Button';

export default () => {
  return (
    <Container>
      <LogoContainer>
        <Logo src="/images/blockscout_logo.svg" />
      </LogoContainer>
      <ButtonsContainer>
        <Dropdown
          title="Blocks"
          items={[
            { title: 'Blocks', path: '/blocks' },
            { title: 'Uncles', path: '/uncles' },
            { title: 'Forked Blocks (Reorgs)', path: '/reorgs' },
          ]}
        />
        <Dropdown
          title="Transactions"
          items={[
            { title: 'Validated', path: '/txs' },
            { title: 'Pending', path: '/pending_transactions' },
          ]}
        />
        <Button variant="" onClick={() => window.location.href = 'accounts'}>Accounts</Button>
        <Dropdown
          title="APIs"
          items={[
            { title: 'GraphQL', path: '/graphiql' },
            { title: 'RPC', path: '/api_docs' },
            { title: 'Eth RPC', path: '/eth_rpc_api_docs' },
          ]}
        />
        <Dropdown
          title="Network"
          items={[
            { title: 'POA Sokol', path: '/' },
            { title: 'POA Core', path: '/' },
            { title: 'xDai Chain', path: '/' },
          ]}
        />
      </ButtonsContainer>
      <SearchInput placeholder="Search by address, token symbol name, transaction hash, or block number" />
    </Container>
  )
}

const Container = styled.div`
  height: 56px;
  width: 100%;
  display: flex;
  flex-direction: row;
  background-color: #ffffff;
  box-shadow: 0 0 30px 0 rgba(21,53,80,.12);
`

const LogoContainer = styled.div`
  display: flex;
  flex-diraction: row;
  align-items: center;
  margin-left: 30px;
`

const Logo = styled.img`
  height: 28px;
  width: auto;
`

const ButtonsContainer = styled.div`
  flex: 3;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: flex-end;
  padding: 0 20px;
`

const SearchInput = styled.input`
  flex: 1;
  background: #f5f6fa;
  border: 0;
  color: #828ba0;
  font-size: 12px;
  padding-left: 38px;
  padding-right: 8px;
  outline: none;
`
