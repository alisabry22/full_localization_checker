#!/bin/bash

# Flutter Localization Checker - Git Hook Installer
# This script installs the pre-commit hook for automatic localization checking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Default configuration
ENABLE_LOCALIZATION_CHECK=true
BLOCK_ON_ISSUES=false
AUTO_CONVERT=false
AUTO_GENERATE_ARB=false
VERBOSE=false

# Display header
display_header() {
    echo ""
    echo "🌍 Flutter Localization Checker - Git Hook Installer"
    echo "======================================================"
    echo ""
}

# Check if we're in a Git repository
check_git_repo() {
    if [ ! -d ".git" ]; then
        log_error "Not a Git repository. Please run this script from the root of your Git repository."
        exit 1
    fi
    log_info "Git repository detected"
}

# Check if we're in a Flutter project
check_flutter_project() {
    if [ ! -f "pubspec.yaml" ]; then
        log_warn "pubspec.yaml not found. This might not be a Flutter project."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled."
            exit 0
        fi
    else
        log_info "Flutter project detected"
    fi
}

# Interactive configuration
configure_hook() {
    echo ""
    log_info "Configuring Git pre-commit hook..."
    echo ""
    
    # Enable localization check
    read -p "Enable localization checking in pre-commit hook? (Y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_LOCALIZATION_CHECK=false
    fi
    
    if [ "$ENABLE_LOCALIZATION_CHECK" = true ]; then
        # Block on issues
        read -p "Block commits when localization issues are found? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            BLOCK_ON_ISSUES=true
        fi
        
        # Auto-convert
        read -p "Automatically convert strings to localization calls? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            AUTO_CONVERT=true
        fi
        
        # Auto-generate ARB
        read -p "Automatically generate ARB files when issues are found? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            AUTO_GENERATE_ARB=true
        fi
        
        # Verbose output
        read -p "Enable verbose output? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            VERBOSE=true
        fi
    fi
}

# Install the pre-commit hook
install_hook() {
    local hooks_dir=".git/hooks"
    local hook_file="$hooks_dir/pre-commit"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local source_hook="$script_dir/pre-commit"
    
    # Create hooks directory if it doesn't exist
    mkdir -p "$hooks_dir"
    
    # Check if pre-commit hook already exists
    if [ -f "$hook_file" ]; then
        log_warn "Pre-commit hook already exists."
        read -p "Backup existing hook and replace? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            cp "$hook_file" "$hook_file.backup.$(date +%Y%m%d_%H%M%S)"
            log_info "Existing hook backed up"
        else
            log_info "Installation cancelled."
            exit 0
        fi
    fi
    
    # Copy and customize the hook
    if [ -f "$source_hook" ]; then
        cp "$source_hook" "$hook_file"
    else
        log_error "Source pre-commit hook not found at: $source_hook"
        exit 1
    fi
    
    # Make the hook executable
    chmod +x "$hook_file"
    
    # Configure the hook with user preferences
    configure_hook_file "$hook_file"
    
    log_success "Pre-commit hook installed successfully!"
}

# Configure the hook file with user preferences
configure_hook_file() {
    local hook_file="$1"
    
    # Update configuration variables in the hook file
    sed -i.bak \
        -e "s/ENABLE_LOCALIZATION_CHECK=\${ENABLE_LOCALIZATION_CHECK:-true}/ENABLE_LOCALIZATION_CHECK=\${ENABLE_LOCALIZATION_CHECK:-$ENABLE_LOCALIZATION_CHECK}/" \
        -e "s/BLOCK_ON_ISSUES=\${BLOCK_ON_ISSUES:-false}/BLOCK_ON_ISSUES=\${BLOCK_ON_ISSUES:-$BLOCK_ON_ISSUES}/" \
        -e "s/AUTO_CONVERT=\${AUTO_CONVERT:-false}/AUTO_CONVERT=\${AUTO_CONVERT:-$AUTO_CONVERT}/" \
        -e "s/AUTO_GENERATE_ARB=\${AUTO_GENERATE_ARB:-false}/AUTO_GENERATE_ARB=\${AUTO_GENERATE_ARB:-$AUTO_GENERATE_ARB}/" \
        -e "s/VERBOSE=\${VERBOSE:-false}/VERBOSE=\${VERBOSE:-$VERBOSE}/" \
        "$hook_file"
    
    # Remove backup file
    rm -f "$hook_file.bak"
    
    log_info "Hook configured with your preferences"
}

# Add loc_checker to pubspec.yaml if needed
setup_loc_checker() {
    if [ -f "pubspec.yaml" ] && ! grep -q "loc_checker:" pubspec.yaml; then
        log_info "Adding loc_checker to pubspec.yaml..."
        
        # Check if dev_dependencies section exists
        if ! grep -q "dev_dependencies:" pubspec.yaml; then
            echo "" >> pubspec.yaml
            echo "dev_dependencies:" >> pubspec.yaml
            echo "  flutter_test:" >> pubspec.yaml
            echo "    sdk: flutter" >> pubspec.yaml
        fi
        
        # Add loc_checker
        sed -i.bak '/dev_dependencies:/a\
  loc_checker: ^1.0.0' pubspec.yaml
        rm -f pubspec.yaml.bak
        
        log_success "Added loc_checker to pubspec.yaml"
        
        # Ask to run pub get
        read -p "Run 'dart pub get' now? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            dart pub get
            log_success "Dependencies updated"
        fi
    fi
}

# Create configuration file
create_config_file() {
    local config_file=".loc_checker_config"
    
    cat > "$config_file" << EOF
# Flutter Localization Checker Configuration
# This file contains default settings for the Git pre-commit hook
# You can override these by setting environment variables

# Enable/disable localization checking
ENABLE_LOCALIZATION_CHECK=$ENABLE_LOCALIZATION_CHECK

# Block commits when issues are found
BLOCK_ON_ISSUES=$BLOCK_ON_ISSUES

# Automatically convert strings to localization calls
AUTO_CONVERT=$AUTO_CONVERT

# Automatically generate ARB files
AUTO_GENERATE_ARB=$AUTO_GENERATE_ARB

# Enable verbose output
VERBOSE=$VERBOSE

# Additional configuration
ARB_OUTPUT_DIR="lib/l10n"
TARGET_LANGUAGES="es,fr,de,it"
EXCLUDE_DIRS="build,.dart_tool,.git,node_modules"

# Usage:
# To temporarily override settings, use environment variables:
# BLOCK_ON_ISSUES=true git commit -m "message"
EOF
    
    log_info "Created configuration file: $config_file"
}

# Display usage instructions
show_usage_instructions() {
    echo ""
    log_success "🎉 Installation completed!"
    echo ""
    echo "📋 Configuration Summary:"
    echo "  - Localization checking: $ENABLE_LOCALIZATION_CHECK"
    echo "  - Block on issues: $BLOCK_ON_ISSUES"
    echo "  - Auto-convert: $AUTO_CONVERT"
    echo "  - Auto-generate ARB: $AUTO_GENERATE_ARB"
    echo "  - Verbose output: $VERBOSE"
    echo ""
    echo "🔧 How to use:"
    echo "  The pre-commit hook will automatically run when you commit changes."
    echo "  It will check staged Dart files for localization issues."
    echo ""
    echo "⚙️  To modify settings:"
    echo "  - Edit .loc_checker_config file"
    echo "  - Or use environment variables:"
    echo "    BLOCK_ON_ISSUES=true git commit -m 'message'"
    echo ""
    echo "🛠️  Useful commands:"
    echo "  - Manual check: dart run loc_checker"
    echo "  - Convert all: dart run loc_checker --convert-all"
    echo "  - Generate ARB: dart run loc_checker --generate-arb"
    echo ""
    echo "❌ To disable temporarily:"
    echo "  ENABLE_LOCALIZATION_CHECK=false git commit -m 'message'"
    echo ""
    echo "🗑️  To uninstall:"
    echo "  rm .git/hooks/pre-commit"
    echo ""
}

# Uninstall function
uninstall_hook() {
    local hook_file=".git/hooks/pre-commit"
    
    if [ -f "$hook_file" ]; then
        # Check if it's our hook
        if grep -q "Flutter Localization Checker" "$hook_file"; then
            rm "$hook_file"
            log_success "Pre-commit hook uninstalled"
            
            # Remove config file
            if [ -f ".loc_checker_config" ]; then
                rm ".loc_checker_config"
                log_info "Configuration file removed"
            fi
        else
            log_warn "Pre-commit hook exists but doesn't appear to be our localization hook"
            log_warn "Please remove manually if needed: $hook_file"
        fi
    else
        log_info "No pre-commit hook found"
    fi
}

# Main function
main() {
    case "${1:-install}" in
        "install")
            display_header
            check_git_repo
            check_flutter_project
            configure_hook
            install_hook
            setup_loc_checker
            create_config_file
            show_usage_instructions
            ;;
        "uninstall")
            display_header
            check_git_repo
            uninstall_hook
            ;;
        "help"|"-h"|"--help")
            echo "Flutter Localization Checker - Git Hook Installer"
            echo ""
            echo "Usage:"
            echo "  $0 [command]"
            echo ""
            echo "Commands:"
            echo "  install    Install the pre-commit hook (default)"
            echo "  uninstall  Remove the pre-commit hook"
            echo "  help       Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage instructions"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 