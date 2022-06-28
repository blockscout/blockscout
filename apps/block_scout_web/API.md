# API Documentation

  * [BlockScoutWeb.Account.Api.V1.UserController](#blockscoutweb-account-api-v1-usercontroller)
    * [info](#blockscoutweb-account-api-v1-usercontroller-info)
    * [create_tag_address](#blockscoutweb-account-api-v1-usercontroller-create_tag_address)
    * [tags_address](#blockscoutweb-account-api-v1-usercontroller-tags_address)
    * [create_tag_transaction](#blockscoutweb-account-api-v1-usercontroller-create_tag_transaction)
    * [tags_transaction](#blockscoutweb-account-api-v1-usercontroller-tags_transaction)
    * [create_watchlist](#blockscoutweb-account-api-v1-usercontroller-create_watchlist)

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-info></a>info
#### Get info about user

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/info
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTg5NTk5MTgsImlhdCI6MTY1NjU0MDcxOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNDk2ODM4NzYtM2ZkYS00MWEzLWFhOTYtZTQzZTMxYTExMzA2IiwibmJmIjoxNjU2NTQwNzE3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.SbA3-DSbRC0FXrIymavxevcR1wZL15Dr-ILqzICV_SRet3pya4rywBsIVHXITp1_kHUMQdCgSi2mKsKutP5oHQ
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv03AbC0Qu51EPAAAASD
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "nickname": "test_user6",
  "name": "User Test6",
  "email": "test_user-6@blockscout.com",
  "avatar": "https://example.com/avatar/test_user6"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_address></a>create_tag_address
#### Create private address tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTg5NTk5MTgsImlhdCI6MTY1NjU0MDcxOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDhkZGY3NDUtYTI5YS00ZTVhLThiMWItNmUxZTBkOWU3NTk1IiwibmJmIjoxNjU2NTQwNzE3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.iomU7m4tS4Bjuvry4eY0PE93oLXJhlIP2wg5ohNhtXwS939DavPdpkcr_kQX8fQDommt29Lj0tgOKEHy_Jlg9Q
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "MyName",
  "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv03Aa-l1pQf1qUAAAOj
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "MyName",
  "id": 70,
  "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-tags_address></a>tags_address
#### Get private addresses tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTg5NTk5MTgsImlhdCI6MTY1NjU0MDcxOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMWQ3NmNmNzEtYjAzZi00NjE3LThmYWQtNDIwYjU5OGRlNDVkIiwibmJmIjoxNjU2NTQwNzE3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDAiLCJ0eXAiOiJhY2Nlc3MifQ.1skgqID9Tc8Yo-QXP969CZjR4RjXSpoxs1WAwonxvxgufOGh7RXJctDobXQPTcREl6kX9SRZeE8ozz_ni8C_BA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv03AapFqH90MQ4AAAXk
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "name": "name0",
    "id": 64,
    "address_hash": "0x0000000000000000000000000000000000000001"
  },
  {
    "name": "name1",
    "id": 65,
    "address_hash": "0x0000000000000000000000000000000000000002"
  },
  {
    "name": "name2",
    "id": 66,
    "address_hash": "0x0000000000000000000000000000000000000003"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_transaction></a>create_tag_transaction
#### Error on try to create private transaction tag for tx does not exist

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTg5NTk5MTgsImlhdCI6MTY1NjU0MDcxOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDAxY2VkMjItYzQwNS00NGZhLWI5NGUtODY2MmE5MzgwY2MyIiwibmJmIjoxNjU2NTQwNzE3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.KozzoCCYxm-IplVfHxMt9D6Y3OlBC3oQc--lFvS-iUNzXZFldrxt2Gb0nFDDBVrJTeigYInbzzlJrMpyI_ca9A
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000006",
  "name": "MyName"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv03AbLZLRHMT8QAABxh
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "errors": {
    "tx_hash": [
      "Transaction does not exist"
    ]
  }
}
```

#### Create private transaction tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTg5NTk5MTgsImlhdCI6MTY1NjU0MDcxOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDAxY2VkMjItYzQwNS00NGZhLWI5NGUtODY2MmE5MzgwY2MyIiwibmJmIjoxNjU2NTQwNzE3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.KozzoCCYxm-IplVfHxMt9D6Y3OlBC3oQc--lFvS-iUNzXZFldrxt2Gb0nFDDBVrJTeigYInbzzlJrMpyI_ca9A
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000007",
  "name": "MyName"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv03AbL6z-jMT8QAAByB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000007",
  "name": "MyName",
  "id": 58
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-tags_transaction></a>tags_transaction
#### Get private transactions tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTg5NTk5MTgsImlhdCI6MTY1NjU0MDcxOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNWUyMGFlNGYtNDViMi00MDk3LTk5MzItNmY4ZWNhYzQxOTcxIiwibmJmIjoxNjU2NTQwNzE3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ.8aONMNSke-aARWRtOc8Xtnad0ogoKcbtMFmS0oLpyWaYUsbdqWk5TB2Lz8bHZiQEM6orSMri60CGP1ZKuZxNEA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv03AbJVqMZqFagAABxB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000003",
    "name": "name0",
    "id": 54
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000004",
    "name": "name1",
    "id": 55
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000005",
    "name": "name2",
    "id": 56
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_watchlist></a>create_watchlist
#### Add address to watchlist

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/watchlist
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTg5NTk5MTgsImlhdCI6MTY1NjU0MDcxOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjNmYWRlYmUtZDVkMy00NzM5LTg5NjMtZWE5ZmNhMDc3OTRiIiwibmJmIjoxNjU2NTQwNzE3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.-77CX9iIIYJmxW8b9qQRBWOSK7JbjbX0P3RoUoAPXaKQxBDnLJO4t-_9IUIlJocUV2gM5SroBXwWiYkPXVbAbw
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": true,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": true,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test0",
  "address_hash": "0x0000000000000000000000000000000000000004"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv03AaqVm0sYOtYAAAFi
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": true,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": true,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test0",
  "id": 13,
  "exchange_rate": null,
  "address_hash": "0x0000000000000000000000000000000000000004",
  "address_balance": null
}
```

