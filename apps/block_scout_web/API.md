# API Documentation

  * [BlockScoutWeb.Account.Api.V1.UserController](#blockscoutweb-account-api-v1-usercontroller)
    * [info](#blockscoutweb-account-api-v1-usercontroller-info)
    * [create_tag_address](#blockscoutweb-account-api-v1-usercontroller-create_tag_address)
    * [tags_address](#blockscoutweb-account-api-v1-usercontroller-tags_address)
    * [delete_tag_address](#blockscoutweb-account-api-v1-usercontroller-delete_tag_address)
    * [create_tag_transaction](#blockscoutweb-account-api-v1-usercontroller-create_tag_transaction)
    * [tags_transaction](#blockscoutweb-account-api-v1-usercontroller-tags_transaction)
    * [delete_tag_transaction](#blockscoutweb-account-api-v1-usercontroller-delete_tag_transaction)
    * [create_watchlist](#blockscoutweb-account-api-v1-usercontroller-create_watchlist)
    * [watchlist](#blockscoutweb-account-api-v1-usercontroller-watchlist)
    * [delete_watchlist](#blockscoutweb-account-api-v1-usercontroller-delete_watchlist)
    * [update_watchlist](#blockscoutweb-account-api-v1-usercontroller-update_watchlist)
    * [create_watchlist](#blockscoutweb-account-api-v1-usercontroller-create_watchlist)
    * [update_watchlist](#blockscoutweb-account-api-v1-usercontroller-update_watchlist)
    * [create_api_key](#blockscoutweb-account-api-v1-usercontroller-create_api_key)
    * [api_keys](#blockscoutweb-account-api-v1-usercontroller-api_keys)
    * [update_api_key](#blockscoutweb-account-api-v1-usercontroller-update_api_key)
    * [delete_api_key](#blockscoutweb-account-api-v1-usercontroller-delete_api_key)
    * [create_custom_abi](#blockscoutweb-account-api-v1-usercontroller-create_custom_abi)
    * [custom_abis](#blockscoutweb-account-api-v1-usercontroller-custom_abis)
    * [update_custom_abi](#blockscoutweb-account-api-v1-usercontroller-update_custom_abi)
    * [delete_custom_abi](#blockscoutweb-account-api-v1-usercontroller-delete_custom_abi)
  * [BlockScoutWeb.Account.Api.V1.TagsController](#blockscoutweb-account-api-v1-tagscontroller)
    * [tags_address](#blockscoutweb-account-api-v1-tagscontroller-tags_address)
    * [tags_transaction](#blockscoutweb-account-api-v1-tagscontroller-tags_transaction)
  * [BlockScoutWeb.Account.Api.V1.AuthController](#blockscoutweb-account-api-v1-authcontroller)

## BlockScoutWeb.Account.Api.V1.AuthController
### <a id=blockscoutweb-account-api-v1-authcontroller-login></a>login
#### Login

##### Request
* __Method:__ GET
* __Path:__ /auth/auth0_api


##### Response
* __Status__: 200
* __Response body:__
```json
{"auth_token":"..."}
```

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-info></a>info
#### Get info about user

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/info
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjgwZDE2ZmMtODIxYi00ZjE5LWEwNjctMzhmNjg0MzIzZTNjIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.jotiQ5Pldu8CBfMxehUqtxczNDT69TBTdQtqNcR2_XM5dlCvBcGtGzi_kPmzoHBhtexhd_ALTBVQw_IpNVN2Ag
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrExR_T21P4AABoi
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "nickname": "test_user4",
  "name": "User Test4",
  "email": "test_user-4@blockscout.com",
  "avatar": "https://example.com/avatar/test_user4"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_address></a>create_tag_address
#### Add private address tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMjczZjNkZDYtNGZjNS00ZDUzLTk5YmItOTZhZTk3N2UyNmM3IiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE3IiwidHlwIjoiYWNjZXNzIn0.1prZNi5Xq_WAIujVc9V3321d-uFA3mPcUT16QWs0khgoqHTA8mOZNt-n7eI_tZN-hcNydzxeT6xVy_GyPCZHBw
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
x-request-id: Fv2GJrt4eg4v1xMAACdi
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "MyName",
  "id": 84,
  "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
}
```

## BlockScoutWeb.Account.Api.V1.TagsController
### <a id=blockscoutweb-account-api-v1-tagscontroller-tags_address></a>tags_address
#### Get tags for address

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/tags/address/0x3e9ac8f16c92bc4f093357933b5befbf1e16987b
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMjczZjNkZDYtNGZjNS00ZDUzLTk5YmItOTZhZTk3N2UyNmM3IiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE3IiwidHlwIjoiYWNjZXNzIn0.1prZNi5Xq_WAIujVc9V3321d-uFA3mPcUT16QWs0khgoqHTA8mOZNt-n7eI_tZN-hcNydzxeT6xVy_GyPCZHBw
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJruw6IIv1xMAACeC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "watchlist_names": [],
  "personal_tags": [
    {
      "label": "MyName",
      "display_name": "MyName"
    }
  ],
  "common_tags": []
}
```

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-tags_address></a>tags_address
#### Get private addresses tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNmMwNjZmZmUtMjQ2OS00NzY5LTlkNmEtNjg2ZDNjOWI4MGYyIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEwIiwidHlwIjoiYWNjZXNzIn0.7oAYBVq380UTK0wQ29Vxwy8ulbFXjo9TLMed01zZxBIVlyU20-VxhgzYyyNupgy6gyErHcKTb4qam06vUtN71A
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrWZ_VYkN5QAAB8C
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "name": "name0",
    "id": 81,
    "address_hash": "0x0000000000000000000000000000000000000014"
  },
  {
    "name": "name1",
    "id": 82,
    "address_hash": "0x0000000000000000000000000000000000000015"
  },
  {
    "name": "name2",
    "id": 83,
    "address_hash": "0x0000000000000000000000000000000000000016"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_tag_address></a>delete_tag_address
#### Delete private address tag

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/tags/address/78
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMzViZjA1MDgtYTRlMS00ZTcwLWJhNDUtOTNmN2U2NGFkZjY0IiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDMiLCJ0eXAiOiJhY2Nlc3MifQ.1_g_NHHOIizEzw-l4RdwrVH8PVRkXfcwWOmC8gpp-T8alEfamEfGhvvcXRfjmcug9kRDP5WKRkGMPi0XTcULRg
```

##### Response
* __Status__: 200
* __Response headers:__
```
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrB7MoNP5PQAABmC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json

```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_transaction></a>create_tag_transaction
#### Error on try to create private transaction tag for tx does not exist

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZGVhODZkYTktYjRmNC00NGE0LTgzMzQtYjhiZjgwZWRlNDUyIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.L4-N8gW9sOwXvSwUijEX-U6XHcelJQK0DJb8Weqg1Eu2jIBlY6NplembDqEsO1Rb-9Jr1nv3VzWMeWYH4Thatw
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "name": "MyName"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJq46Ly5S0w4AABFh
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZGVhODZkYTktYjRmNC00NGE0LTgzMzQtYjhiZjgwZWRlNDUyIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.L4-N8gW9sOwXvSwUijEX-U6XHcelJQK0DJb8Weqg1Eu2jIBlY6NplembDqEsO1Rb-9Jr1nv3VzWMeWYH4Thatw
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
  "name": "MyName"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJq58ynNS0w4AABgi
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
  "name": "MyName",
  "id": 68
}
```

## BlockScoutWeb.Account.Api.V1.TagsController
### <a id=blockscoutweb-account-api-v1-tagscontroller-tags_transaction></a>tags_transaction
#### Get tags for transaction

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000001
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZGVhODZkYTktYjRmNC00NGE0LTgzMzQtYjhiZjgwZWRlNDUyIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.L4-N8gW9sOwXvSwUijEX-U6XHcelJQK0DJb8Weqg1Eu2jIBlY6NplembDqEsO1Rb-9Jr1nv3VzWMeWYH4Thatw
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJq6MxEtS0w4AABGB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "watchlist_names": [],
  "personal_tx_tag": {
    "label": "MyName"
  },
  "personal_tags": [],
  "common_tags": []
}
```

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-tags_transaction></a>tags_transaction
#### Get private transactions tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTYwZGFmZDQtMTJiOS00OTIzLTgzNmItNDE0YTA4NzZjMjYwIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.wLMhbPAPYu2wF5JtRnUjsvGWzV9y-LI3YNyUoo3zj_HdSNFWsBIhORaVCIeHSGp4kBggFmv4myRZe7S4hUCh_g
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrQvRgis4YIAABYB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000002",
    "name": "name0",
    "id": 69
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000003",
    "name": "name1",
    "id": 70
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000004",
    "name": "name2",
    "id": 71
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_tag_transaction></a>delete_tag_transaction
#### Delete private transaction tag

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/tags/transaction/72
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjY2MjU0NjMtNGEyMi00NzU5LTkxNGEtYWYyMWZkYWI4MzI0IiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.TSD0Q0k6vLQWHLW69VNjHxuLj-d5UIQ_mGeE1SKBtHYlpK1FnSjml2Yvw9JnQ0R0X4J57rdpf0ei-ot7Tv3RGg
```

##### Response
* __Status__: 200
* __Response headers:__
```
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrivA-UT9c4AACQC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json

```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_watchlist></a>create_watchlist
#### Add address to watchlist

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/watchlist
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjIyY2JmMzYtZDZiZC00YzQzLWI2YTMtYjE5ZjEwZGU2MzhhIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.7tuq-HJ1m8n17_RIW3d2skm47IB9tx2AiQAF6BdSoTtxd0EiZfbnz4sh7BT4JSQxmYXMzOjR9yqpCtnY-QW4gg
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": false
    },
    "ERC-721": {
      "outcoming": true,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": false,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test6",
  "address_hash": "0x0000000000000000000000000000000000000017"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrYMQz4yfYIAACDC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": false
    },
    "ERC-721": {
      "outcoming": true,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": false,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test6",
  "id": 32,
  "exchange_rate": null,
  "address_hash": "0x0000000000000000000000000000000000000017",
  "address_balance": null
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-watchlist></a>watchlist
#### Get addresses from watchlists

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/watchlist
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjIyY2JmMzYtZDZiZC00YzQzLWI2YTMtYjE5ZjEwZGU2MzhhIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.7tuq-HJ1m8n17_RIW3d2skm47IB9tx2AiQAF6BdSoTtxd0EiZfbnz4sh7BT4JSQxmYXMzOjR9yqpCtnY-QW4gg
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrZ44twyfYIAACFC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "notification_settings": {
      "native": {
        "outcoming": false,
        "incoming": false
      },
      "ERC-721": {
        "outcoming": true,
        "incoming": true
      },
      "ERC-20": {
        "outcoming": false,
        "incoming": true
      }
    },
    "notification_methods": {
      "email": true
    },
    "name": "test6",
    "id": 32,
    "exchange_rate": null,
    "address_hash": "0x0000000000000000000000000000000000000017",
    "address_balance": null
  },
  {
    "notification_settings": {
      "native": {
        "outcoming": false,
        "incoming": true
      },
      "ERC-721": {
        "outcoming": false,
        "incoming": true
      },
      "ERC-20": {
        "outcoming": false,
        "incoming": false
      }
    },
    "notification_methods": {
      "email": true
    },
    "name": "test7",
    "id": 33,
    "exchange_rate": null,
    "address_hash": "0x0000000000000000000000000000000000000018",
    "address_balance": null
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_watchlist></a>delete_watchlist
#### Delete address from watchlist by id

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/watchlist/35
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODI2NDIyOTItZmVkNS00ZDVlLTg4ZWUtOWQ1Y2MzZTNmMmQ0IiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEzIiwidHlwIjoiYWNjZXNzIn0.54XGqd5ZJub6IwCFo5qsFmLnIdhZbxQzY8rNhSyqkSRnFyU24A3ilq47jJHGWDVua4D9sWq8rxW-UhdTB9_zcg
```

##### Response
* __Status__: 200
* __Response headers:__
```
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrcxLRW6yO4AACJi
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json

```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_watchlist></a>update_watchlist
#### Edit watchlist address

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/watchlist/36
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZTFkNWU2OWMtNWM0Ni00YTNiLWEzZGYtNWQ3ZGJlOGM4OTgzIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE4IiwidHlwIjoiYWNjZXNzIn0.w4Vbz2j63XnVkBnk9gJMxudnvflSuIqgxN_c7EYTsdQAgzzNGqwlQwXySaz7524n7lddc8Xi7_AW01WPz7EJig
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
      "outcoming": false,
      "incoming": false
    },
    "ERC-20": {
      "outcoming": false,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test27",
  "address_hash": "0x0000000000000000000000000000000000000032"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrxOMiKxvrkAABkh
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
      "outcoming": false,
      "incoming": false
    },
    "ERC-20": {
      "outcoming": false,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test27",
  "id": 36,
  "exchange_rate": null,
  "address_hash": "0x0000000000000000000000000000000000000032",
  "address_balance": null
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_watchlist></a>create_watchlist
#### Example of error on creating watchlist address

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/watchlist
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjY0Mzc4NDktMDBiNi00MzlhLTliY2YtMzY5YWQ5NDI4YTgwIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.kifHyUUFcOpKZ07cmrfjJ2G_OhBq_SxKtQ8ftv4gq4wEhoNCeYuedrrwwQ-KEC8h02zUH6hzsCOrMxYeO5sPVA
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
      "outcoming": false,
      "incoming": false
    },
    "ERC-20": {
      "outcoming": false,
      "incoming": false
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test4",
  "address_hash": "0x0000000000000000000000000000000000000012"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrSb0Ppv5V8AAB2C
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "errors": {
    "watchlist_id": [
      "Address already added to the watchlist"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_watchlist></a>update_watchlist
#### Example of error on editing watchlist address

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/watchlist/31
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjY0Mzc4NDktMDBiNi00MzlhLTliY2YtMzY5YWQ5NDI4YTgwIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.kifHyUUFcOpKZ07cmrfjJ2G_OhBq_SxKtQ8ftv4gq4wEhoNCeYuedrrwwQ-KEC8h02zUH6hzsCOrMxYeO5sPVA
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
      "outcoming": false,
      "incoming": false
    },
    "ERC-20": {
      "outcoming": false,
      "incoming": false
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test4",
  "address_hash": "0x0000000000000000000000000000000000000012"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrTQWtlv5V8AAB2i
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "errors": {
    "watchlist_id": [
      "Address already added to the watchlist"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_api_key></a>create_api_key
#### Add api key

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/api_keys
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNWVhOWMwMDEtOGI4NS00YTRlLWIxZDEtNTVmZjVkZGY4YjFlIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIiLCJ0eXAiOiJhY2Nlc3MifQ.U_gPb7BluCbD63l10BMmlOdt8cw9kJZhG3-7ON2UUfWhjPEmlW8zBXZu60MBZ8lTeAlNDOzswG7do2DX7_Ffsg
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJq9YKU199NEAABlC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "test",
  "api_key": "d7dafd5d-0166-4c82-b250-5b88722f32ee"
}
```

#### Example of error on creating api key

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/api_keys
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTNhMzRlMDctZWJlYS00OGM5LTg4OWMtYzY3YWIzZTIwNTNmIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ.GSwD3mU7ZtEKUMv0PvUIprrEFzvOUitCU8iwRddfKvT01Z1U8BjMM8zroN6voHPZJasXGvznSC_PkarSVgZ7Mg
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrLc0AmvcEwAABxC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "errors": {
    "name": [
      "Max 3 keys per account"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-api_keys></a>api_keys
#### Get api keys list

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/api_keys
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTNhMzRlMDctZWJlYS00OGM5LTg4OWMtYzY3YWIzZTIwNTNmIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ.GSwD3mU7ZtEKUMv0PvUIprrEFzvOUitCU8iwRddfKvT01Z1U8BjMM8zroN6voHPZJasXGvznSC_PkarSVgZ7Mg
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrLl5l6vcEwAABxi
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "name": "test",
    "api_key": "58316b23-e045-409a-9e35-3dd25636cde3"
  },
  {
    "name": "test",
    "api_key": "850ee242-3bf1-45fa-95ed-4327f12a63f9"
  },
  {
    "name": "test",
    "api_key": "30825a15-248b-494b-8429-052b9c9b2ee6"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_api_key></a>update_api_key
#### Edit api key

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/api_keys/b2273c9e-94fe-47fd-ae84-21bf60c4593f
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMTgxM2FmNjctZmU4Ny00NWVmLWExMjYtNTNjMTk2NjgxYzEwIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE2IiwidHlwIjoiYWNjZXNzIn0.qEYJPN44t6sTLrQ7y9M070-KRYmHfowMMn07PVwupun6o0s9wOiX-0XZNlW0ZcuTcBfqCuH77gAbG7wFABZCgA
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test_1"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrsuoJ5B5awAACaC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "test_1",
  "api_key": "b2273c9e-94fe-47fd-ae84-21bf60c4593f"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_api_key></a>delete_api_key
#### Delete api key

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/api_keys/d7209622-7f5d-4131-b876-87c97a8db8e7
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjFlYzdhOWUtYmM4Yi00YzU4LTkxYjMtNmY4NzY2MmEyY2Q2IiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDExIiwidHlwIjoiYWNjZXNzIn0.lUKviXl8YUVNBDMhpiRPN9ycI20iYatT7qH2EHlhhvkcP62r9asI5uEVwEJmH9J8Ziq8vDFdGjO65R6OULT4aQ
```

##### Response
* __Status__: 200
* __Response headers:__
```
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrXeb09k2lAAAB_i
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json

```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_custom_abi></a>create_custom_abi
#### Add custom abi

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/custom_abis
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNmUxNWI0ZTktMWQzYS00NWViLWEyODUtNzA2Mzc5MTM1ZDY3IiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.1mVytXi_tg5A4bkQT6w1we1ha5MXDtHAQ2bu7mQIpLNaYM-tuSBtTcsdxpfXv8qvBM054eywTyvkORasR1ZVBw
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test3",
  "contract_address_hash": "0x000000000000000000000000000000000000000b",
  "abi": [
    {
      "type": "function",
      "stateMutability": "nonpayable",
      "payable": false,
      "outputs": [],
      "name": "set",
      "inputs": [
        {
          "type": "uint256",
          "name": "x"
        }
      ],
      "constant": false
    },
    {
      "type": "function",
      "stateMutability": "view",
      "payable": false,
      "outputs": [
        {
          "type": "uint256",
          "name": ""
        }
      ],
      "name": "get",
      "inputs": [],
      "constant": true
    }
  ]
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrIraAXV3gIAABtC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "test3",
  "id": 114,
  "contract_address_hash": "0x000000000000000000000000000000000000000b",
  "abi": [
    {
      "type": "function",
      "stateMutability": "nonpayable",
      "payable": false,
      "outputs": [],
      "name": "set",
      "inputs": [
        {
          "type": "uint256",
          "name": "x"
        }
      ],
      "constant": false
    },
    {
      "type": "function",
      "stateMutability": "view",
      "payable": false,
      "outputs": [
        {
          "type": "uint256",
          "name": ""
        }
      ],
      "name": "get",
      "inputs": [],
      "constant": true
    }
  ]
}
```

#### Example of error on creating custom abi

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/custom_abis
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOTM3NzM1ODktNTIxNy00NzU2LWIxMDEtMzQ1MTMzNTQzNDIzIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.xqRYJBXibGbwOGWKwLpgu_ZPOYqGHAuLngsXzuv_rm7YaxWqVfpWiUNgCz-Wa7FmwtufXQQ9MbIyeTurzCrxtw
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test25",
  "contract_address_hash": "0x0000000000000000000000000000000000000030",
  "abi": [
    {
      "type": "function",
      "stateMutability": "nonpayable",
      "payable": false,
      "outputs": [],
      "name": "set",
      "inputs": [
        {
          "type": "uint256",
          "name": "x"
        }
      ],
      "constant": false
    },
    {
      "type": "function",
      "stateMutability": "view",
      "payable": false,
      "outputs": [
        {
          "type": "uint256",
          "name": ""
        }
      ],
      "name": "get",
      "inputs": [],
      "constant": true
    }
  ]
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrrStI6lmvsAABih
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "errors": {
    "name": [
      "Max 15 ABIs per account"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-custom_abis></a>custom_abis
#### Get custom abis list

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/custom_abis
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOTM3NzM1ODktNTIxNy00NzU2LWIxMDEtMzQ1MTMzNTQzNDIzIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.xqRYJBXibGbwOGWKwLpgu_ZPOYqGHAuLngsXzuv_rm7YaxWqVfpWiUNgCz-Wa7FmwtufXQQ9MbIyeTurzCrxtw
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrrhcQSlmvsAABjB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "name": "test10",
    "id": 115,
    "contract_address_hash": "0x0000000000000000000000000000000000000021",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test11",
    "id": 116,
    "contract_address_hash": "0x0000000000000000000000000000000000000022",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test12",
    "id": 117,
    "contract_address_hash": "0x0000000000000000000000000000000000000023",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test13",
    "id": 118,
    "contract_address_hash": "0x0000000000000000000000000000000000000024",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test14",
    "id": 119,
    "contract_address_hash": "0x0000000000000000000000000000000000000025",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test15",
    "id": 120,
    "contract_address_hash": "0x0000000000000000000000000000000000000026",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test16",
    "id": 121,
    "contract_address_hash": "0x0000000000000000000000000000000000000027",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test17",
    "id": 122,
    "contract_address_hash": "0x0000000000000000000000000000000000000028",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test18",
    "id": 123,
    "contract_address_hash": "0x0000000000000000000000000000000000000029",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test19",
    "id": 124,
    "contract_address_hash": "0x000000000000000000000000000000000000002a",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test20",
    "id": 125,
    "contract_address_hash": "0x000000000000000000000000000000000000002b",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test21",
    "id": 126,
    "contract_address_hash": "0x000000000000000000000000000000000000002c",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test22",
    "id": 127,
    "contract_address_hash": "0x000000000000000000000000000000000000002d",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test23",
    "id": 128,
    "contract_address_hash": "0x000000000000000000000000000000000000002e",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  },
  {
    "name": "test24",
    "id": 129,
    "contract_address_hash": "0x000000000000000000000000000000000000002f",
    "abi": [
      {
        "type": "function",
        "stateMutability": "nonpayable",
        "payable": false,
        "outputs": [],
        "name": "set",
        "inputs": [
          {
            "type": "uint256",
            "name": "x"
          }
        ],
        "constant": false
      },
      {
        "type": "function",
        "stateMutability": "view",
        "payable": false,
        "outputs": [
          {
            "type": "uint256",
            "name": ""
          }
        ],
        "name": "get",
        "inputs": [],
        "constant": true
      }
    ]
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_custom_abi></a>update_custom_abi
#### Edit custom abi

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/custom_abis/113
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYzRiYmVjYmYtZGFhMC00Y2ZkLWFkYWYtMWVmMjM1NWU0NmRmIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.TbQ1vfSLBn4SqF9b4r7qDEXDmILP9d5ksWAeV59ZjFubXH00jU_kuatAEHv0C1tIzu3H_991kZQwAnLHtiBo4A
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test2",
  "contract_address_hash": "0x000000000000000000000000000000000000000a",
  "abi": [
    {
      "type": "function",
      "stateMutability": "nonpayable",
      "payable": false,
      "outputs": [],
      "name": "set",
      "inputs": [
        {
          "type": "uint256",
          "name": "x"
        }
      ],
      "constant": false
    },
    {
      "type": "function",
      "stateMutability": "view",
      "payable": false,
      "outputs": [
        {
          "type": "uint256",
          "name": ""
        }
      ],
      "name": "get",
      "inputs": [],
      "constant": true
    }
  ]
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJrGw90vqUBIAABri
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "test2",
  "id": 113,
  "contract_address_hash": "0x000000000000000000000000000000000000000a",
  "abi": [
    {
      "type": "function",
      "stateMutability": "nonpayable",
      "payable": false,
      "outputs": [],
      "name": "set",
      "inputs": [
        {
          "type": "uint256",
          "name": "x"
        }
      ],
      "constant": false
    },
    {
      "type": "function",
      "stateMutability": "view",
      "payable": false,
      "outputs": [
        {
          "type": "uint256",
          "name": ""
        }
      ],
      "name": "get",
      "inputs": [],
      "constant": true
    }
  ]
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_custom_abi></a>delete_custom_abi
#### Delete custom abi

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/custom_abis/112
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NTkwNDY5MzgsImlhdCI6MTY1NjYyNzczOCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMTc5NGUyNzgtOTY4ZS00NWE1LTk4MWEtNDkxM2YxZDBmZGNiIiwibmJmIjoxNjU2NjI3NzM3LCJzdWIiOiJibG9ja3Njb3V0fDAwMDAiLCJ0eXAiOiJhY2Nlc3MifQ.H026imc5Vl-TVTDQO5Splpyro1F92tN3WzbKv9pBmhrfFQ7uoIwXYkEpOG3YoqA5halY7qGJOoBy1YWJriadlA
```

##### Response
* __Status__: 200
* __Response headers:__
```
cache-control: max-age=0, private, must-revalidate
x-request-id: Fv2GJq2lPhwQF88AABfi
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json

```
