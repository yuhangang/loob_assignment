# API Error Codes

All API errors use this response shape:

```json
{
  "error": "unsupported country",
  "error_code": "USR_UNSUPPORTED_COUNTRY",
  "trace_id": "tr_..."
}
```

`error` is user/developer-readable. `error_code` is the stable app contract. `trace_id` should be included in support logs and bug reports.

## API Fallback Codes

| Code | HTTP | Meaning |
| --- | ---: | --- |
| `API_BAD_REQUEST` | 400 | Request was malformed or failed validation. |
| `API_UNAUTHORIZED` | 401 | Authentication is missing or invalid. |
| `API_FORBIDDEN` | 403 | Authenticated user cannot access the resource. |
| `API_NOT_FOUND` | 404 | Resource was not found. |
| `API_CONFLICT` | 409 | Request conflicts with current resource state. |
| `API_UNPROCESSABLE` | 422 | Request is syntactically valid but cannot be applied. |
| `API_REQUEST_TOO_LARGE` | 413 | Request payload is too large. |
| `API_RATE_LIMITED` | 429 | Client is sending too many requests. |
| `API_INTERNAL_ERROR` | 500 | Unexpected server failure. |

## Module Codes

| Module | Code | HTTP | Meaning |
| --- | --- | ---: | --- |
| Auth | `API_UNAUTHORIZED` | 401 | Missing or invalid bearer token. |
| Context | `API_BAD_REQUEST` | 400 | Required request context header is missing or invalid. |
| App Config | `API_INTERNAL_ERROR` | 500 | App configuration could not be loaded. |
| Campaigns | `API_BAD_REQUEST` | 400 | Invalid campaign query, such as malformed `brand_id`. |
| Campaigns | `API_INTERNAL_ERROR` | 500 | Campaign/feed load failed. |
| Catalog | `API_BAD_REQUEST` | 400 | Invalid catalog query parameter or unsupported country. |
| Catalog | `API_NOT_FOUND` | 404 | Store or menu item was not found. |
| Catalog | `API_INTERNAL_ERROR` | 500 | Catalog load failed. |
| Cart | `API_BAD_REQUEST` | 400 | Invalid cart payload, item id, or cart mutation. |
| Cart | `API_NOT_FOUND` | 404 | Cart item was not found. |
| Cart | `API_INTERNAL_ERROR` | 500 | Cart operation failed. |
| Checkout | `API_BAD_REQUEST` | 400 | Missing user id, invalid checkout payload, unsupported country, or validation failure. |
| Checkout | `API_NOT_FOUND` | 404 | Store or order was not found. |
| Checkout | `API_CONFLICT` | 409 | Store is closed or cart item is unavailable. |
| Checkout | `API_UNPROCESSABLE` | 422 | Voucher or payment method cannot be applied. |
| Checkout | `API_INTERNAL_ERROR` | 500 | Checkout/order status operation failed. |
| Payments | `API_BAD_REQUEST` | 400 | Invalid provider, method, or callback payload. |
| Payments | `API_UNAUTHORIZED` | 401 | Payment callback secret is missing or invalid. |
| Payments | `API_NOT_FOUND` | 404 | Payment transaction was not found. |
| Payments | `API_CONFLICT` | 409 | Wallet balance is insufficient. |
| Payments | `API_INTERNAL_ERROR` | 500 | Payment operation failed. |
| Vouchers | `API_BAD_REQUEST` | 400 | Invalid voucher query or validation payload. |
| Vouchers | `API_NOT_FOUND` | 404 | Store was not found for voucher validation. |
| Vouchers | `API_CONFLICT` | 409 | Store or cart state prevents voucher validation. |
| Vouchers | `API_INTERNAL_ERROR` | 500 | Voucher wallet or validation operation failed. |
| Users | `USR_AUTH_REQUIRED` | 401 | User profile request has no authenticated user. |
| Users | `USR_UNSUPPORTED_COUNTRY` | 400 | User profile country is not supported. |
| Users | `USR_INVALID_PROFILE_PAYLOAD` | 400 | Profile update body could not be decoded. |
| Users | `USR_INVALID_WALLET_TOPUP_PAYLOAD` | 400 | Wallet top-up body could not be decoded. |
| Users | `USR_INVALID_TOPUP_AMOUNT` | 400 | Wallet top-up amount must be greater than zero. |
| Users | `USR_PROFILE_LOAD_FAILED` | 500 | Profile could not be loaded. |
| Users | `USR_PROFILE_UPDATE_FAILED` | 500 | Profile could not be updated. |
| Users | `USR_WALLET_LOAD_FAILED` | 500 | Wallet history could not be loaded. |
| Users | `USR_WALLET_TOPUP_FAILED` | 500 | Wallet top-up could not be completed. |
| Users | `USR_LOYALTY_LOAD_FAILED` | 500 | Loyalty history could not be loaded. |

When a module has not yet been assigned a domain-specific code, the API fallback code is still returned by status. New user-facing flows should add module-specific codes before app release.
