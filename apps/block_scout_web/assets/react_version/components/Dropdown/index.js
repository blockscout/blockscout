import React from 'react'
import styled from 'styled-components'
import { DropdownButton, Dropdown } from 'react-bootstrap'

export default ({ title, items }) => {
  return (
    <CustomDropdownButton
        title={title}
        variant=""
        key={title}
      >
        {items.map(item =>
          <Dropdown.Item key={item.path} href={item.path}>{item.title}</Dropdown.Item>
        )}
      </CustomDropdownButton>
  )
}

const CustomDropdownButton = styled(DropdownButton)`
  & > .btn {
    box-shadow: none !important;
  }
`
