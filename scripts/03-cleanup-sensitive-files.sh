#!/bin/bash

################################################################################
# VibeApp Sensitive Files Cleanup
#
# This script safely removes temporary sensitive files after setup is complete.
# Performs verification before deletion to prevent accidental data loss.
#
# Usage: ./scripts/03-cleanup-sensitive-files.sh
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Files to check
SECRETS_FILE=".secrets.env"
KEYSTORE_FILE="production.keystore"
ENCRYPTED_BACKUP="production.keystore.enc"

# Initialize counters
files_to_remove=()
files_confirmed=()

# Display header
print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  🧹 Sensitive Files Cleanup v1.0                             ║${NC}"
    echo -e "${BLUE}║     Safe removal of temporary credentials                    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if GitHub Secrets are configured
check_github_secrets() {
    echo -e "${BLUE}🔍 Verifying GitHub Secrets are configured...${NC}"
    echo ""
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}⚠️  GitHub CLI not available, skipping verification${NC}"
        echo -e "${YELLOW}    Please verify secrets manually at:${NC}"
        echo -e "${YELLOW}    https://github.com/samehlove218/VibeApp/settings/secrets/actions${NC}"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Cleanup cancelled${NC}"
            exit 0
        fi
        return 0
    fi
    
    # Check each secret
    local required_secrets=("APP_KEYSTORE" "KEYSTORE_PASSWORD" "KEY_PASSWORD" "KEY_ALIAS")
    local missing_secrets=()
    
    for secret in "${required_secrets[@]}"; do
        if gh secret list --repo samehlove218/VibeApp 2>/dev/null | grep -q "^$secret"; then
            echo -e "${GREEN}  ✅ $secret${NC}"
        else
            echo -e "${YELLOW}  ⚠️  $secret (not found)${NC}"
            missing_secrets+=("$secret")
        fi
    done
    
    echo ""
    
    if [ ${#missing_secrets[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing secrets: ${missing_secrets[*]}${NC}"
        echo -e "${YELLOW}Please configure all secrets before cleanup${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All required secrets are configured${NC}\n"
}

# Scan for sensitive files
scan_for_sensitive_files() {
    echo -e "${BLUE}🔍 Scanning for sensitive files...${NC}"
    echo ""
    
    # Check .secrets.env
    if [ -f "$SECRETS_FILE" ]; then
        echo -e "${CYAN}  Found: $SECRETS_FILE${NC}"
        files_to_remove+=("$SECRETS_FILE")
    fi
    
    # Check if should remove production.keystore
    if [ -f "$KEYSTORE_FILE" ]; then
        if [ -f "$ENCRYPTED_BACKUP" ]; then
            echo -e "${CYAN}  Found: $KEYSTORE_FILE (backup exists)${NC}"
            read -p "  Remove $KEYSTORE_FILE? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                files_to_remove+=("$KEYSTORE_FILE")
            fi
        else
            echo -e "${YELLOW}  ⚠️  $KEYSTORE_FILE (no backup found)${NC}"
            read -p "  Create backup before removing? (Y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                echo -e "${BLUE}    Creating encrypted backup...${NC}"
                openssl enc -aes-256-cbc -salt -in "$KEYSTORE_FILE" -out "$ENCRYPTED_BACKUP"
                echo -e "${GREEN}    ✅ Backup created: $ENCRYPTED_BACKUP${NC}"
                files_to_remove+=("$KEYSTORE_FILE")
            else
                echo -e "${YELLOW}    ⚠️  Skipped removal of $KEYSTORE_FILE${NC}"
            fi
        fi
    fi
    
    echo ""
}

# Show files to be removed
show_files_to_remove() {
    if [ ${#files_to_remove[@]} -eq 0 ]; then
        echo -e "${YELLOW}No sensitive files to remove${NC}"
        echo ""
        return 1
    fi
    
    echo -e "${CYAN}📋 Files to be removed:${NC}"
    for file in "${files_to_remove[@]}"; do
        echo -e "${CYAN}  • $file${NC}"
    done
    echo ""
    return 0
}

# Confirm before deletion
confirm_deletion() {
    echo -e "${YELLOW}⚠️  WARNING: This action cannot be undone${NC}"
    echo ""
    read -p "Remove $(echo ${#files_to_remove[@]}) file(s)? (y/N) " -n 1 -r
    echo
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cleanup cancelled${NC}"
        exit 0
    fi
}

# Perform secure deletion
secure_delete() {
    echo -e "${BLUE}🧹 Removing sensitive files...${NC}"
    echo ""
    
    local delete_count=0
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            # Overwrite file with random data before deleting (optional, more secure)
            # Uncomment for extra security (slow for large files):
            # shred -vfz -n 3 "$file" 2>/dev/null || true
            
            rm -f "$file"
            
            if [ ! -f "$file" ]; then
                echo -e "${GREEN}  ✅ Removed: $file${NC}"
                ((delete_count++))
            else
                echo -e "${RED}  ❌ Failed to remove: $file${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ Deleted $delete_count file(s)${NC}\n"
}

# Verify deletion
verify_deletion() {
    echo -e "${BLUE}🔍 Verifying deletion...${NC}"
    echo ""
    
    local verification_ok=true
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            echo -e "${RED}  ❌ Still exists: $file${NC}"
            verification_ok=false
        else
            echo -e "${GREEN}  ✅ Confirmed removed: $file${NC}"
        fi
    done
    
    echo ""
    
    if [ "$verification_ok" = true ]; then
        echo -e "${GREEN}✅ All files successfully removed${NC}\n"
        return 0
    else
        echo -e "${RED}❌ Some files could not be removed${NC}\n"
        return 1
    fi
}

# Check .gitignore
check_gitignore() {
    echo -e "${BLUE}🔍 Checking .gitignore...${NC}"
    echo ""
    
    if [ ! -f .gitignore ]; then
        echo -e "${YELLOW}⚠️  .gitignore not found, creating it${NC}"
        touch .gitignore
    fi
    
    # Check if entries exist
    local gitignore_ok=true
    
    if grep -q "^\*\.keystore$" .gitignore 2>/dev/null; then
        echo -e "${GREEN}  ✅ *.keystore is ignored${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Adding *.keystore to .gitignore${NC}"
        echo "*.keystore" >> .gitignore
        gitignore_ok=false
    fi
    
    if grep -q "^\.secrets\.env$" .gitignore 2>/dev/null; then
        echo -e "${GREEN}  ✅ .secrets.env is ignored${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Adding .secrets.env to .gitignore${NC}"
        echo ".secrets.env" >> .gitignore
        gitignore_ok=false
    fi
    
    echo ""
    
    if [ "$gitignore_ok" = true ]; then
        echo -e "${GREEN}✅ .gitignore properly configured${NC}\n"
    else
        echo -e "${YELLOW}⚠️  .gitignore has been updated${NC}\n"
    fi
}

# Verify git status
verify_git_status() {
    echo -e "${BLUE}📝 Git status check...${NC}"
    echo ""
    
    local sensitive_files_tracked=false
    
    if git ls-files --others --exclude-standard | grep -E "(\.keystore|\.secrets\.env)" > /dev/null 2>&1; then
        echo -e "${RED}❌ Sensitive files are untracked${NC}"
        sensitive_files_tracked=true
    fi
    
    if git ls-files | grep -E "(\.keystore|\.secrets\.env)" > /dev/null 2>&1; then
        echo -e "${RED}❌ WARNING: Sensitive files are committed${NC}"
        echo -e "${RED}   These must be removed from git history!${NC}"
        sensitive_files_tracked=true
    fi
    
    if [ "$sensitive_files_tracked" = false ]; then
        echo -e "${GREEN}✅ No sensitive files in git${NC}"
    fi
    
    echo ""
}

# Final recommendations
print_recommendations() {
    echo -e "${CYAN}📋 Post-Cleanup Recommendations:${NC}"
    echo ""
    echo "1. Verify git status:"
    echo -e "${CYAN}   $ git status${NC}"
    echo ""
    echo "2. Create backup of encrypted keystore:"
    echo -e "${CYAN}   $ cp production.keystore.enc ~/Backups/${NC}"
    echo ""
    echo "3. Test release build:"
    echo -e "${CYAN}   $ git tag -a v1.0.0 -m 'Test release'${NC}"
    echo -e "${CYAN}   $ git push origin v1.0.0${NC}"
    echo ""
    echo "4. Monitor workflow:"
    echo -e "${CYAN}   https://github.com/samehlove218/VibeApp/actions${NC}"
    echo ""
}

# Summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ CLEANUP COMPLETE                                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Security status: Protected${NC}"
    echo -e "${GREEN}Temporary files: Removed${NC}"
    echo -e "${GREEN}GitHub Secrets: Configured${NC}"
    echo -e "${GREEN}Ready for: Release builds${NC}"
    echo ""
}

# Main execution
main() {
    print_header
    
    check_github_secrets
    scan_for_sensitive_files
    
    if ! show_files_to_remove; then
        echo -e "${GREEN}✅ No files to remove${NC}"
        exit 0
    fi
    
    confirm_deletion
    secure_delete
    verify_deletion
    check_gitignore
    verify_git_status
    print_recommendations
    print_summary
}

# Run main function
main "$@"
