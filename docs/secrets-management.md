# Secrets Management Guide

**Self-Deploy Blueprint Documentation**

Options for managing secrets in self-deployed applications.

---

## Quick Reference

| Method | Complexity | Best For |
|--------|------------|----------|
| Environment Files | Low | Development, simple deployments |
| Docker Secrets | Medium | Docker Swarm deployments |
| SOPS | Medium | Git-committed encrypted secrets |
| HashiCorp Vault | High | Enterprise, dynamic secrets |
| Cloud KMS | Medium | Cloud-hosted deployments |

---

## Level 1: Environment Files

**Use for:** Development, single-server deployments

### Setup

```bash
# Create .env from template
cp .env.example .env

# Edit with your values
nano .env
```

### Security Checklist

- [ ] `.env` in `.gitignore`
- [ ] `.env.example` has no real values
- [ ] Restrict file permissions: `chmod 600 .env`
- [ ] Different `.env` per environment

### Docker Compose Usage

```yaml
services:
  api:
    env_file:
      - .env
    # Or individual variables:
    environment:
      - DATABASE_URL=${DATABASE_URL}
```

---

## Level 2: Docker Secrets

**Use for:** Docker Swarm, multi-node deployments

### Setup

```bash
# Create secret from file
echo "my-secret-value" | docker secret create db_password -

# Create secret from file
docker secret create api_key ./api_key.txt

# List secrets
docker secret ls
```

### Docker Compose Usage

```yaml
version: '3.8'

services:
  api:
    secrets:
      - db_password
      - api_key
    environment:
      # Secrets are mounted at /run/secrets/<name>
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    external: true
  api_key:
    file: ./secrets/api_key.txt
```

### Reading Secrets in Code

```python
# Python
import os

def get_secret(name):
    # Try Docker secret first
    secret_file = f"/run/secrets/{name}"
    if os.path.exists(secret_file):
        with open(secret_file) as f:
            return f.read().strip()
    # Fall back to environment variable
    return os.environ.get(name.upper())

db_password = get_secret('db_password')
```

```javascript
// Node.js
const fs = require('fs');

function getSecret(name) {
  const secretPath = `/run/secrets/${name}`;
  if (fs.existsSync(secretPath)) {
    return fs.readFileSync(secretPath, 'utf8').trim();
  }
  return process.env[name.toUpperCase()];
}

const dbPassword = getSecret('db_password');
```

---

## Level 3: SOPS (Secrets OPerationS)

**Use for:** Git-committed encrypted secrets, GitOps workflows

### Install

```bash
# macOS
brew install sops

# Linux
curl -LO https://github.com/getsops/sops/releases/latest/download/sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
chmod +x /usr/local/bin/sops
```

### Setup with Age (Recommended)

```bash
# Generate key pair
age-keygen -o ~/.sops/key.txt

# Get public key
cat ~/.sops/key.txt | grep "public key"
# Output: # public key: age1...

# Configure SOPS
cat > .sops.yaml << 'EOF'
creation_rules:
  - path_regex: \.env\.encrypted$
    age: age1your_public_key_here
  - path_regex: secrets/.*\.yaml$
    age: age1your_public_key_here
EOF
```

### Encrypt/Decrypt

```bash
# Encrypt existing .env
sops -e .env > .env.encrypted

# Decrypt to stdout
sops -d .env.encrypted

# Edit encrypted file (decrypts, opens editor, re-encrypts)
sops .env.encrypted

# Decrypt to file (for deployment)
sops -d .env.encrypted > .env
```

### YAML Secrets

```yaml
# secrets/production.yaml (encrypted)
database:
    password: ENC[AES256_GCM,data:...,type:str]
    host: production-db.example.com  # Not encrypted
api_keys:
    openai: ENC[AES256_GCM,data:...,type:str]
    stripe: ENC[AES256_GCM,data:...,type:str]
```

### CI/CD Integration

```yaml
# GitHub Actions
jobs:
  deploy:
    steps:
      - name: Decrypt secrets
        env:
          SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
        run: |
          sops -d .env.encrypted > .env
```

---

## Level 4: HashiCorp Vault

**Use for:** Enterprise, dynamic secrets, audit requirements

### Setup (Docker)

```yaml
# docker-compose.yml
services:
  vault:
    image: hashicorp/vault:1.15
    cap_add:
      - IPC_LOCK
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: dev-token
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    volumes:
      - vault-data:/vault/data
```

### Store Secrets

```bash
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Store secret
vault kv put secret/myapp/database \
    password="supersecret" \
    host="db.example.com"

# Read secret
vault kv get secret/myapp/database
```

### Application Integration

```python
# Python with hvac
import hvac

client = hvac.Client(
    url='http://vault:8200',
    token=os.environ['VAULT_TOKEN']
)

# Read secret
secret = client.secrets.kv.v2.read_secret_version(
    path='myapp/database',
    mount_point='secret'
)
db_password = secret['data']['data']['password']
```

```javascript
// Node.js with node-vault
const vault = require('node-vault')({
  endpoint: 'http://vault:8200',
  token: process.env.VAULT_TOKEN
});

const { data } = await vault.read('secret/data/myapp/database');
const dbPassword = data.data.password;
```

### Dynamic Database Credentials

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL
vault write database/config/myapp \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@db:5432/app" \
    allowed_roles="myapp-role" \
    username="vault" \
    password="vault-password"

# Create role
vault write database/roles/myapp-role \
    db_name=myapp \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Get dynamic credentials
vault read database/creds/myapp-role
```

---

## Level 5: Cloud KMS

### AWS Secrets Manager

```bash
# Create secret
aws secretsmanager create-secret \
    --name myapp/database \
    --secret-string '{"password":"supersecret"}'

# Get secret
aws secretsmanager get-secret-value \
    --secret-id myapp/database
```

```python
# Python with boto3
import boto3
import json

client = boto3.client('secretsmanager')
response = client.get_secret_value(SecretId='myapp/database')
secrets = json.loads(response['SecretString'])
db_password = secrets['password']
```

### Google Cloud Secret Manager

```bash
# Create secret
echo -n "supersecret" | gcloud secrets create db-password --data-file=-

# Access secret
gcloud secrets versions access latest --secret=db-password
```

### Azure Key Vault

```bash
# Create secret
az keyvault secret set \
    --vault-name myapp-vault \
    --name db-password \
    --value "supersecret"

# Get secret
az keyvault secret show \
    --vault-name myapp-vault \
    --name db-password
```

---

## Recommendations by Deployment Type

| Deployment | Recommended Approach |
|------------|---------------------|
| Local development | `.env` files |
| Single VPS | `.env` with restricted permissions |
| Docker Compose | Docker secrets (file-based) |
| Docker Swarm | Docker secrets (Swarm-managed) |
| Kubernetes | K8s Secrets + External Secrets Operator |
| GitOps workflow | SOPS encrypted in repo |
| Enterprise/Compliance | HashiCorp Vault |
| Cloud-native | Cloud provider's secret manager |

---

## Migration Path

### From .env to SOPS

```bash
# 1. Install SOPS and age
brew install sops age

# 2. Generate keys
age-keygen -o ~/.sops/key.txt

# 3. Create .sops.yaml config
echo "creation_rules:
  - age: $(cat ~/.sops/key.txt | grep 'public key' | cut -d: -f2 | tr -d ' ')" > .sops.yaml

# 4. Encrypt existing .env
sops -e .env > .env.encrypted

# 5. Add .env to .gitignore, commit .env.encrypted
echo ".env" >> .gitignore
git add .env.encrypted .sops.yaml
git commit -m "Switch to SOPS for secrets management"

# 6. Update deployment to decrypt
# In your start script:
# sops -d .env.encrypted > .env
```

---

## Security Best Practices

1. **Never commit plaintext secrets** to version control
2. **Rotate secrets regularly** (at least quarterly for production)
3. **Use different secrets** per environment (dev, staging, production)
4. **Audit access** to secret management systems
5. **Encrypt secrets at rest** and in transit
6. **Limit secret scope** - only expose what's needed
7. **Use short-lived credentials** when possible (Vault dynamic secrets)
8. **Monitor for leaks** using tools like GitLeaks, TruffleHog

---

**Version:** 1.0.0 | **Updated:** December 2025
