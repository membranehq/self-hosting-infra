# Auth0 Authentication

Auth0 is the recommended authentication provider for Membrane. This guide covers Auth0 configuration for self-hosted deployments.

## Why Auth0?

- **Free tier sufficient** - The Auth0 free plan supports up to 7,000 active users
- **Enterprise features** - SSO, MFA, custom domains included
- **Easy setup** - Minimal configuration required
- **Secure** - Industry-standard OAuth 2.0 / OpenID Connect

## Prerequisites

- Auth0 account (sign up at [auth0.com](https://auth0.com))
- Domain for your Membrane deployment

## Auth0 Setup

### 1. Create Auth0 Application

1. Log in to your Auth0 Dashboard
2. Navigate to **Applications** > **Applications**
3. Click **Create Application**
4. Configure:
   - **Name:** `Membrane Console` (or your preferred name)
   - **Application Type:** **Single Page Application**
5. Click **Create**

### 2. Configure Application Settings

In your newly created application, navigate to the **Settings** tab:

#### Basic Information

Record these values - you'll need them for environment variables:
- **Domain:** `your-tenant.auth0.com` (or custom domain)
- **Client ID:** Your application's client ID
- **Client Secret:** Your application's client secret (reveal and copy)

#### Application URIs

Configure the following URIs based on your Console service URL:

**Allowed Callback URLs:**
```
https://console.yourdomain.com
https://console.yourdomain.com/callback
```

**Allowed Logout URLs:**
```
https://console.yourdomain.com
```

**Allowed Web Origins:**
```
https://console.yourdomain.com
```

**Allowed Origins (CORS):**
```
https://console.yourdomain.com
```

> Replace `console.yourdomain.com` with your actual Console service URL.

#### Advanced Settings

Navigate to **Advanced Settings** > **Grant Types** and ensure these are enabled:
- ✅ Implicit
- ✅ Authorization Code
- ✅ Refresh Token

### 3. Create Auth0 API (Optional but Recommended)

For M2M (machine-to-machine) authentication and API access:

1. Navigate to **Applications** > **APIs**
2. Click **Create API**
3. Configure:
   - **Name:** `Membrane API`
   - **Identifier:** `https://api.yourdomain.com` (your API base URL)
   - **Signing Algorithm:** RS256
4. Click **Create**

### 4. Configure Custom Domain (Optional)

For production deployments, use a custom domain:

1. Navigate to **Branding** > **Custom Domains**
2. Click **Set Up Custom Domain**
3. Enter your domain: `login.yourdomain.com`
4. Verify domain ownership via DNS
5. Configure SSL certificate (Auth0 provides managed certificates)

**Using custom domain:**
- Use `login.yourdomain.com` instead of `your-tenant.auth0.com` for `AUTH0_DOMAIN`

## Environment Variables

Configure these environment variables for your Membrane services:

### API Service

```bash
# Auth0 Configuration
AUTH0_DOMAIN=your-tenant.auth0.com  # or login.yourdomain.com for custom domain
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
```

### Console Service

```bash
# Auth0 Configuration
NEXT_PUBLIC_AUTH0_DOMAIN=your-tenant.auth0.com  # or login.yourdomain.com
NEXT_PUBLIC_AUTH0_CLIENT_ID=your_client_id
NEXT_PUBLIC_BASE_URI=https://console.yourdomain.com
```

## Complete Example

Here's a complete configuration example:

### Auth0 Application Settings

```
Application Name: Membrane Console
Application Type: Single Page Application
Domain: membrane-prod.auth0.com
Client ID: abc123def456ghi789
Client Secret: *********************

Allowed Callback URLs:
https://console.integration.example.com
https://console.integration.example.com/callback

Allowed Logout URLs:
https://console.integration.example.com

Allowed Web Origins:
https://console.integration.example.com

Allowed Origins (CORS):
https://console.integration.example.com
```

### Environment Variables

**API Service:**
```bash
AUTH0_DOMAIN=membrane-prod.auth0.com
AUTH0_CLIENT_ID=abc123def456ghi789
AUTH0_CLIENT_SECRET=your_actual_client_secret_here
```

**Console Service:**
```bash
NEXT_PUBLIC_AUTH0_DOMAIN=membrane-prod.auth0.com
NEXT_PUBLIC_AUTH0_CLIENT_ID=abc123def456ghi789
NEXT_PUBLIC_BASE_URI=https://console.integration.example.com
```

## User Management

### Creating Admin Users

1. Navigate to **User Management** > **Users** in Auth0 Dashboard
2. Click **Create User**
3. Enter email and password
4. User will receive a verification email

### Inviting Users

Membrane includes built-in user invitation functionality:
- Organization admins can invite users via the Console
- Invitation emails are sent automatically
- See [System Webhooks](../system-webhooks.md) for invitation event handling

### SSO Configuration (Optional)

For enterprise SSO:

1. Navigate to **Authentication** > **Enterprise**
2. Choose your SSO provider (SAML, OAuth, etc.)
3. Configure connection settings
4. Enable for your application

## Testing Authentication

### Test Login Flow

1. Navigate to your Console URL: `https://console.yourdomain.com`
2. You should be redirected to Auth0 login page
3. Log in with your Auth0 user credentials
4. You should be redirected back to the Console

### Troubleshooting

**"Callback URL mismatch" error:**
- Verify the callback URL is added to "Allowed Callback URLs" in Auth0
- Ensure the URL exactly matches (including https://, trailing slash, etc.)

**"Access Denied" error:**
- Check that Grant Types are properly configured
- Verify client ID and secret are correct

**Console doesn't redirect to Auth0:**
- Check `NEXT_PUBLIC_AUTH0_DOMAIN` is set correctly
- Verify `NEXT_PUBLIC_BASE_URI` matches your actual Console URL
- Check browser console for errors

## Security Best Practices

### Rotate Secrets Regularly

- Rotate `AUTH0_CLIENT_SECRET` every 90 days
- Auth0 supports multiple active secrets during rotation

### Enable MFA

1. Navigate to **Security** > **Multi-factor Auth**
2. Enable desired MFA factors (SMS, Authenticator App, etc.)
3. Configure MFA policies

### Configure Rate Limiting

Auth0 automatically provides DDoS protection and rate limiting.

### Use Custom Domain in Production

- Custom domains provide better branding
- Avoid exposing Auth0 tenant name
- Improves user trust

## Alternative: Username/Password Provider

If you prefer not to use Auth0, see [Username/Password Authentication](username-password.md) for the built-in alternative.

## Next Steps

1. Test authentication by logging into the Console
2. Create admin users in Auth0
3. Proceed to [Service Deployment](../deployment/services.md)

## Additional Resources

- [Auth0 Documentation](https://auth0.com/docs)
- [Auth0 Single Page App Quickstart](https://auth0.com/docs/quickstart/spa)
- [Auth0 Security Best Practices](https://auth0.com/docs/security)
