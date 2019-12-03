import React from 'react'
import styled from 'styled-components'

import Chart from './Chart'

export default () => {
  return (
    <Column>
      <DashboardHeader>
        <Container>
          <Chart />
        </Container>
      </DashboardHeader>
    </Column>
  )
}

const Column = styled.div`
  display: flex;
  flex-direction: column;
`

const Container = styled.div`
  width: 1110px;
  margin: 0 auto;
`

const DashboardHeader = styled.div`
  height: 250px;
  background-image: linear-gradient(180deg, #5c34a2, #673ab5);
  box-shadow: 0 5px 40px -5px rgba(0,0,0,.25);
`
