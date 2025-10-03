# Connector Management

This guide covers deploying and managing custom connectors in your self-hosted Membrane environment.

## Overview

Connectors are packaged as `.zip` archives and stored in your connectors storage bucket. There are two ways to deploy connectors:

1. **Automated** - Using Membrane CLI (recommended)
2. **Manual** - Upload via Console UI

## Method 1: Membrane CLI (Recommended)

The [Membrane CLI](https://www.npmjs.com/package/@membranehq/membrane-cli) automates connector migration from cloud to self-hosted environments.

### Installation

```bash
npm install -g @membranehq/membrane-cli
```

### Usage

```bash
# Login to cloud Membrane
membrane login

# List available connectors
membrane connectors list

# Download a connector
membrane connectors download <connector-name>

# Upload to self-hosted instance
membrane connectors upload <connector-name>.zip \
  --api-url https://api.yourdomain.com \
  --token <your-jwt-token>
```

### Migrate All Connectors

```bash
# Download all connectors from cloud
membrane connectors download-all --output ./connectors

# Upload to self-hosted
for file in ./connectors/*.zip; do
  membrane connectors upload "$file" \
    --api-url https://api.yourdomain.com \
    --token <your-jwt-token>
done
```

## Method 2: Manual Upload via Console

### Upload Connector

1. Log in to Console: `https://console.yourdomain.com`
2. Navigate to **Integrations** > **Apps**
3. Click **Upload Connector**
4. Select your `.zip` file
5. Click **Upload**

### Connector Package Structure

A connector package must follow this structure:

```
connector-name.zip
├── manifest.json
├── index.js (or index.ts)
├── package.json (optional)
└── ... other files
```

**manifest.json example:**
```json
{
  "name": "my-custom-connector",
  "version": "1.0.0",
  "displayName": "My Custom Connector",
  "description": "A custom connector for my service",
  "icon": "data:image/svg+xml;base64,...",
  "authentication": {
    "type": "oauth2",
    "config": {
      "authorizationUrl": "https://api.example.com/oauth/authorize",
      "tokenUrl": "https://api.example.com/oauth/token",
      "clientId": "{{clientId}}",
      "clientSecret": "{{clientSecret}}"
    }
  },
  "actions": [...],
  "triggers": [...],
  "dataSources": [...]
}
```

## Managing Connectors

### List Connectors

**Via Console:**
- Navigate to **Integrations** > **Apps**
- View all installed connectors

**Via API:**
```bash
curl -X GET https://api.yourdomain.com/apps \
  -H "Authorization: Bearer <your-jwt-token>"
```

### Update Connector

To update a connector, upload a new version with the same name. The system will:
1. Validate the new package
2. Replace the existing connector
3. Restart affected integrations

### Delete Connector

**Via Console:**
1. Navigate to **Integrations** > **Apps**
2. Find the connector
3. Click **Delete**
4. Confirm deletion

**Via API:**
```bash
curl -X DELETE https://api.yourdomain.com/apps/<connector-id> \
  -H "Authorization: Bearer <your-jwt-token>"
```

## Connector Versioning

### Version Strategy

- Store connector versions in your connectors bucket
- Use naming convention: `connector-name-v1.0.0.zip`
- Enable versioning on your connectors storage bucket (recommended)

### Rollback to Previous Version

If versioning is enabled on your storage bucket:

**AWS S3:**
```bash
aws s3api list-object-versions \
  --bucket integration-app-connectors \
  --prefix my-connector.zip

aws s3api get-object \
  --bucket integration-app-connectors \
  --key my-connector.zip \
  --version-id <version-id> \
  my-connector-old.zip
```

Then re-upload the old version via Console or CLI.

## Storage Configuration

Connectors are stored in the bucket specified by `CONNECTORS_STORAGE_BUCKET` environment variable.

### Storage Structure

```
connectors-bucket/
├── my-connector-v1.zip
├── another-connector-v2.zip
├── custom-integration-v1.zip
└── ...
```

### Storage Permissions

Ensure the Membrane API service has these permissions:

**AWS S3:**
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `s3:ListBucket`

**Azure Blob Storage:**
- Storage Blob Data Contributor role

**Google Cloud Storage:**
- `storage.objects.create`
- `storage.objects.get`
- `storage.objects.delete`
- `storage.buckets.get`

## Developing Custom Connectors

### Development Resources

- [Membrane Connector SDK Documentation](https://docs.membrane.app/connectors)
- [Example Connectors Repository](https://github.com/membranehq/connectors)
- [Connector Development Guide](https://docs.membrane.app/guides/building-connectors)

### Local Development

```bash
# Install Membrane CLI
npm install -g @membranehq/membrane-cli

# Create new connector
membrane connectors create my-connector

# Develop locally
cd my-connector
npm install
npm run dev

# Build and package
npm run build
membrane connectors package

# Upload to self-hosted
membrane connectors upload my-connector.zip \
  --api-url https://api.yourdomain.com \
  --token <your-jwt-token>
```

### Testing Connectors

1. Upload connector to self-hosted environment
2. Create a test integration using the connector
3. Test authentication flow
4. Test each action and trigger
5. Monitor logs for errors

**Enable debug logs:**
```bash
# On API service
DEBUG_ALL=1
```

## Connector Security

### Code Review

Before uploading custom connectors:
- Review code for security vulnerabilities
- Validate all external API calls
- Ensure secrets are properly handled
- Check for malicious code

### Sandboxing

Custom code runs in isolated Custom Code Runner service:
- Limited network access
- Memory and time limits enforced
- No access to host system
- Restricted file system access

### Credentials Storage

Connector credentials are:
- Encrypted at rest using `ENCRYPTION_SECRET`
- Stored in MongoDB or external API (see [Connection Credentials Storage](connection-credentials-storage.md))
- Never logged or exposed in plain text

## Troubleshooting

### Connector Upload Fails

**Check:**
- File is valid ZIP format
- manifest.json is valid JSON
- Connector name is unique
- File size is within limits
- Storage bucket is accessible

**View logs:**
```bash
kubectl logs -n membrane -l app=api --tail=100
```

### Connector Not Appearing

**Check:**
- Upload completed successfully
- Console cache (refresh page)
- API logs for errors
- Storage bucket permissions

### Connector Execution Errors

**Check:**
- Custom Code Runner service is running
- CUSTOM_CODE_RUNNER_URI is correctly configured
- Memory limits are sufficient (20GB virtual for AMD64)
- Review connector code for errors

**View Custom Code Runner logs:**
```bash
kubectl logs -n membrane -l app=custom-code-runner --tail=100
```

## Best Practices

1. **Version control** - Keep connector source code in git
2. **Test thoroughly** - Test all actions and triggers before production
3. **Enable versioning** - Use storage bucket versioning for rollback capability
4. **Document connectors** - Maintain documentation for custom connectors
5. **Monitor usage** - Track connector execution metrics
6. **Regular updates** - Keep connectors updated with API changes
7. **Security review** - Review third-party connectors before uploading

## Migration Checklist

When migrating from cloud to self-hosted:

- [ ] Install Membrane CLI
- [ ] Authenticate to cloud Membrane
- [ ] Download all connectors
- [ ] Review connector code (if custom)
- [ ] Upload to self-hosted instance
- [ ] Test each connector
- [ ] Update integrations if needed
- [ ] Document custom connectors

## Next Steps

- Review [System Webhooks](system-webhooks.md) for event notifications
- Configure [Connection Credentials Storage](connection-credentials-storage.md)
- Check [FAQ](faq.md) for common questions
