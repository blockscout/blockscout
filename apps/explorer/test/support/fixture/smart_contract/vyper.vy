from vyper.interfaces import ERC20

implements: ERC20

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

name: public(String[64])
symbol: public(String[32])
decimals: public(uint256)

balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
totalSupply: public(uint256)
minter: address
_supply: uint256
_check: uint256 #1% of the total supply check


@external
def __init__():
    self._supply = 10_000_000_000 
    self._check = 100_000_000
    self.decimals = 18
    self.name = 'Kooopa'
    self.symbol = 'KOO'
    
    init_supply: uint256 = self._supply * 10 ** self.decimals
    
    self.balanceOf[msg.sender] = init_supply
    self.totalSupply = init_supply
    self.minter = msg.sender

    log Transfer(ZERO_ADDRESS, msg.sender, init_supply)


@internal
def _transfer(_from : address, _to : address, _value : uint256) -> bool:
    assert _value <= self._check, 'Transfer limit of 1%(100 Million) Tokens'

    TargetBalance: uint256 = self.balanceOf[_to] + _value
    assert TargetBalance <= self._check, 'Single wallet cannot hold more than 1%(100 Million) Tokens'

    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    log Transfer(_from, _to, _value)
    return True


@external
def transfer(_to : address, _value : uint256) -> bool:
    self._transfer(msg.sender, _to, _value)
    return True


@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    self._transfer(_from, _to, _value)
    self.allowance[_from][msg.sender] -= _value
    return True


@external
def approve(_spender : address, _value : uint256) -> bool:
    assert _value <= self._check, 'Cant Approve more than 1%(100 Million) Tokens for transfer'

    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True


@external
def mint(_to: address, _value: uint256):
    assert msg.sender == self.minter
    assert _to != ZERO_ADDRESS
    self.totalSupply += _value
    self.balanceOf[_to] += _value
    log Transfer(ZERO_ADDRESS, _to, _value)


@internal
def _burn(_to: address, _value: uint256):
    
    assert _to != ZERO_ADDRESS
    self.totalSupply -= _value
    self.balanceOf[_to] -= _value
    log Transfer(_to, ZERO_ADDRESS, _value)


@external
def burn(_value: uint256):
    self._burn(msg.sender, _value)


@external
def burnFrom(_to: address, _value: uint256):
    self.allowance[_to][msg.sender] -= _value
    self._burn(_to, _value)        