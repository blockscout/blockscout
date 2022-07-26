# API Documentation

  * [BlockScoutWeb.Account.Api.V1.UserController](#blockscoutweb-account-api-v1-usercontroller)
    * [info](#blockscoutweb-account-api-v1-usercontroller-info)
    * [create_tag_address](#blockscoutweb-account-api-v1-usercontroller-create_tag_address)
  * [BlockScoutWeb.Account.Api.V1.TagsController](#blockscoutweb-account-api-v1-tagscontroller)
    * [tags_address](#blockscoutweb-account-api-v1-tagscontroller-tags_address)
  * [BlockScoutWeb.Account.Api.V1.UserController](#blockscoutweb-account-api-v1-usercontroller)
    * [update_tag_address](#blockscoutweb-account-api-v1-usercontroller-update_tag_address)
    * [tags_address](#blockscoutweb-account-api-v1-usercontroller-tags_address)
    * [delete_tag_address](#blockscoutweb-account-api-v1-usercontroller-delete_tag_address)
    * [create_tag_transaction](#blockscoutweb-account-api-v1-usercontroller-create_tag_transaction)
  * [BlockScoutWeb.Account.Api.V1.TagsController](#blockscoutweb-account-api-v1-tagscontroller)
    * [tags_transaction](#blockscoutweb-account-api-v1-tagscontroller-tags_transaction)
  * [BlockScoutWeb.Account.Api.V1.UserController](#blockscoutweb-account-api-v1-usercontroller)
    * [update_tag_transaction](#blockscoutweb-account-api-v1-usercontroller-update_tag_transaction)
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
    * [create_public_tags_request](#blockscoutweb-account-api-v1-usercontroller-create_public_tags_request)
    * [public_tags_requests](#blockscoutweb-account-api-v1-usercontroller-public_tags_requests)
    * [delete_public_tags_request](#blockscoutweb-account-api-v1-usercontroller-delete_public_tags_request)
    * [update_public_tags_request](#blockscoutweb-account-api-v1-usercontroller-update_public_tags_request)
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZWNhMTBiMjAtOGNjMy00ZjQzLWFkMTYtZjk3YjM5NTg3NmUwIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEwIiwidHlwIjoiYWNjZXNzIn0.7H-cTTAH-o4SpgqoVFWAT_DwhqGISbgu24T-fivJ6I0nx9OafsNCxNhqK3WunhEV84QRtOir1QFusCbmXzD0hQ
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FD0vQMD5E60AAAei
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "nickname": "test_user10",
  "name": "User Test10",
  "email": "test_user-10@blockscout.com",
  "avatar": "https://example.com/avatar/test_user10"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_address></a>create_tag_address
#### Add private address tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTQ1YmJiOGQtMTg1Ni00NWRkLWJhMjgtODM1MzIwMWQ3YmE2IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.UXLszHWCt3aN_YuIA5PvweGxQASesXIXn-Htam-7ptXaTgCMxgecigOpYYopG7IFJBKfg61ypzjgKwd5OiXr4A
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
x-request-id: FwX9FEAXw_eXFKIAACPh
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "MyName",
  "id": 123,
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTQ1YmJiOGQtMTg1Ni00NWRkLWJhMjgtODM1MzIwMWQ3YmE2IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.UXLszHWCt3aN_YuIA5PvweGxQASesXIXn-Htam-7ptXaTgCMxgecigOpYYopG7IFJBKfg61ypzjgKwd5OiXr4A
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEBJLwKXFKIAACQB
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
      "display_name": "MyName",
      "address_hash": "0x3e9ac8f16c92bc4f093357933b5befbf1e16987b"
    }
  ],
  "common_tags": []
}
```

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-update_tag_address></a>update_tag_address
#### Edit private address tag

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/tags/address/116
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDAsImlhdCI6MTY1OTAxMDMwMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNjk0ZjIyYjQtYTBkOS00MGNiLThlNTAtYTM2MzI1MDhhMzc4IiwibmJmIjoxNjU5MDEwMjk5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDAiLCJ0eXAiOiJhY2Nlc3MifQ.6_RT4rbm1vwbi9_eUtze3-ZN_EBbmdqycGyOVJ9AJ6PVvIzyRQFlWlRrvhq7YKiZt8ue2ljL8XJyqvBbGplQFQ
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "name1",
  "address_hash": "0x0000000000000000000000000000000000000002"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FC8B36iSrmsAAAHk
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "name1",
  "id": 116,
  "address_hash": "0x0000000000000000000000000000000000000002"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-tags_address></a>tags_address
#### Get private addresses tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNzdiYTcxNWEtNDI1OS00ODAxLWIxOTktZDgwNDM2MWUwNmU1IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.NC-jt9HzTIfusCKVF43c-3aNHfKReziLQIzpICuuBNnqUj6em1VaMnwLttW8FSYxLwxfcF6U9wbx-EhtE7K0pA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FDtkAYijgTYAACDB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "name": "name0",
    "id": 120,
    "address_hash": "0x0000000000000000000000000000000000000023"
  },
  {
    "name": "name1",
    "id": 121,
    "address_hash": "0x0000000000000000000000000000000000000024"
  },
  {
    "name": "name2",
    "id": 122,
    "address_hash": "0x0000000000000000000000000000000000000025"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_tag_address></a>delete_tag_address
#### Delete private address tag

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/tags/address/117
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDAsImlhdCI6MTY1OTAxMDMwMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjViNzE0ZmQtYWFhYS00N2NmLTk4YmUtYzk1MzBhZTA4YTk0IiwibmJmIjoxNjU5MDEwMjk5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIiLCJ0eXAiOiJhY2Nlc3MifQ.jJdgLf3d71x_VL-lP8eOjfewv71UjT4R7SBp_TFmRb_rxV0GeE37R1B-nDZKvoABHKODctz6kIaS6Koyizv9YQ
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FDJLG3NmonIAAB0B
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_transaction></a>create_tag_transaction
#### Error on try to create private transaction tag for tx does not exist

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOGI2MjFlYmYtZDY2OC00MWExLWI4YzMtOGUzZWQxZWIxZGU3IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.8oBFdtsSqTeo9zaHHQ8LKeVLnRZi5GFVxSuN_9OY6zlijPftT2qDSN5Qu6cLz5MCm8218caXVBA3MoOmjh81-Q
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
x-request-id: FwX9FDw_irSTUzMAAAdi
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOGI2MjFlYmYtZDY2OC00MWExLWI4YzMtOGUzZWQxZWIxZGU3IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.8oBFdtsSqTeo9zaHHQ8LKeVLnRZi5GFVxSuN_9OY6zlijPftT2qDSN5Qu6cLz5MCm8218caXVBA3MoOmjh81-Q
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
x-request-id: FwX9FDxm9yaTUzMAAAeC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
  "name": "MyName",
  "id": 133
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOGI2MjFlYmYtZDY2OC00MWExLWI4YzMtOGUzZWQxZWIxZGU3IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.8oBFdtsSqTeo9zaHHQ8LKeVLnRZi5GFVxSuN_9OY6zlijPftT2qDSN5Qu6cLz5MCm8218caXVBA3MoOmjh81-Q
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FDyRX0WTUzMAACDh
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
### <a id=blockscoutweb-account-api-v1-usercontroller-update_tag_transaction></a>update_tag_transaction
#### Edit private transaction tag

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/tags/transaction/140
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNWJlMjZkYWYtMzcxZi00MTA0LWEwMWItOTJiNjM0ZjA4ZDQxIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIxIiwidHlwIjoiYWNjZXNzIn0.5St_z_24WME_Eu7tpgziqcn1oXAIdJOGEeISmVS5bbYYDQqBRa49-v6Xm9h1fsjCSg8ZbJ4Vi3WEcn84ygCRzA
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
  "name": "name3"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEojjETdulQAAA2i
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
  "name": "name3",
  "id": 140
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-tags_transaction></a>tags_transaction
#### Get private transactions tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODZiOTVmZTMtZWYzMC00MWFiLWJkYWQtNDRjZmY0NmYwYTVmIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE5IiwidHlwIjoiYWNjZXNzIn0.SR5s3ma8zaDJjGJqwsJcRGz3iHUBtFz4TuzSJF1k9NL-4ri2XSAIPnidyvUWsmzPe0M6k4xfwgBaaloqDtIwCA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEkKMJngvGIAACpB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000005",
    "name": "name0",
    "id": 137
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000006",
    "name": "name1",
    "id": 138
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000007",
    "name": "name2",
    "id": 139
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_tag_transaction></a>delete_tag_transaction
#### Delete private transaction tag

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/tags/transaction/134
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYTNhZTBjNTMtNWIyNS00MzQ0LTlmZmYtOWE1MzYzMDkxNTFiIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE4IiwidHlwIjoiYWNjZXNzIn0.ma-cNPZuf0Y580wWcgawrYy_rtWp0MmMp4FZGh9jDsTLPIQCcKNOvWpEgU0GbxHs0Lqlv4hFiugwopwKwfaaPA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEaIlUw09lsAACgB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_watchlist></a>create_watchlist
#### Add address to watchlist

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/watchlist
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjVmMmEyZjMtYTNlMy00MWVjLWI0ZDItZjIwMmIzMzg3MmE5IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIyIiwidHlwIjoiYWNjZXNzIn0.AEALezStFrFEmQ8i9H6h9li-pbXKcb28NTNXW0bQC2YasdSAuCCVWythzzalZpKqY0Ta7OG7DQGNVGk0O026fw
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
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
      "outcoming": true,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test24",
  "address_hash": "0x0000000000000000000000000000000000000071"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEp38eayqccAACph
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
      "incoming": true
    },
    "ERC-721": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test24",
  "id": 133,
  "exchange_rate": null,
  "address_hash": "0x0000000000000000000000000000000000000071",
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjVmMmEyZjMtYTNlMy00MWVjLWI0ZDItZjIwMmIzMzg3MmE5IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIyIiwidHlwIjoiYWNjZXNzIn0.AEALezStFrFEmQ8i9H6h9li-pbXKcb28NTNXW0bQC2YasdSAuCCVWythzzalZpKqY0Ta7OG7DQGNVGk0O026fw
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEsbBUuyqccAACqh
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
        "incoming": true
      },
      "ERC-721": {
        "outcoming": false,
        "incoming": true
      },
      "ERC-20": {
        "outcoming": true,
        "incoming": true
      }
    },
    "notification_methods": {
      "email": false
    },
    "name": "test24",
    "id": 133,
    "exchange_rate": null,
    "address_hash": "0x0000000000000000000000000000000000000071",
    "address_balance": null
  },
  {
    "notification_settings": {
      "native": {
        "outcoming": true,
        "incoming": false
      },
      "ERC-721": {
        "outcoming": false,
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
    "name": "test25",
    "id": 134,
    "exchange_rate": null,
    "address_hash": "0x0000000000000000000000000000000000000072",
    "address_balance": null
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_watchlist></a>delete_watchlist
#### Delete address from watchlist by id

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/watchlist/136
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiY2YxNzVjOGUtMzIxYi00NGZkLWE1YTUtYTkzNjUxZDUxNGMyIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDI0IiwidHlwIjoiYWNjZXNzIn0.Kg9e3VxXE--Ufz_K8CB0oYL-q0fFC48refZlVkD2anbDbok9zmbTA-qYdhsZzDDB_t-gLxp4O_HgX7RQRR12Pw
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FE0fElhW-8kAACxB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_watchlist></a>update_watchlist
#### Edit watchlist address

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/watchlist/132
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMWUwZWM1ZmQtMTNmNS00NGQ3LWI1NzItOGE1ZmZmYjhmMDM4IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE3IiwidHlwIjoiYWNjZXNzIn0.3hV0DtJ1rkeEA3jAeSWVy-bUajntQWht-iPhd4HpIP474qK_fyigl3wvj76Fr30L42MF3jdFWVC0F0uUnISMbQ
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": false,
      "incoming": true
    },
    "ERC-721": {
      "outcoming": true,
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
  "name": "test23",
  "address_hash": "0x000000000000000000000000000000000000005b"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEQreO4tKUsAACdh
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
      "incoming": true
    },
    "ERC-721": {
      "outcoming": true,
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
  "name": "test23",
  "id": 132,
  "exchange_rate": null,
  "address_hash": "0x000000000000000000000000000000000000005b",
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiM2NmYmMwNWMtNTRjNS00NWMyLWFmMGYtNWZlMGU3ZTVkNTUyIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEzIiwidHlwIjoiYWNjZXNzIn0.YB49bcxmnQXIZLo8PQCa7TyCPJEe7bh2RIXowME3ScFbz6OOJ6UrEBjFtgClTNtKUAfNyLc4w0XJp2T254bacw
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
      "outcoming": true,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test20",
  "address_hash": "0x000000000000000000000000000000000000002a"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FD8_qd3GWf4AACLh
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
* __Path:__ /api/account/v1/user/watchlist/131
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiM2NmYmMwNWMtNTRjNS00NWMyLWFmMGYtNWZlMGU3ZTVkNTUyIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEzIiwidHlwIjoiYWNjZXNzIn0.YB49bcxmnQXIZLo8PQCa7TyCPJEe7bh2RIXowME3ScFbz6OOJ6UrEBjFtgClTNtKUAfNyLc4w0XJp2T254bacw
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
      "outcoming": true,
      "incoming": true
    }
  },
  "notification_methods": {
    "email": true
  },
  "name": "test20",
  "address_hash": "0x000000000000000000000000000000000000002a"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FD-je2nGWf4AACMh
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNDU3MmM2OGItNWIwNy00YzY3LThiMGEtNjZiZmVhZjBmYzkxIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE2IiwidHlwIjoiYWNjZXNzIn0.013s29QLhAI8xvvUV7YsFnh-lvXcgqoyD5PGITjaJjipyUv9gpa9BlzokCBP7gabCjNyFIJWEHvOfX-u4Ls-dg
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
x-request-id: FwX9FEM9W5OeXwUAAApC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "test",
  "api_key": "40e57889-7cbc-4a3e-b8a0-6da06b31fbba"
}
```

#### Example of error on creating api key

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/api_keys
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWVlZTYwNzUtYjAxMy00N2M4LWI0YjUtOWU2NThiZDM1Yzg2IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.zVdgxdzf0nTBtu1SVPJI88uWM_7582ezIbX1QSM3pD1bZ1LCB4G3DnCflb_c4KAsuL_6oC9CblVxEZXRN9Yt4Q
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
x-request-id: FwX9FD4o8SlcVs8AACJh
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWVlZTYwNzUtYjAxMy00N2M4LWI0YjUtOWU2NThiZDM1Yzg2IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.zVdgxdzf0nTBtu1SVPJI88uWM_7582ezIbX1QSM3pD1bZ1LCB4G3DnCflb_c4KAsuL_6oC9CblVxEZXRN9Yt4Q
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FD448ddcVs8AACKB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "name": "test",
    "api_key": "00df6506-4849-44e1-bace-1d5d3eb8fea3"
  },
  {
    "name": "test",
    "api_key": "2e44373a-f986-4ae7-95ae-162b34f7d90b"
  },
  {
    "name": "test",
    "api_key": "aab962c6-f43f-4b41-b5a9-2363ed03bbde"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_api_key></a>update_api_key
#### Edit api key

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/api_keys/f0ce17a9-9461-4219-8bcd-e27722425bbb
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDAsImlhdCI6MTY1OTAxMDMwMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZjY5MWY4YTEtMGM0Yi00MGVmLWFhMTMtMzEyMmZiMDA4NDQ3IiwibmJmIjoxNjU5MDEwMjk5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.kiuUCaTNIzeCCn5Rh4B4NavQCSeTHIHMSiFDIs5SIWtUMGZkNstH8fb-EJbS6uc6fXOpRaxVWDOOkCKyUL5GrQ
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
x-request-id: FwX9FC_XiBww_lsAABuB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "test_1",
  "api_key": "f0ce17a9-9461-4219-8bcd-e27722425bbb"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_api_key></a>delete_api_key
#### Delete api key

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/api_keys/84c0098b-a0e3-45a9-bbb8-011d8027dcf0
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZmRlODcyNDMtZWRmOC00NjIxLThkYWItZjkyN2I5MmY0MGQ5IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDExIiwidHlwIjoiYWNjZXNzIn0.ZjCdVNzT9iCU_Sb6Wi5oKo6Hn7LSEI3lANq68nXTn7v489OgqdAupEL_2eQLTy7HgZaQKqoCMhNJeAwYH_ZM9Q
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FD2U_S_pPTUAAAhC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_custom_abi></a>create_custom_abi
#### Add custom abi

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/custom_abis
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDAsImlhdCI6MTY1OTAxMDMwMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTk4YjIzMWMtYzE2MS00YzAwLWE5ZDktYTU2NDcwNzBmODM1IiwibmJmIjoxNjU5MDEwMjk5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDMiLCJ0eXAiOiJhY2Nlc3MifQ.Xu99bTKlKhnG8SOgyFVRsM8HNrxCPZTQkQgSEeBnxGh9Y4k-bKMygbQ86ZYOOSvxLUVPReceMwaYJFq2untC1Q
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test0",
  "contract_address_hash": "0x0000000000000000000000000000000000000006",
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
x-request-id: FwX9FDOKezeB5iEAAB4B
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "test0",
  "id": 289,
  "contract_address_hash": "0x0000000000000000000000000000000000000006",
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDAsImlhdCI6MTY1OTAxMDMwMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWY4OWIzMmMtNWVlMy00ZTU0LThjOTMtZDNiMDk5MmJmMDRkIiwibmJmIjoxNjU5MDEwMjk5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.k2oQjv-o5qPSDdCT4idXEhI2oBEz6KiYy0pRPiQ0Ma77i2Z2Da3Xr8g2wb3W0vWbG65yvNnuywps4OXatgG2jA
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test16",
  "contract_address_hash": "0x0000000000000000000000000000000000000016",
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
x-request-id: FwX9FDcwa8LsvpkAAB8h
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDAsImlhdCI6MTY1OTAxMDMwMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYWY4OWIzMmMtNWVlMy00ZTU0LThjOTMtZDNiMDk5MmJmMDRkIiwibmJmIjoxNjU5MDEwMjk5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.k2oQjv-o5qPSDdCT4idXEhI2oBEz6KiYy0pRPiQ0Ma77i2Z2Da3Xr8g2wb3W0vWbG65yvNnuywps4OXatgG2jA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FDdCHYvsvpkAAB9B
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "name": "test1",
    "id": 290,
    "contract_address_hash": "0x0000000000000000000000000000000000000007",
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
    "name": "test2",
    "id": 291,
    "contract_address_hash": "0x0000000000000000000000000000000000000008",
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
    "name": "test3",
    "id": 292,
    "contract_address_hash": "0x0000000000000000000000000000000000000009",
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
    "name": "test4",
    "id": 293,
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
  },
  {
    "name": "test5",
    "id": 294,
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
  },
  {
    "name": "test6",
    "id": 295,
    "contract_address_hash": "0x000000000000000000000000000000000000000c",
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
    "name": "test7",
    "id": 296,
    "contract_address_hash": "0x000000000000000000000000000000000000000d",
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
    "name": "test8",
    "id": 297,
    "contract_address_hash": "0x000000000000000000000000000000000000000e",
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
    "name": "test9",
    "id": 298,
    "contract_address_hash": "0x000000000000000000000000000000000000000f",
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
    "name": "test10",
    "id": 299,
    "contract_address_hash": "0x0000000000000000000000000000000000000010",
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
    "id": 300,
    "contract_address_hash": "0x0000000000000000000000000000000000000011",
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
    "id": 301,
    "contract_address_hash": "0x0000000000000000000000000000000000000012",
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
    "id": 302,
    "contract_address_hash": "0x0000000000000000000000000000000000000013",
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
    "id": 303,
    "contract_address_hash": "0x0000000000000000000000000000000000000014",
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
    "id": 304,
    "contract_address_hash": "0x0000000000000000000000000000000000000015",
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
* __Path:__ /api/account/v1/user/custom_abis/305
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYzQ1YjRjYjMtMmUxYS00MTI2LThkMjgtMjE5OGM3MDg4MzNjIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.DNb34dNnY3Qs91NHvxtKVi_3wl9P8vPXyzFG6VTParQVzNhz4L7w4mJVcxl7dTpk4FqUMllokhM1NYM3fPFW5A
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test18",
  "contract_address_hash": "0x0000000000000000000000000000000000000018",
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
x-request-id: FwX9FDgXjDdlqPkAAB-h
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "name": "test18",
  "id": 305,
  "contract_address_hash": "0x0000000000000000000000000000000000000018",
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
* __Path:__ /api/account/v1/user/custom_abis/306
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTRhYTYxYjItOWRjYi00MWZhLTkwMDQtODJjZjE1MDQ0NmJhIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ.NSKNjPFqh3LLrRtBaliyxLCT37RsOnkW6Y__JyXlnZzH033xct94jFoB-BDuIrRGlsz4Infs9HIKTor3J1NbVw
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FDnES_sdOgkAAAXC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_public_tags_request></a>create_public_tags_request
#### Submit request to add a public tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/public_tags
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMzQ2MmFlNmItOWIwNS00NjkxLTgwNzktZjQ1MTUyZTc5ODEyIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIwIiwidHlwIjoiYWNjZXNzIn0.9mwp6vm2_RurBsJSU6puiu2qkMKbVZUMMuLzij9Js3wdoMa2YDk_Pm9ylP-7P6SakVeU9-wvf0XQu32IBrpLqQ
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "website": "website12",
  "tags": "Tag19;Tag20",
  "is_owner": false,
  "full_name": "full name12",
  "email": "email12",
  "company": "company12",
  "addresses_array": [
    "0x0000000000000000000000000000000000000068",
    "0x0000000000000000000000000000000000000069",
    "0x000000000000000000000000000000000000006a",
    "0x000000000000000000000000000000000000006b",
    "0x000000000000000000000000000000000000006c"
  ],
  "additional_comment": "additional_comment12"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEk6QUkAq20AAAzC
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "website": "website12",
  "tags": "Tag19;Tag20",
  "is_owner": false,
  "id": 95,
  "full_name": "full name12",
  "email": "email12",
  "company": "company12",
  "addresses": "0x0000000000000000000000000000000000000068;0x0000000000000000000000000000000000000069;0x000000000000000000000000000000000000006a;0x000000000000000000000000000000000000006b;0x000000000000000000000000000000000000006c",
  "additional_comment": "additional_comment12"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-public_tags_requests></a>public_tags_requests
#### Get list of requests to add a public tag

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/public_tags
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOGQyMTNmZjUtZjcwMi00MGY1LThlYTAtYmMwMmViNjdkOTgyIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.F3xDTfXJLm5BAoKT6KjUE56XPq-taA1R-KMYnf2p9uHgZ2ZcWbPZcJEmaaq8ejdB77t_AbqSothvP1AqrbnNWg
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEG1TdpTy1EAACXh
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
[
  {
    "website": "website2",
    "tags": "Tag2;Tag3",
    "is_owner": true,
    "id": 85,
    "full_name": "full name2",
    "email": "email2",
    "company": "company2",
    "addresses": "0x000000000000000000000000000000000000002c;0x000000000000000000000000000000000000002d;0x000000000000000000000000000000000000002e;0x000000000000000000000000000000000000002f;0x0000000000000000000000000000000000000030;0x0000000000000000000000000000000000000031;0x0000000000000000000000000000000000000032;0x0000000000000000000000000000000000000033",
    "additional_comment": "additional_comment2"
  },
  {
    "website": "website3",
    "tags": "Tag4;Tag5",
    "is_owner": true,
    "id": 86,
    "full_name": "full name3",
    "email": "email3",
    "company": "company3",
    "addresses": "0x0000000000000000000000000000000000000034;0x0000000000000000000000000000000000000035",
    "additional_comment": "additional_comment3"
  },
  {
    "website": "website4",
    "tags": "Tag6",
    "is_owner": true,
    "id": 87,
    "full_name": "full name4",
    "email": "email4",
    "company": "company4",
    "addresses": "0x0000000000000000000000000000000000000036;0x0000000000000000000000000000000000000037;0x0000000000000000000000000000000000000038;0x0000000000000000000000000000000000000039;0x000000000000000000000000000000000000003a",
    "additional_comment": "additional_comment4"
  },
  {
    "website": "website5",
    "tags": "Tag7;Tag8",
    "is_owner": true,
    "id": 88,
    "full_name": "full name5",
    "email": "email5",
    "company": "company5",
    "addresses": "0x000000000000000000000000000000000000003b;0x000000000000000000000000000000000000003c;0x000000000000000000000000000000000000003d",
    "additional_comment": "additional_comment5"
  },
  {
    "website": "website6",
    "tags": "Tag9;Tag10",
    "is_owner": false,
    "id": 89,
    "full_name": "full name6",
    "email": "email6",
    "company": "company6",
    "addresses": "0x000000000000000000000000000000000000003e;0x000000000000000000000000000000000000003f;0x0000000000000000000000000000000000000040;0x0000000000000000000000000000000000000041;0x0000000000000000000000000000000000000042;0x0000000000000000000000000000000000000043",
    "additional_comment": "additional_comment6"
  },
  {
    "website": "website7",
    "tags": "Tag11",
    "is_owner": false,
    "id": 90,
    "full_name": "full name7",
    "email": "email7",
    "company": "company7",
    "addresses": "0x0000000000000000000000000000000000000044;0x0000000000000000000000000000000000000045;0x0000000000000000000000000000000000000046;0x0000000000000000000000000000000000000047;0x0000000000000000000000000000000000000048;0x0000000000000000000000000000000000000049;0x000000000000000000000000000000000000004a;0x000000000000000000000000000000000000004b",
    "additional_comment": "additional_comment7"
  },
  {
    "website": "website8",
    "tags": "Tag12",
    "is_owner": true,
    "id": 91,
    "full_name": "full name8",
    "email": "email8",
    "company": "company8",
    "addresses": "0x000000000000000000000000000000000000004c",
    "additional_comment": "additional_comment8"
  },
  {
    "website": "website9",
    "tags": "Tag13;Tag14",
    "is_owner": false,
    "id": 92,
    "full_name": "full name9",
    "email": "email9",
    "company": "company9",
    "addresses": "0x000000000000000000000000000000000000004d;0x000000000000000000000000000000000000004e;0x000000000000000000000000000000000000004f",
    "additional_comment": "additional_comment9"
  },
  {
    "website": "website10",
    "tags": "Tag15;Tag16",
    "is_owner": true,
    "id": 93,
    "full_name": "full name10",
    "email": "email10",
    "company": "company10",
    "addresses": "0x0000000000000000000000000000000000000050;0x0000000000000000000000000000000000000051;0x0000000000000000000000000000000000000052",
    "additional_comment": "additional_comment10"
  },
  {
    "website": "website11",
    "tags": "Tag17;Tag18",
    "is_owner": false,
    "id": 94,
    "full_name": "full name11",
    "email": "email11",
    "company": "company11",
    "addresses": "0x0000000000000000000000000000000000000053;0x0000000000000000000000000000000000000054;0x0000000000000000000000000000000000000055;0x0000000000000000000000000000000000000056;0x0000000000000000000000000000000000000057;0x0000000000000000000000000000000000000058;0x0000000000000000000000000000000000000059",
    "additional_comment": "additional_comment11"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_public_tags_request></a>delete_public_tags_request
#### Delete public tags request

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/public_tags/85
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOGQyMTNmZjUtZjcwMi00MGY1LThlYTAtYmMwMmViNjdkOTgyIiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.F3xDTfXJLm5BAoKT6KjUE56XPq-taA1R-KMYnf2p9uHgZ2ZcWbPZcJEmaaq8ejdB77t_AbqSothvP1AqrbnNWg
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "remove_reason": "reason"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FEHJeHNTy1EAACYB
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_public_tags_request></a>update_public_tags_request
#### Edit request to add a public tag

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/public_tags/84
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjE0Mjk1MDEsImlhdCI6MTY1OTAxMDMwMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjM4MjljNTgtYzRjNC00NDQxLTlmNTYtZmY5YzJlZTU2MDE5IiwibmJmIjoxNjU5MDEwMzAwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.2MJrq9MRPksGIJK2Ol-chZMOy677EHr3Pr7bJ3lKtGbOD4iiV49dqO5KnH1o2sXw3HLH1SEtytYrcNYM_0kYYA
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "website": "website1",
  "tags": "Tag1",
  "is_owner": false,
  "full_name": "full name1",
  "email": "email1",
  "company": "company1",
  "addresses_array": [
    "0x000000000000000000000000000000000000001a",
    "0x000000000000000000000000000000000000001b",
    "0x000000000000000000000000000000000000001c",
    "0x000000000000000000000000000000000000001d",
    "0x000000000000000000000000000000000000001e",
    "0x000000000000000000000000000000000000001f",
    "0x0000000000000000000000000000000000000020",
    "0x0000000000000000000000000000000000000021"
  ],
  "additional_comment": "additional_comment1"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwX9FDjgyH50TAgAAASi
access-control-allow-origin: *
access-control-expose-headers: 
access-control-allow-credentials: true
```
* __Response body:__
```json
{
  "website": "website1",
  "tags": "Tag1",
  "is_owner": false,
  "id": 84,
  "full_name": "full name1",
  "email": "email1",
  "company": "company1",
  "addresses": "0x000000000000000000000000000000000000001a;0x000000000000000000000000000000000000001b;0x000000000000000000000000000000000000001c;0x000000000000000000000000000000000000001d;0x000000000000000000000000000000000000001e;0x000000000000000000000000000000000000001f;0x0000000000000000000000000000000000000020;0x0000000000000000000000000000000000000021",
  "additional_comment": "additional_comment1"
}
```

