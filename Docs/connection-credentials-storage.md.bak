# Connection Credentials Storage


# Connection Credentials Storage

By default, Membrane stores connection credentials in the database.

If configured, it allows storing those credentials in an external API.

## Configuration

### Database (default)

No configuration required. By default this is the storage used (default value: `database`).

### External API

You need to set 2 environment variables:

1. `CONNECTION_CREDENTIALS_STORAGE_TYPE` to `external_api`
2. `CONNECTION_CREDENTIALS_EXTERNAL_API_ENDPOINT_URL` to the designated endpoint, using REST API for reading and saving connection credentials.

All communication (saving and reading credentials) will pass `X-Membrane-Token` header with your token.

### Saving credentials

Endpoint URL will contain `connectionId` query parameter (added by Membrane), as connection identifier. Body payload will contain credentials to store.

```sh
PUT: https://api.yourendpointurl.com?connectionId={CONNECTION_ID}
```

Hint: URL can contain any other query parameters, or path. `connectionId` parameter will be added to the URL.

**Payload:**

```json
{
  "credentials": "YOUR_CREDENTIALS"
}
```

**Where:**

- `CONNECTION_ID` is the ID of the connection you wish to store the credentials for
- `YOUR_CREDENTIALS` is any valid JSON value. Can be a string, object, whatever is used for credentials for given connection, e.g.:
  ```json
  {
    "accessToken": "test-access-token",
    "refreshToken": "test-refresh-token",
    "expiresAt": "2024-12-31T23:59:59Z"
  }
  ```

**Expected responses:**

- `201 Created` when save was successful
- non `2xx` when save was unsuccessful

### Reading credentials

Endpoint URL will will contain `credentialsId` query parameter, as connection identifier:

```sh
GET: https://api.yourendpointurl.com?connectionId={CONNECTION_ID}
```

Hint: URL can contain any other query parameters or path. `connectionId` parameter will be added to the URL.

**Expected responses:**

- `200 OK` with body `{ "credentials": "YOUR_CREDENTIALS" }`
- `404 NOT FOUND` when credentials were not found

**Where:**

- `CONNECTION_ID` is the ID of the connection you wish to get the credentials for
- `YOUR_CREDENTIALS` contains previously stored credentials, e.g.:
  ```json
  {
    "accessToken": "test-access-token",
    "refreshToken": "test-refresh-token",
    "expiresAt": "2024-12-31T23:59:59Z"
  }
  ```
