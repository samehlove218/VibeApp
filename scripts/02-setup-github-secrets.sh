#!/bin/bash

################################################################################
# VibeApp GitHub Secrets Configuration
#
# This script automatically configures GitHub Secrets using the GitHub CLI.
# Requires: GitHub CLI (gh) and authentication
#
# Usage: ./scripts/02-setup-github-secrets.sh
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
SECRETS_FILE=".secrets.env"
REPO="samehlove218/VibeApp"

# Check GitHub CLI
check_gh_cli() {
    echo -e "${BLUE}🔍 Checking GitHub CLI...${NC}"
    
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI (gh) not installed${NC}"
        echo -e "${YELLOW}Install: brew install gh (macOS) or apt-get install gh (Linux)${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ GitHub CLI found${NC}\n"
}

# Check authentication
check_authentication() {
    echo -e "${BLUE}🔍 Checking GitHub authentication...${NC}"
    
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ Not authenticated with GitHub${NC}"
        echo -e "${YELLOW}Run: gh auth login${NC}"
        exit 1
    fi
    
    # Get authenticated user
    USER=$(gh api user -q '.login')
    echo -e "${GREEN}✅ Authenticated as: $USER${NC}\n"
}

# Check secrets file exists
check_secrets_file() {
    echo -e "${BLUE}🔍 Checking secrets file...${NC}"
    
    if [ ! -f "$SECRETS_FILE" ]; then
        echo -e "${RED}❌ Secrets file not found: $SECRETS_FILE${NC}"
        echo -e "${YELLOW}Run: ./scripts/01-generate-production-keystore.sh${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Secrets file found${NC}\n"
}

# Load secrets from file
load_secrets() {
    echo -e "${BLUE}📥 Loading secrets from configuration...${NC}"
    
    # Source the secrets file (but don't export them to environment)
    source "$SECRETS_FILE"
    
    # Validate all required variables are set
    if [ -z "${APP_KEYSTORE_BASE64:-}" ]; then
        echo -e "${RED}❌ APP_KEYSTORE_BASE64 not found in $SECRETS_FILE${NC}"
        exit 1
    fi
    
    if [ -z "${KEYSTORE_PASSWORD:-}" ]; then
        echo -e "${RED}❌ KEYSTORE_PASSWORD not found in $SECRETS_FILE${NC}"
        exit 1
    fi
    
    if [ -z "${KEY_PASSWORD:-}" ]; then
        echo -e "${RED}❌ KEY_PASSWORD not found in $SECRETS_FILE${NC}"
        exit 1
    fi
    
    if [ -z "${KEY_ALIAS:-}" ]; then
        # Try to extract from file if not set
        if [ -f "production.keystore" ]; then
            KEY_ALIAS=$(keytool -list -keystore production.keystore -storepass "$KEYSTORE_PASSWORD" -storetype PKCS12 2>/dev/null | grep "Entry type" | head -1 | awk '{print $6}' || echo "vibeapp-prod-key")
        else
            echo -e "${RED}❌ KEY_ALIAS not found${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ Secrets loaded successfully${NC}\n"
}

# Set GitHub secret
set_secret() {
    local secret_name="$1"
    local secret_value="$2"
    
    echo -e "${CYAN}  Setting: $secret_name${NC}"
    
    if gh secret set "$secret_name" --body "$secret_value" --repo "$REPO" 2>/dev/null; then
        echo -e "${GREEN}    ✅ Success${NC}"
        return 0
    else
        echo -e "${RED}    ❌ Failed${NC}"
        return 1
    fi
}

# Configure all secrets
configure_secrets() {
    echo -e "${BLUE}📤 Configuring GitHub Secrets...${NC}"
    echo ""
    
    local failures=0
    
    # Set each secret
    if ! set_secret "APP_KEYSTORE" "$APP_KEYSTORE_BASE64"; then
        ((failures++))
    fi
    
    if ! set_secret "KEYSTORE_PASSWORD" "$KEYSTORE_PASSWORD"; then
        ((failures++))
    fi
    
    if ! set_secret "KEY_PASSWORD" "$KEY_PASSWORD"; then
        ((failures++))
    fi
    
    if ! set_secret "KEY_ALIAS" "$KEY_ALIAS"; then
        ((failures++))
    fi
    
    echo ""
    
    if [ $failures -eq 0 ]; then
        echo -e "${GREEN}✅ All secrets configured successfully${NC}\n"
        return 0
    else
        echo -e "${RED}❌ $failures secret(s) failed to configure${NC}\n"
        return 1
    fi
}

# Verify secrets were set
verify_secrets() {
    echo -e "${BLUE}🔍 Verifying secrets configuration...${NC}"
    echo ""
    
    local secrets_ok=true
    
    for secret_name in APP_KEYSTORE KEYSTORE_PASSWORD KEY_PASSWORD KEY_ALIAS; do
        echo -e "${CYAN}  Checking: $secret_name${NC}"
        
        if gh secret list --repo "$REPO" 2>/dev/null | grep -q "^$secret_name"; then
            echo -e "${GREEN}    ✅ Configured${NC}"
        else
            echo -e "${RED}    ❌ Not found${NC}"
            secrets_ok=false
        fi
    done
    
    echo ""
    
    if [ "$secrets_ok" = true ]; then
        echo -e "${GREEN}✅ All secrets verified${NC}\n"
        return 0
    else
        echo -e "${RED}❌ Some secrets are missing${NC}\n"
        return 1
    fi
}

# Display verification link
display_verification_link() {
    echo -e "${BLUE}📋 Verification Link${NC}"
    echo ""
    echo -e "${CYAN}  View configured secrets:${NC}"
    echo -e "${CYAN}  https://github.com/$REPO/settings/secrets/actions${NC}"
    echo ""
}

# Security recommendations
print_security_reminder() {
    echo -e "${YELLOW}⚠️  Security Reminders${NC}"
    echo ""
    echo "1. Delete temporary files:"
    echo -e "${CYAN}   $ rm .secrets.env${NC}"
    echo ""
    echo "2. Backup keystore securely:"
    echo -e "${CYAN}   $ openssl enc -aes-256-cbc -salt -in production.keystore -out production.keystore.enc${NC}"
    echo ""
    echo "3. Never commit keystore or secrets:"
    echo -e "${CYAN}   $ echo '*.keystore' >> .gitignore${NC}"
    echo -e "${CYAN}   $ echo '.secrets.env' >> .gitignore${NC}"
    echo ""
    echo "4. Verify .gitignore is up to date:"
    echo -e "${CYAN}   $ git status${NC}"
    echo ""
}

# Summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ GITHUB SECRETS CONFIGURATION COMPLETE                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📊 Configured Secrets:${NC}"
    echo -e "${CYAN}  • APP_KEYSTORE${NC}"
    echo -e "${CYAN}  • KEYSTORE_PASSWORD${NC}"
    echo -e "${CYAN}  • KEY_PASSWORD${NC}"
    echo -e "${CYAN}  • KEY_ALIAS${NC}"
    echo ""
    print_security_reminder
    display_verification_link
}

# Main execution
main() {
    clear
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  🔐 GitHub Secrets Configuration v1.0                        ║${NC}"
    echo -e "${BLUE}║     Configure repository secrets for CI/CD pipeline          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Execute configuration steps
    check_gh_cli
    check_authentication
    check_secrets_file
    load_secrets
    configure_secrets
    verify_secrets
    print_summary
}

# Run main function
main "$@"
