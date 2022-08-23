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

### <a id=blockscoutweb-account-api-v1-authcontroller-logout></a>logout
#### Logout

##### Request
* __Method:__ GET
* __Path:__ /auth/api/logout
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNjAzYjliYjctMjAzNS00ZTMwLWFmMDYtZjQzZjdhZGY4YTFjIiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE4IiwidHlwIjoiYWNjZXNzIn0.P4fttdoki0KFFU9WjeuV1ysYVcdOfjZHpupA5ljWyZfaTaGsNGXr8ENf7jZlKxLy6cSjbsL2k3ZAEv9FdJErmg
```

##### Response
* __Status__: 200
* __Response body:__
```
OK
```

## BlockScoutWeb.Account.Api.V1.UserController
### <a id=blockscoutweb-account-api-v1-usercontroller-info></a>info
#### Get info about user

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/info
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNjAzYjliYjctMjAzNS00ZTMwLWFmMDYtZjQzZjdhZGY4YTFjIiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE4IiwidHlwIjoiYWNjZXNzIn0.P4fttdoki0KFFU9WjeuV1ysYVcdOfjZHpupA5ljWyZfaTaGsNGXr8ENf7jZlKxLy6cSjbsL2k3ZAEv9FdJErmg
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjVVLIQxzQ0AAAjk
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "nickname": "test_user18",
  "name": "User Test18",
  "email": "test_user-29@blockscout.com",
  "avatar": "https://example.com/avatar/test_user18"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_tag_address></a>create_tag_address
#### Add private address tag

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjYwY2U1NjUtNmJkYy00YTUzLWFmNTUtNDgzNTAzYmE2ZTliIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDExIiwidHlwIjoiYWNjZXNzIn0.g3dZzR7VoucLcnWZe8_Ww-w3BaxGOMpyOYZBgyoP5y9uHd_zWvFzvmvo-3uD10Hmuy3Z48jcxZypO0CTACQ3tg
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
x-request-id: FwuQpim7VYsHFF0AABlD
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "MyName",
  "id": 191,
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYjYwY2U1NjUtNmJkYy00YTUzLWFmNTUtNDgzNTAzYmE2ZTliIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDExIiwidHlwIjoiYWNjZXNzIn0.g3dZzR7VoucLcnWZe8_Ww-w3BaxGOMpyOYZBgyoP5y9uHd_zWvFzvmvo-3uD10Hmuy3Z48jcxZypO0CTACQ3tg
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpioOkSkHFF0AAAVh
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
* __Path:__ /api/account/v1/user/tags/address/195
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNDVhMTIzNDItOTEzYS00NWNiLWIzMjktMzY3MTRiMTQwODE3IiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE0IiwidHlwIjoiYWNjZXNzIn0.p-9LA2uAMy1UKcax83biqshChsDVZBCADgNy677IorSszZ98-tlIQ2ACKao0gR_uhVNZu-wqAxgPJcg22iQpuQ
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "name3",
  "address_hash": "0x0000000000000000000000000000000000000071"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjEYwtEDCiMAAAXB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "name3",
  "id": 195,
  "address_hash": "0x0000000000000000000000000000000000000071"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-tags_address></a>tags_address
#### Get private addresses tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/address
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZGMyN2RkZjItZTRkMi00ZWEzLWFkZWYtMDIyYjMwY2QxMzUzIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDAiLCJ0eXAiOiJhY2Nlc3MifQ.wWzQx7QIkq0slxN9T67pycERqba5-0KKTxcSjKEy5q4Fi1zNDAYrdQ4UZVXvzU63ec9Y1MMxzLCaOlZ2p8ci4A
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQphwzPKDHPBMAAA8j
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "name": "name2",
    "id": 190,
    "address_hash": "0x0000000000000000000000000000000000000003"
  },
  {
    "name": "name1",
    "id": 189,
    "address_hash": "0x0000000000000000000000000000000000000002"
  },
  {
    "name": "name0",
    "id": 188,
    "address_hash": "0x0000000000000000000000000000000000000001"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_tag_address></a>delete_tag_address
#### Delete private address tag

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/tags/address/192
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNTBiZjNmY2QtYTdiNi00ZjVmLTg2MTktOWIwZGVmMzY5MGE2IiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDEzIiwidHlwIjoiYWNjZXNzIn0.CJ4QnRrUvkbrO36NOPAqiyZj09iPA6yma7U2P4P8aBlLxWy3bAZUl-3ZKLJmu5gSrCFdPlEDAcDR4o2s3SVyHw
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpi-vPnoAeg4AAAYC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODg4ZTUwZjItNzJjYi00OWYzLWI2YTItNjViMTYzNWZkZjY3IiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.PwpzZUToKUFzfEHeDBubhp_HD5funsu5wrP6fMZXieRItYK9LewGXk7v_D-Iqd2UxQSgmMaqpxRk_-c8RwjHEQ
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000002",
  "name": "MyName"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpiSlZ8MFRCAAAAPi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODg4ZTUwZjItNzJjYi00OWYzLWI2YTItNjViMTYzNWZkZjY3IiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.PwpzZUToKUFzfEHeDBubhp_HD5funsu5wrP6fMZXieRItYK9LewGXk7v_D-Iqd2UxQSgmMaqpxRk_-c8RwjHEQ
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000003",
  "name": "MyName"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpiTYW2IFRCAAABeD
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000003",
  "name": "MyName",
  "id": 215
}
```

## BlockScoutWeb.Account.Api.V1.TagsController
### <a id=blockscoutweb-account-api-v1-tagscontroller-tags_transaction></a>tags_transaction
#### Get tags for transaction

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/tags/transaction/0x0000000000000000000000000000000000000000000000000000000000000003
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODg4ZTUwZjItNzJjYi00OWYzLWI2YTItNjViMTYzNWZkZjY3IiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDgiLCJ0eXAiOiJhY2Nlc3MifQ.PwpzZUToKUFzfEHeDBubhp_HD5funsu5wrP6fMZXieRItYK9LewGXk7v_D-Iqd2UxQSgmMaqpxRk_-c8RwjHEQ
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpiTucn4FRCAAAAQC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
* __Path:__ /api/account/v1/user/tags/transaction/213
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOThjZGVlYjgtMGI3Yy00M2U2LWI3ZDAtODAzYjAyZmNkZTlmIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDMiLCJ0eXAiOiJhY2Nlc3MifQ.wx0GAbtOBVhAcDksePh2srpuYZV0YEKWJzbcWXXzO_zNck0lHLu_AUQ9pJMeLADfsHD5BBtypA8eRYcAPIANeg
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
  "name": "name1"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQph4dlZl_aCMAABFD
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000001",
  "name": "name1",
  "id": 213
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-tags_transaction></a>tags_transaction
#### Get private transactions tags

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/tags/transaction
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNmY3YTU5MTctZTkzZS00ZDIwLWJkMjItYzZkZmI1MjcxMGI4IiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE3IiwidHlwIjoiYWNjZXNzIn0.EwNpusuNiETjPyX99BCG7kFVw1ILO2h5ma3-F6rXbC1C_r4YtIRH3dX8OxxzoGzVkzdT9ycO8N6QywNV2oKRvg
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjT3AhI31PUAAAhi
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000009",
    "name": "name2",
    "id": 221
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000008",
    "name": "name1",
    "id": 220
  },
  {
    "transaction_hash": "0x0000000000000000000000000000000000000000000000000000000000000007",
    "name": "name0",
    "id": 219
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_tag_transaction></a>delete_tag_transaction
#### Delete private transaction tag

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/tags/transaction/216
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiN2JmNmY2NTAtNDFlOS00NzU1LThkM2UtNDYyNTgzMWE0ODAwIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEyIiwidHlwIjoiYWNjZXNzIn0.OApbGu0VIJAb92sk2z5uRryqJfNQUgTZMNYPg3l-fAqFC5Q8Ozf7fzvi7D6UOZYYH_kV7KOplbYSf_f6d6EHww
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpiy51yHVod4AABpD
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "message": "OK"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-create_watchlist></a>create_watchlist
#### Add address to watch list

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/watchlist
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMDkzN2VjYjMtN2NiYi00MGE3LThiMTUtOTI1NGI2NDBlMzA2IiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIxIiwidHlwIjoiYWNjZXNzIn0.T2XfV2XJ74KVI_ILXC37uTQZi1WlIQfr60fQd7aX1eC-in8ZW2cO0yBSnTMb8vliqVnvq3ChI4XRZoza0CEpnw
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
  "name": "test22",
  "address_hash": "0x000000000000000000000000000000000000007d"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjb3H08IRYYAAApk
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
  "name": "test22",
  "id": 218,
  "exchange_rate": null,
  "address_hash": "0x000000000000000000000000000000000000007d",
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMDkzN2VjYjMtN2NiYi00MGE3LThiMTUtOTI1NGI2NDBlMzA2IiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIxIiwidHlwIjoiYWNjZXNzIn0.T2XfV2XJ74KVI_ILXC37uTQZi1WlIQfr60fQd7aX1eC-in8ZW2cO0yBSnTMb8vliqVnvq3ChI4XRZoza0CEpnw
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjfSdyoIRYYAAArk
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
      "email": true
    },
    "name": "test23",
    "id": 219,
    "exchange_rate": null,
    "address_hash": "0x000000000000000000000000000000000000007e",
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
        "outcoming": true,
        "incoming": true
      }
    },
    "notification_methods": {
      "email": false
    },
    "name": "test22",
    "id": 218,
    "exchange_rate": null,
    "address_hash": "0x000000000000000000000000000000000000007d",
    "address_balance": null
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_watchlist></a>delete_watchlist
#### Delete address from watchlist by id

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/watchlist/222
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMjE2YTNmZDktYmZmOS00MDc1LTgwMGMtMzIzMGViY2NkNTQyIiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDI0IiwidHlwIjoiYWNjZXNzIn0.owHZYYTtUZ117ErpxW3xW-qqmfeWCVlli5JbAL1GbRpAKBxsLJ56tcjTv7pbKIq4cM-PzC2bbrw5JuISHhdfOQ
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjtUa8rUTWIAAAlB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
* __Path:__ /api/account/v1/user/watchlist/220
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiNDE0OWJiNzktZDFlZi00NTIyLThmYTMtMTFmODZmMzBkYmE4IiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIyIiwidHlwIjoiYWNjZXNzIn0.yZjVfTRrQ3nuv0eU19VW5swMPO75WdiWZPW2EVrZLcEyXUP0X8oenB-A1haYT_0kMu40K7JZS7XMnR6Fo4wlkA
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": true,
      "incoming": false
    },
    "ERC-721": {
      "outcoming": true,
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
  "name": "test25",
  "address_hash": "0x0000000000000000000000000000000000000080"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjkDIU6MdJQAAAki
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "notification_settings": {
    "native": {
      "outcoming": true,
      "incoming": false
    },
    "ERC-721": {
      "outcoming": true,
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
  "name": "test25",
  "id": 220,
  "exchange_rate": null,
  "address_hash": "0x0000000000000000000000000000000000000080",
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZTNiNjE0MDEtZjJlOS00YzVlLTllODMtMzdmNWZkNjJhZDIyIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.jgzonm_tqZGmwcImaz114SJkaEVFR-4sjENu3OyUTbjfnxokTHyth6GxgKgyWuakTv0QmwlWLkvI27f6LIcvWA
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
      "outcoming": false,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": false
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test0",
  "address_hash": "0x0000000000000000000000000000000000000008"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQph-LHUg_AFwAABND
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "errors": {
    "watchlist_id": [
      "Address already added to the watch list"
    ]
  }
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_watchlist></a>update_watchlist
#### Example of error on editing watchlist address

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/watchlist/217
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZTNiNjE0MDEtZjJlOS00YzVlLTllODMtMzdmNWZkNjJhZDIyIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDUiLCJ0eXAiOiJhY2Nlc3MifQ.jgzonm_tqZGmwcImaz114SJkaEVFR-4sjENu3OyUTbjfnxokTHyth6GxgKgyWuakTv0QmwlWLkvI27f6LIcvWA
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
      "outcoming": false,
      "incoming": true
    },
    "ERC-20": {
      "outcoming": true,
      "incoming": false
    }
  },
  "notification_methods": {
    "email": false
  },
  "name": "test0",
  "address_hash": "0x0000000000000000000000000000000000000008"
}
```

##### Response
* __Status__: 422
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQph_yy5k_AFwAABOD
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "errors": {
    "watchlist_id": [
      "Address already added to the watch list"
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMjM1ZWI1MzEtY2U1My00MGY5LWIwZmEtZDE3NTc3NDA4OWI5IiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEiLCJ0eXAiOiJhY2Nlc3MifQ.v1lMn6bUzn8hrFFv6sDR0xioMWiqDt5q5SluJ8p3jAEdEA18ZAXsOLH6-vDNWr50GhObEB6KoSOX8wmbvTtuOg
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
x-request-id: FwuQphyX8rDQD4QAAATB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "test",
  "api_key": "b8c07804-e992-4de4-ae29-f0d6a6691d12"
}
```

#### Example of error on creating api key

##### Request
* __Method:__ POST
* __Path:__ /api/account/v1/user/api_keys
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOWMxYmQ2ZTEtYWZjMi00ODk3LTgwNDktYWE1YWQ4Mjc5MzljIiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE5IiwidHlwIjoiYWNjZXNzIn0.NQGehmwQo4_-iivPSEspKQ4mFxkg8RskxjxkBCc_D7FulNFu3dUA2Qg8sLxCK3Oqxu57WO8HpI2qIeBw3H1HWA
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
x-request-id: FwuQpjYLyBOZMSkAAAiC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiOWMxYmQ2ZTEtYWZjMi00ODk3LTgwNDktYWE1YWQ4Mjc5MzljIiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE5IiwidHlwIjoiYWNjZXNzIn0.NQGehmwQo4_-iivPSEspKQ4mFxkg8RskxjxkBCc_D7FulNFu3dUA2Qg8sLxCK3Oqxu57WO8HpI2qIeBw3H1HWA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjY6CbWZMSkAAAgB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "name": "test",
    "api_key": "4b8a9016-f6c7-4cf4-8697-5fb1851e16ec"
  },
  {
    "name": "test",
    "api_key": "0f16c464-b857-41c1-894d-233110158756"
  },
  {
    "name": "test",
    "api_key": "12cd8bf6-508a-4311-98d7-09ffa6ee043d"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-update_api_key></a>update_api_key
#### Edit api key

##### Request
* __Method:__ PUT
* __Path:__ /api/account/v1/user/api_keys/f46581bc-cc15-4482-8038-dab72c0e4405
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYTFjZGU3ZjEtMzA4My00ZTQ5LWFmNzEtYmU1YmRiOGNlYjFiIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDIiLCJ0eXAiOiJhY2Nlc3MifQ.1QQjWUyhuw2yEHEk-vEI1NcWQpK0BO3uFQPmLCaMhTuzEsg-HIztelraJIB7FSAN70Bt_FzKUN40TjoNvAQGDQ
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
x-request-id: FwuQph0kB14mvRQAAA_D
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "test_1",
  "api_key": "f46581bc-cc15-4482-8038-dab72c0e4405"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_api_key></a>delete_api_key
#### Delete api key

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/api_keys/50804f9d-d929-4017-a8e0-380facf88d42
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMjE1NThjZTgtNmE5NC00ODQyLThmZmEtMDNmYzI3MzY1MDgyIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDQiLCJ0eXAiOiJhY2Nlc3MifQ.YowVxGq8eb3dX2UK_7Dxl_Lg9T3HeoTEvOkHvgq520H4NYo-6oU8vfFbUMUkLr3jTfWDJgGidhnOfud44JM2vA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQph6_OaQNBRoAAAOC
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiODQzZjg1ODEtMmU3Zi00YzQyLTkxMTAtMzFkNjAwNWFiZDdkIiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE2IiwidHlwIjoiYWNjZXNzIn0.IQC9TAYZyygTEv-g4AilY6tpZmGUCCAyIQfj4tCdmnrHfajzkpnbO3lctA-3oiRlnNB71ZG3te7JWcfvc7ro0w
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test21",
  "contract_address_hash": "0x0000000000000000000000000000000000000074",
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
x-request-id: FwuQpjIzQYD_0WMAABxj
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "test21",
  "id": 468,
  "contract_address_hash": "0x0000000000000000000000000000000000000074",
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYzdmN2NmOWQtMjEzYi00OGVhLWJlOTEtNWQ2YTI0Yjc1NTdlIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.lZboWExo17mBNR-sGWkbyyZhjLEI7-7GBLwZqI22LT9kIPa3sXXhkUZNfjlhlotS2l_AlXxTpVNZkhDZ_XxdZg
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test17",
  "contract_address_hash": "0x0000000000000000000000000000000000000065",
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
x-request-id: FwuQpiiglpJ_3TEAAAZk
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYzdmN2NmOWQtMjEzYi00OGVhLWJlOTEtNWQ2YTI0Yjc1NTdlIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDkiLCJ0eXAiOiJhY2Nlc3MifQ.lZboWExo17mBNR-sGWkbyyZhjLEI7-7GBLwZqI22LT9kIPa3sXXhkUZNfjlhlotS2l_AlXxTpVNZkhDZ_XxdZg
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpii331h_3TEAAAaE
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "name": "test16",
    "id": 465,
    "contract_address_hash": "0x0000000000000000000000000000000000000064",
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
    "id": 464,
    "contract_address_hash": "0x0000000000000000000000000000000000000063",
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
    "id": 463,
    "contract_address_hash": "0x0000000000000000000000000000000000000062",
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
    "id": 462,
    "contract_address_hash": "0x0000000000000000000000000000000000000061",
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
    "id": 461,
    "contract_address_hash": "0x0000000000000000000000000000000000000060",
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
    "id": 460,
    "contract_address_hash": "0x000000000000000000000000000000000000005f",
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
    "id": 459,
    "contract_address_hash": "0x000000000000000000000000000000000000005e",
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
    "id": 458,
    "contract_address_hash": "0x000000000000000000000000000000000000005d",
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
    "id": 457,
    "contract_address_hash": "0x000000000000000000000000000000000000005c",
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
    "id": 456,
    "contract_address_hash": "0x000000000000000000000000000000000000005b",
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
    "id": 455,
    "contract_address_hash": "0x000000000000000000000000000000000000005a",
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
    "id": 454,
    "contract_address_hash": "0x0000000000000000000000000000000000000059",
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
    "id": 453,
    "contract_address_hash": "0x0000000000000000000000000000000000000058",
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
    "id": 452,
    "contract_address_hash": "0x0000000000000000000000000000000000000057",
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
    "id": 451,
    "contract_address_hash": "0x0000000000000000000000000000000000000056",
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
* __Path:__ /api/account/v1/user/custom_abis/467
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiZDU2YTY5NzYtY2U4NS00OWQ2LWI2YTgtNzY1OTUzMDkxMGU5IiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDE1IiwidHlwIjoiYWNjZXNzIn0.VeRQl9FN6i2NxfT_x0-E8YPGo8gDxDmGEHfjmLPJAa0-s8vRykPNq5C8loESJAFowi0MCIeHottQvR94oK-TVg
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "name": "test20",
  "contract_address_hash": "0x0000000000000000000000000000000000000073",
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
x-request-id: FwuQpjG3_3dYelIAABwD
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "name": "test20",
  "id": 467,
  "contract_address_hash": "0x0000000000000000000000000000000000000073",
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
* __Path:__ /api/account/v1/user/custom_abis/466
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMzE2ZjNhNjAtZTQzYi00MzE1LWE0NzUtY2NlY2VkZTZmYWY4IiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDEwIiwidHlwIjoiYWNjZXNzIn0.sMNyE8SSLXLL9f1Jx6xUfxeuYNDjbOCdoUwmlB1fcEKOrELZGUU_sHnDKKyaL5y1wYyd5PNC0NJ7E1gEPtWUrA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpilcg3W_YHIAAAbk
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMGEzZDI5ZjMtY2UxOS00Y2U5LWEyMTMtMjlhMDA4MGYzMDJkIiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDciLCJ0eXAiOiJhY2Nlc3MifQ._znDLvjrXnb4b2J74_RA2olgq8Zj_eWYKq1J3W3ZkdJksaF0fmJnJ_K35vzAsd4mShDGkRUnJbWveyo-R5egXA
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "website": "website10",
  "tags": "Tag11",
  "is_owner": true,
  "full_name": "full name10",
  "email": "test_user-18@blockscout.com",
  "company": "company10",
  "addresses": [
    "0x0000000000000000000000000000000000000051"
  ],
  "additional_comment": "additional_comment10"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpiPkYbM3wm8AAAXk
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "website": "website10",
  "tags": "Tag11",
  "is_owner": true,
  "id": 192,
  "full_name": "full name10",
  "email": "test_user-18@blockscout.com",
  "company": "company10",
  "addresses": [
    "0x0000000000000000000000000000000000000051"
  ],
  "additional_comment": "additional_comment10"
}
```

### <a id=blockscoutweb-account-api-v1-usercontroller-public_tags_requests></a>public_tags_requests
#### Get list of requests to add a public tag

##### Request
* __Method:__ GET
* __Path:__ /api/account/v1/user/public_tags
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYTJkNGIxNjAtZTNiMC00ZDZhLWI0NWUtNTEyYmI0OTZkZWQ4IiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.ZBfbt5qBLc1tVkZvatWlCqdiPgZ3nXF23O5hfGvFdj47rHB2ej7gbg6MKLDOLHBAdt7qIqaKGPnQWj1VerQDcA
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpiJB0_ZrrjAAABTD
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
[
  {
    "website": "website9",
    "tags": "Tag10",
    "is_owner": false,
    "id": 191,
    "full_name": "full name9",
    "email": "test_user-16@blockscout.com",
    "company": "company9",
    "addresses": [
      "0x0000000000000000000000000000000000000048",
      "0x0000000000000000000000000000000000000049",
      "0x000000000000000000000000000000000000004a",
      "0x000000000000000000000000000000000000004b",
      "0x000000000000000000000000000000000000004c",
      "0x000000000000000000000000000000000000004d",
      "0x000000000000000000000000000000000000004e",
      "0x000000000000000000000000000000000000004f",
      "0x0000000000000000000000000000000000000050"
    ],
    "additional_comment": "additional_comment9"
  },
  {
    "website": "website8",
    "tags": "Tag9",
    "is_owner": true,
    "id": 190,
    "full_name": "full name8",
    "email": "test_user-15@blockscout.com",
    "company": "company8",
    "addresses": [
      "0x000000000000000000000000000000000000003f",
      "0x0000000000000000000000000000000000000040",
      "0x0000000000000000000000000000000000000041",
      "0x0000000000000000000000000000000000000042",
      "0x0000000000000000000000000000000000000043",
      "0x0000000000000000000000000000000000000044",
      "0x0000000000000000000000000000000000000045",
      "0x0000000000000000000000000000000000000046",
      "0x0000000000000000000000000000000000000047"
    ],
    "additional_comment": "additional_comment8"
  },
  {
    "website": "website7",
    "tags": "Tag7;Tag8",
    "is_owner": true,
    "id": 189,
    "full_name": "full name7",
    "email": "test_user-14@blockscout.com",
    "company": "company7",
    "addresses": [
      "0x0000000000000000000000000000000000000035",
      "0x0000000000000000000000000000000000000036",
      "0x0000000000000000000000000000000000000037",
      "0x0000000000000000000000000000000000000038",
      "0x0000000000000000000000000000000000000039",
      "0x000000000000000000000000000000000000003a",
      "0x000000000000000000000000000000000000003b",
      "0x000000000000000000000000000000000000003c",
      "0x000000000000000000000000000000000000003d",
      "0x000000000000000000000000000000000000003e"
    ],
    "additional_comment": "additional_comment7"
  },
  {
    "website": "website6",
    "tags": "Tag6",
    "is_owner": true,
    "id": 188,
    "full_name": "full name6",
    "email": "test_user-13@blockscout.com",
    "company": "company6",
    "addresses": [
      "0x000000000000000000000000000000000000002f",
      "0x0000000000000000000000000000000000000030",
      "0x0000000000000000000000000000000000000031",
      "0x0000000000000000000000000000000000000032",
      "0x0000000000000000000000000000000000000033",
      "0x0000000000000000000000000000000000000034"
    ],
    "additional_comment": "additional_comment6"
  },
  {
    "website": "website5",
    "tags": "Tag5",
    "is_owner": true,
    "id": 187,
    "full_name": "full name5",
    "email": "test_user-12@blockscout.com",
    "company": "company5",
    "addresses": [
      "0x0000000000000000000000000000000000000028",
      "0x0000000000000000000000000000000000000029",
      "0x000000000000000000000000000000000000002a",
      "0x000000000000000000000000000000000000002b",
      "0x000000000000000000000000000000000000002c",
      "0x000000000000000000000000000000000000002d",
      "0x000000000000000000000000000000000000002e"
    ],
    "additional_comment": "additional_comment5"
  },
  {
    "website": "website4",
    "tags": "Tag4",
    "is_owner": false,
    "id": 186,
    "full_name": "full name4",
    "email": "test_user-11@blockscout.com",
    "company": "company4",
    "addresses": [
      "0x0000000000000000000000000000000000000022",
      "0x0000000000000000000000000000000000000023",
      "0x0000000000000000000000000000000000000024",
      "0x0000000000000000000000000000000000000025",
      "0x0000000000000000000000000000000000000026",
      "0x0000000000000000000000000000000000000027"
    ],
    "additional_comment": "additional_comment4"
  },
  {
    "website": "website3",
    "tags": "Tag3",
    "is_owner": false,
    "id": 185,
    "full_name": "full name3",
    "email": "test_user-10@blockscout.com",
    "company": "company3",
    "addresses": [
      "0x000000000000000000000000000000000000001b",
      "0x000000000000000000000000000000000000001c",
      "0x000000000000000000000000000000000000001d",
      "0x000000000000000000000000000000000000001e",
      "0x000000000000000000000000000000000000001f",
      "0x0000000000000000000000000000000000000020",
      "0x0000000000000000000000000000000000000021"
    ],
    "additional_comment": "additional_comment3"
  },
  {
    "website": "website2",
    "tags": "Tag2",
    "is_owner": true,
    "id": 184,
    "full_name": "full name2",
    "email": "test_user-9@blockscout.com",
    "company": "company2",
    "addresses": [
      "0x0000000000000000000000000000000000000016",
      "0x0000000000000000000000000000000000000017",
      "0x0000000000000000000000000000000000000018",
      "0x0000000000000000000000000000000000000019",
      "0x000000000000000000000000000000000000001a"
    ],
    "additional_comment": "additional_comment2"
  },
  {
    "website": "website1",
    "tags": "Tag1",
    "is_owner": false,
    "id": 183,
    "full_name": "full name1",
    "email": "test_user-8@blockscout.com",
    "company": "company1",
    "addresses": [
      "0x0000000000000000000000000000000000000010",
      "0x0000000000000000000000000000000000000011",
      "0x0000000000000000000000000000000000000012",
      "0x0000000000000000000000000000000000000013",
      "0x0000000000000000000000000000000000000014",
      "0x0000000000000000000000000000000000000015"
    ],
    "additional_comment": "additional_comment1"
  },
  {
    "website": "website0",
    "tags": "Tag0",
    "is_owner": true,
    "id": 182,
    "full_name": "full name0",
    "email": "test_user-7@blockscout.com",
    "company": "company0",
    "addresses": [
      "0x000000000000000000000000000000000000000a",
      "0x000000000000000000000000000000000000000b",
      "0x000000000000000000000000000000000000000c",
      "0x000000000000000000000000000000000000000d",
      "0x000000000000000000000000000000000000000e",
      "0x000000000000000000000000000000000000000f"
    ],
    "additional_comment": "additional_comment0"
  }
]
```

### <a id=blockscoutweb-account-api-v1-usercontroller-delete_public_tags_request></a>delete_public_tags_request
#### Delete public tags request

##### Request
* __Method:__ DELETE
* __Path:__ /api/account/v1/user/public_tags/191
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzAsImlhdCI6MTY2MDU3OTkzMCwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiYTJkNGIxNjAtZTNiMC00ZDZhLWI0NWUtNTEyYmI0OTZkZWQ4IiwibmJmIjoxNjYwNTc5OTI5LCJzdWIiOiJibG9ja3Njb3V0fDAwMDYiLCJ0eXAiOiJhY2Nlc3MifQ.ZBfbt5qBLc1tVkZvatWlCqdiPgZ3nXF23O5hfGvFdj47rHB2ej7gbg6MKLDOLHBAdt7qIqaKGPnQWj1VerQDcA
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
x-request-id: FwuQpiJiCRRrrjAAABUD
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
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
* __Path:__ /api/account/v1/user/public_tags/194
* __Request headers:__
```
authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJibG9ja19zY291dF93ZWIiLCJleHAiOjE2NjI5OTkxMzEsImlhdCI6MTY2MDU3OTkzMSwiaXNzIjoiYmxvY2tfc2NvdXRfd2ViIiwianRpIjoiMzMzOWViOWYtYTE3Ny00MzJlLWE3NjYtMTk4YzIwZjk2ZTMyIiwibmJmIjoxNjYwNTc5OTMwLCJzdWIiOiJibG9ja3Njb3V0fDAwMDIzIiwidHlwIjoiYWNjZXNzIn0.cv2NCc9KC-ad5u8hDlXeSL1EJpt3E_C1OvoENI_xkjBSnWqBL-M-KXSqqgo_42Od_cVKslI4XGtVeK3fk0eaOA
content-type: multipart/mixed; boundary=plug_conn_test
```
* __Request body:__
```json
{
  "website": "website13",
  "tags": "Tag14",
  "is_owner": false,
  "full_name": "full name13",
  "email": "test_user-37@blockscout.com",
  "company": "company13",
  "addresses": [
    "0x0000000000000000000000000000000000000082"
  ],
  "additional_comment": "additional_comment13"
}
```

##### Response
* __Status__: 200
* __Response headers:__
```
content-type: application/json; charset=utf-8
cache-control: max-age=0, private, must-revalidate
x-request-id: FwuQpjnaeEIPFzIAAAiB
access-control-allow-credentials: true
access-control-allow-origin: *
access-control-expose-headers: 
```
* __Response body:__
```json
{
  "website": "website13",
  "tags": "Tag14",
  "is_owner": false,
  "id": 194,
  "full_name": "full name13",
  "email": "test_user-37@blockscout.com",
  "company": "company13",
  "addresses": [
    "0x0000000000000000000000000000000000000082"
  ],
  "additional_comment": "additional_comment13"
}
```

