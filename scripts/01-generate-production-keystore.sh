#!/bin/bash

################################################################################
# VibeApp Production Keystore Generation
# 
# This script generates a production-grade RSA 4096-bit keystore for signing
# release APKs. All generated passwords are cryptographically secure.
#
# Usage: ./scripts/01-generate-production-keystore.sh
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
KEYSTORE_FILE="production.keystore"
SECRETS_FILE=".secrets.env"
README_FILE="KEYSTORE_SETUP_README.md"
BACKUP_DIR=".keystore-backup"

# Check prerequisites
check_requirements() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    if ! command -v keytool &> /dev/null; then
        missing_tools+=("keytool (Java Development Kit)")
    fi
    
    if ! command -v openssl &> /dev/null; then
        missing_tools+=("openssl")
    fi
    
    if ! command -v base64 &> /dev/null; then
        missing_tools+=("base64")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "${RED}   - $tool${NC}"
        done
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}\n"
}

# Generate secure random passwords
generate_passwords() {
    echo -e "${BLUE}🔐 Generating cryptographically secure passwords...${NC}"
    
    # Generate 32-byte (256-bit) random strings
    KEYSTORE_PASSWORD=$(openssl rand -base64 32)
    KEY_PASSWORD=$(openssl rand -base64 32)
    
    echo -e "${GREEN}✅ Passwords generated${NC}\n"
}

# Create keystore with optimal settings
create_keystore() {
    echo -e "${BLUE}🔨 Creating keystore with production-grade settings...${NC}"
    
    # Certificate information
    COMMON_NAME="VibeApp Production"
    ORG_NAME="VibeApp Development Team"
    ORG_UNIT="Engineering"
    LOCATION="Global"
    STATE="Global"
    COUNTRY="US"
    KEY_ALIAS="vibeapp-prod-$(date +%Y%m%d)"
    
    echo -e "${CYAN}  Certificate Details:${NC}"
    echo -e "${CYAN}    CN:    $COMMON_NAME${NC}"
    echo -e "${CYAN}    OU:    $ORG_UNIT${NC}"
    echo -e "${CYAN}    O:     $ORG_NAME${NC}"
    echo -e "${CYAN}    L:     $LOCATION${NC}"
    echo -e "${CYAN}    ST:    $STATE${NC}"
    echo -e "${CYAN}    C:     $COUNTRY${NC}"
    echo -e "${CYAN}    Alias: $KEY_ALIAS${NC}"
    echo ""
    
    # Generate keystore
    keytool -genkey -v \
        -keystore "$KEYSTORE_FILE" \
        -keyalg RSA \
        -keysize 4096 \
        -validity 36500 \
        -alias "$KEY_ALIAS" \
        -storepass "$KEYSTORE_PASSWORD" \
        -keypass "$KEY_PASSWORD" \
        -dname "CN=$COMMON_NAME,OU=$ORG_UNIT,O=$ORG_NAME,L=$LOCATION,ST=$STATE,C=$COUNTRY" \
        -storetype PKCS12 || {
        echo -e "${RED}❌ Keystore creation failed${NC}"
        exit 1
    }
    
    if [ ! -f "$KEYSTORE_FILE" ]; then
        echo -e "${RED}❌ Keystore file not created${NC}"
        exit 1
    fi
    
    # Verify keystore
    echo ""
    echo -e "${BLUE}🔍 Verifying keystore integrity...${NC}"
    keytool -list -v \
        -keystore "$KEYSTORE_FILE" \
        -storepass "$KEYSTORE_PASSWORD" \
        -storetype PKCS12 > /dev/null 2>&1 || {
        echo -e "${RED}❌ Keystore verification failed${NC}"
        exit 1
    }
    
    echo -e "${GREEN}✅ Keystore created and verified${NC}\n"
}

# Display keystore information
display_keystore_info() {
    echo -e "${BLUE}📋 Keystore Information:${NC}"
    keytool -list -v \
        -keystore "$KEYSTORE_FILE" \
        -storepass "$KEYSTORE_PASSWORD" \
        -storetype PKCS12 | grep -E "(Owner|Issuer|Serial number|Valid from|Valid until|Certificate fingerprints|Signature algorithm)" || true
    echo ""
}

# Encode keystore to Base64
encode_to_base64() {
    echo -e "${BLUE}📤 Encoding keystore to Base64...${NC}"
    KEYSTORE_BASE64=$(base64 < "$KEYSTORE_FILE")
    echo -e "${GREEN}✅ Base64 encoding complete${NC}\n"
}

# Create secrets configuration file
create_secrets_file() {
    echo -e "${BLUE}📝 Creating secrets configuration file...${NC}"
    
    cat > "$SECRETS_FILE" << EOF
################################################################################
# ⚠️  SENSITIVE FILE - DO NOT COMMIT TO REPOSITORY
################################################################################
# This file contains credentials needed to configure GitHub Secrets
# Keep this file secure and delete it after setup
#
# Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
################################################################################

# Base64-encoded keystore (for APP_KEYSTORE secret)
APP_KEYSTORE_BASE64="$KEYSTORE_BASE64"

# Keystore master password (for KEYSTORE_PASSWORD secret)
KEYSTORE_PASSWORD="$KEYSTORE_PASSWORD"

# Key password (for KEY_PASSWORD secret)
KEY_PASSWORD="$KEY_PASSWORD"

# Key alias (for KEY_ALIAS secret)
KEY_ALIAS="$(keytool -list -keystore "$KEYSTORE_FILE" -storepass "$KEYSTORE_PASSWORD" -storetype PKCS12 | grep "Entry type" | head -1 | awk '{print $6}')"

################################################################################
# Setup Instructions:
#
# 1. Add to GitHub Secrets:
#    https://github.com/samehlove218/VibeApp/settings/secrets/actions
#
# 2. Create each secret:
#    - Name: APP_KEYSTORE
#      Value: \$APP_KEYSTORE_BASE64 (entire base64 string)
#    
#    - Name: KEYSTORE_PASSWORD
#      Value: \$KEYSTORE_PASSWORD
#    
#    - Name: KEY_PASSWORD
#      Value: \$KEY_PASSWORD
#    
#    - Name: KEY_ALIAS
#      Value: \$KEY_ALIAS
#
# 3. Delete this file after setup:
#    rm $SECRETS_FILE
#
# 4. Create encrypted backup of keystore:
#    openssl enc -aes-256-cbc -salt -in $KEYSTORE_FILE -out $KEYSTORE_FILE.enc
#
# 5. Store backup in secure location (offline, cloud drive, etc.)
################################################################################
EOF
    
    chmod 600 "$SECRETS_FILE"
    echo -e "${GREEN}✅ Secrets file created: $SECRETS_FILE${NC}\n"
}

# Create setup documentation
create_documentation() {
    echo -e "${BLUE}📚 Creating setup documentation...${NC}"
    
    cat > "$README_FILE" << 'EOF'
# 🔐 VibeApp Production Keystore Setup Guide

## Overview

This guide documents the production keystore setup for VibeApp release builds.

### Key Specifications

- **Algorithm**: RSA 4096-bit
- **Validity**: 25 years (36,500 days)
- **Format**: PKCS12 (JKS is deprecated)
- **Created**: $(date)
- **Purpose**: Signing release APKs and app bundles

## Security Requirements

### What You Have

1. **production.keystore** - The keystore file (binary)
2. **.secrets.env** - Temporary configuration file with credentials
3. **KEYSTORE_SETUP_README.md** - This documentation

### What You Must Do

1. ✅ **Backup keystore securely**
   ```bash
   # Create encrypted backup
   openssl enc -aes-256-cbc -salt -in production.keystore -out production.keystore.enc
   
   # Store in secure location:
   # - Offline USB drive (encrypted)
   # - Cloud storage (Google Drive, Dropbox, etc.)
   # - Password manager vault
   # - Safe deposit box (physical copy)
   ```

2. ✅ **Configure GitHub Secrets**
   - Go to: https://github.com/samehlove218/VibeApp/settings/secrets/actions
   - Add the 4 secrets from .secrets.env file
   - Verify all secrets are set

3. ✅ **Delete temporary files**
   ```bash
   # Delete after GitHub Secrets are configured
   rm .secrets.env
   rm production.keystore (optional - keep for local builds)
   ```

## GitHub Secrets Setup

### Required Secrets

| Secret Name | Source | Description |
|---|---|---|
| `APP_KEYSTORE` | `.secrets.env` → `APP_KEYSTORE_BASE64` | Base64-encoded keystore file |
| `KEYSTORE_PASSWORD` | `.secrets.env` → `KEYSTORE_PASSWORD` | Master keystore password |
| `KEY_PASSWORD` | `.secrets.env` → `KEY_PASSWORD` | Key entry password |
| `KEY_ALIAS` | `.secrets.env` → `KEY_ALIAS` | Alias of the signing key |

### Setup Steps

1. Open GitHub Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Copy each value from `.secrets.env`
4. Paste into the corresponding secret name
5. Verify all 4 secrets are created

## Verification

### Verify Keystore Locally

```bash
# List keystore contents
keytool -list -v -keystore production.keystore -storepass "<KEYSTORE_PASSWORD>" -storetype PKCS12

# Verify specific key
keytool -list -keystore production.keystore -alias "<KEY_ALIAS>" -storepass "<KEYSTORE_PASSWORD>" -storetype PKCS12
```

### Test with APK Signing

```bash
# After configuring GitHub Secrets, trigger a release build
git tag -a v1.0.0 -m "Test release"
git push origin v1.0.0

# Monitor: https://github.com/samehlove218/VibeApp/actions
```

## Troubleshooting

### "Tag number over 30 is not supported"

**Cause**: Corrupted or invalid keystore format
**Solution**: Regenerate keystore using the script

### "Key alias not found"

**Cause**: Wrong key alias in secrets
**Solution**: Verify KEY_ALIAS matches what's in keystore

### "Keystore was tampered with"

**Cause**: File corruption during transfer
**Solution**: Re-encode from original file or regenerate

## Emergency Procedures

### Key Compromise

If private key is compromised:

1. **Immediate**: Revoke all GitHub Secrets
   ```
   Settings → Secrets and variables → Actions → Delete all VibeApp secrets
   ```

2. **Regenerate**: Create new keystore
   ```bash
   ./scripts/01-generate-production-keystore.sh
   ```

3. **Update**: Reconfigure GitHub Secrets with new values

4. **Document**: Record incident and resolution

### Lost Keystore Password

If you forget the passwords:

1. Regenerate keystore (old one becomes invalid)
2. Update GitHub Secrets
3. Any APKs signed with old key become untrusted
4. Notify team of key rotation

## Best Practices

- ✅ Always backup keystore securely
- ✅ Never commit .secrets.env to repository
- ✅ Rotate keys every 2-3 years
- ✅ Test signing process before release
- ✅ Document all security procedures
- ✅ Limit access to keystore credentials
- ✅ Use encrypted storage for backups
- ✅ Enable 2FA on GitHub account

## References

- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [keytool Documentation](https://docs.oracle.com/en/java/javase/17/docs/specs/man/keytool.html)
- [GitHub Secrets Management](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [OpenSSL Encryption](https://www.openssl.org/docs/man1.1.1/man1/enc.html)

---

Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
Keystore Version: 1.0
EOF
    
    echo -e "${GREEN}✅ Documentation created: $README_FILE${NC}\n"
}

# Create backup directory
create_backup_prompt() {
    echo -e "${YELLOW}📦 Backup Recommendation${NC}"
    echo ""
    echo "The following files should be backed up securely:"
    echo -e "${CYAN}  1. $KEYSTORE_FILE (keystore binary)${NC}"
    echo -e "${CYAN}  2. $SECRETS_FILE (credentials - temporary)${NC}"
    echo -e "${CYAN}  3. $README_FILE (documentation)${NC}"
    echo ""
    echo "Create encrypted backup:"
    echo -e "${CYAN}  openssl enc -aes-256-cbc -salt -in $KEYSTORE_FILE -out $KEYSTORE_FILE.enc${NC}"
    echo ""
}

# Summary and next steps
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ KEYSTORE GENERATION COMPLETE                              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 Generated Files:${NC}"
    echo -e "${CYAN}  1. $KEYSTORE_FILE${NC}"
    echo -e "${CYAN}  2. $SECRETS_FILE${NC}"
    echo -e "${CYAN}  3. $README_FILE${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
    echo ""
    echo "Step 1️⃣  - Configure GitHub Secrets"
    echo "   $ ./scripts/02-setup-github-secrets.sh"
    echo ""
    echo "Step 2️⃣  - Backup keystore securely"
    echo "   $ openssl enc -aes-256-cbc -salt -in $KEYSTORE_FILE -out $KEYSTORE_FILE.enc"
    echo ""
    echo "Step 3️⃣  - Delete temporary credentials"
    echo "   $ rm $SECRETS_FILE"
    echo ""
    echo "Step 4️⃣  - Test release build"
    echo "   $ git tag -a v1.0.0 -m 'Test release'"
    echo "   $ git push origin v1.0.0"
    echo ""
    echo -e "${RED}⚠️  DO NOT COMMIT FILES:${NC}"
    echo "   - $KEYSTORE_FILE"
    echo "   - $SECRETS_FILE"
    echo ""
    echo -e "${GREEN}📚 For more details, see: $README_FILE${NC}"
    echo ""
}

# Main execution
main() {
    clear
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  🔐 VibeApp Production Keystore Generator v1.0               ║${NC}"
    echo -e "${BLUE}║     Production-Grade APK Signing Certificate                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check if keystore already exists
    if [ -f "$KEYSTORE_FILE" ]; then
        echo -e "${YELLOW}⚠️  Warning: $KEYSTORE_FILE already exists${NC}"
        read -p "Do you want to regenerate it? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Aborted${NC}"
            exit 0
        fi
        rm -f "$KEYSTORE_FILE"
    fi
    
    # Execute generation steps
    check_requirements
    generate_passwords
    create_keystore
    display_keystore_info
    encode_to_base64
    create_secrets_file
    create_documentation
    create_backup_prompt
    print_summary
}

# Run main function
main "$@"
