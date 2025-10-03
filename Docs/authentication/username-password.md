# Username/Password Authentication

Membrane includes a built-in username/password authentication provider as an alternative to Auth0. This is useful for air-gapped environments or when you prefer not to use a third-party authentication service.

## Overview

The username/password provider:
- ✅ No external dependencies
- ✅ Self-contained authentication
- ✅ User management via API
- ✅ Password hashing with bcrypt
- ❌ No SSO/SAML support
- ❌ No MFA built-in
- ❌ Basic feature set compared to Auth0

## When to Use

**Use username/password authentication when:**
- Deploying in air-gapped or restricted environments
- Company policy prohibits third-party auth services
- Simple authentication requirements

**Use Auth0 when:**
- You need SSO, MFA, or enterprise features
- You want social login providers
- You need advanced security features
- Managing many users across multiple organizations

## Configuration

### Environment Variables

The username/password provider is enabled by **not** setting Auth0 environment variables.

**API Service:**
```bash
# Do NOT set these Auth0 variables:
# AUTH0_DOMAIN=
# AUTH0_CLIENT_ID=
# AUTH0_CLIENT_SECRET=

# Required variables (same as with Auth0):
SECRET=your_jwt_secret_key_here  # Used for signing JWT tokens
BASE_URI=https://api.yourdomain.com
```

**Console Service:**
```bash
# Do NOT set these Auth0 variables:
# NEXT_PUBLIC_AUTH0_DOMAIN=
# NEXT_PUBLIC_AUTH0_CLIENT_ID=

# Required variables:
NEXT_PUBLIC_ENGINE_API_URI=https://api.yourdomain.com
NEXT_PUBLIC_BASE_URI=https://console.yourdomain.com
```

### JWT Secret

The `SECRET` environment variable is critical for security:

```bash
# Generate a strong random secret:
openssl rand -base64 32
```

**Important:**
- Use a cryptographically secure random string
- Minimum 32 characters recommended
- Never commit to version control
- Rotate periodically

## User Management

### Creating the First Admin User

When using username/password authentication, create the first admin user via API:

```bash
curl -X POST https://api.yourdomain.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@yourdomain.com",
    "password": "SecurePassword123!",
    "name": "Admin User"
  }'
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user123",
    "email": "admin@yourdomain.com",
    "name": "Admin User"
  }
}
```

### User Login

Users log in via the Console interface or API:

**Console Login:**
1. Navigate to `https://console.yourdomain.com`
2. Enter email and password
3. Click "Sign In"

**API Login:**
```bash
curl -X POST https://api.yourdomain.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@yourdomain.com",
    "password": "SecurePassword123!"
  }'
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user123",
    "email": "admin@yourdomain.com",
    "name": "Admin User"
  }
}
```

### Inviting Additional Users

Organization admins can invite users through the Console:

1. Log in to Console as admin
2. Navigate to **Organization** > **Users**
3. Click **Invite User**
4. Enter user email
5. User receives invitation email with setup link

**API User Invitation:**
```bash
curl -X POST https://api.yourdomain.com/org/users/invite \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@yourdomain.com"
  }'
```

### Password Reset

Users can request password reset via the Console:

1. On login page, click **Forgot Password?**
2. Enter email address
3. Receive password reset email
4. Click link and set new password

**API Password Reset Request:**
```bash
curl -X POST https://api.yourdomain.com/auth/password-reset \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@yourdomain.com"
  }'
```

## Security Considerations

### Password Requirements

Default password requirements:
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- Special characters recommended

### Password Hashing

Passwords are hashed using bcrypt with a cost factor of 10. Never store or transmit plain text passwords.

### JWT Token Security

JWT tokens are used for authentication:
- Tokens expire after 24 hours by default
- Signed with `SECRET` environment variable
- Include user ID and permissions

**Token Storage:**
- Console stores tokens in browser localStorage
- API clients should store tokens securely
- Never expose tokens in logs or URLs

### HTTPS Required

**Always use HTTPS in production:**
- Passwords transmitted over encrypted connections
- Tokens protected from interception
- Use valid SSL/TLS certificates

## Email Configuration

The username/password provider requires email configuration for:
- User invitations
- Password reset emails
- Account notifications

### SMTP Configuration

Configure SMTP via environment variables:

```bash
# SMTP Server Settings
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false  # true for port 465, false for port 587
SMTP_USER=noreply@yourdomain.com
SMTP_PASSWORD=smtp_password_here

# Email Settings
EMAIL_FROM=noreply@yourdomain.com
EMAIL_FROM_NAME=Membrane
```

### Supported Email Providers

Works with any SMTP provider:
- **SendGrid**
- **AWS SES**
- **Mailgun**
- **Postmark**
- **Office 365**
- **Gmail** (for testing only)

### Testing Email Configuration

Test email sending:

```bash
curl -X POST https://api.yourdomain.com/auth/test-email \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "test@yourdomain.com"
  }'
```

## User Roles and Permissions

The username/password provider supports the same role-based access control as Auth0:

- **Platform Admin** - Full system access
- **Organization Admin** - Manage organization and users
- **Organization Member** - Access organization integrations
- **Customer** - End-user access to integrations

Roles are assigned via the Console or API.

## Comparison: Auth0 vs Username/Password

| Feature | Auth0 | Username/Password |
|---------|-------|-------------------|
| SSO/SAML | ✅ Yes | ❌ No |
| Social Login | ✅ Yes | ❌ No |
| MFA | ✅ Built-in | ❌ No |
| User Management UI | ✅ Advanced | ⚠️ Basic (via Console) |
| External Dependencies | ⚠️ Auth0 service | ✅ None |
| Air-Gapped Support | ❌ No | ✅ Yes |
| Setup Complexity | ⚠️ Moderate | ✅ Simple |
| Cost | ✅ Free tier | ✅ Free |

## Migration Between Providers

### From Username/Password to Auth0

To migrate from username/password to Auth0:

1. Set up Auth0 application (see [Auth0 guide](auth0.md))
2. Export users from Membrane database
3. Import users to Auth0 via bulk import
4. Configure Auth0 environment variables
5. Restart services
6. Users authenticate via Auth0

### From Auth0 to Username/Password

To migrate from Auth0 to username/password:

1. Remove Auth0 environment variables
2. Set `SECRET` environment variable
3. Configure SMTP for email
4. Restart services
5. Recreate users or trigger password reset for all users

## Troubleshooting

### Cannot Log In

**Check:**
- Verify `SECRET` is set correctly on API service
- Ensure password meets requirements
- Check browser console for errors
- Verify API service is accessible

### Password Reset Emails Not Sending

**Check:**
- SMTP configuration is correct
- SMTP credentials are valid
- Test email connectivity
- Check API service logs for SMTP errors

### JWT Token Errors

**Check:**
- `SECRET` matches across all API service instances
- Token hasn't expired
- Token is being sent in Authorization header
- Clock sync across services

## Best Practices

1. **Use strong JWT secrets** - Generate cryptographically random secrets
2. **Enforce HTTPS** - Never use username/password auth over HTTP
3. **Rotate secrets** - Rotate JWT secret every 90 days
4. **Monitor failed logins** - Implement rate limiting for login attempts
5. **Use email verification** - Require email verification for new users
6. **Regular backups** - Backup user database regularly

## Next Steps

1. Configure SMTP for email functionality
2. Create admin users
3. Test login flow
4. Proceed to [Service Deployment](../deployment/services.md)

## Additional Resources

- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
