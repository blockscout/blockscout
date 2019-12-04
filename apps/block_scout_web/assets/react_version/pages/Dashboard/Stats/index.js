import React from 'react'
import styled from 'styled-components'

export default () => {
  return (
    <Container>
      <Background />
      {[
        { title: 'Average block time', value: '5 seconds' },
        { title: 'Total transactions', value: '8,704,244' },
        { title: 'Total blocks', value: '12,343,450' },
        { title: 'Wallett addresses', value: '96,817' },
      ].map(item =>
        <Item key={item.title}>
          <ItemTitle>{item.title}</ItemTitle>
          <ItemValue>{item.value}</ItemValue>
          <ItemMarker />
        </Item>
      )}
    </Container>
  )
}

const Column = styled.div`
  display: flex;
  flex-direction: column;
`

const Row = styled.div`
  display: flex;
  flex-direction: row;
`

const Container = styled(Row)`
  flex: 1;
  align-items: center;
  justify-content: space-between;
  padding: 20px 0 0 60px;
  margin: 45px 0 0 30px;
  position: relative;
`

const Background = styled.div`
  position: absolute;
  top: 0;
  left: 0;
  height: 200%;
  width: 9999px;
  background-color: #8258cd;
  -webkit-box-shadow: 0 0 35px 0 rgba(0,0,0,.2);
  box-shadow: 0 0 35px 0 rgba(0,0,0,.2);
  border-top-left-radius: 10px;
`

const Item = styled(Column)`
  position: relative;
  padding-left: 20px;
`

const ItemTitle = styled.span`
  color: #dcc8ff;
`

const ItemValue = styled.span`
  color: #fff;
  font-size: 24px;
`

const ItemMarker = styled.div`
  background-color: #87e1a9;
  border-radius: 2px;
  height: 100%;
  left: 0;
  position: absolute;
  top: 0;
  width: 4px;
`
