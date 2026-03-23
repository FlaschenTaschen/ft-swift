#!/bin/bash

# build.sh - Build script for FlaschenTaschen macOS FT server
# Usage: ./build.sh [clean|build|test|all] [debug|release]

set -e  # Exit on any error

# Configuration
PROJECT_NAME="FlaschenTaschen"
PROJECT_FILE="FlaschenTaschen.xcodeproj"
SCHEME_NAME="FlaschenTaschen"

# Default values
CONFIGURATION="debug"
ACTION=""
FORCE_REBUILD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [ACTION] [CONFIGURATION] [OPTIONS]"
    echo ""
    echo "Actions:"
    echo "  clean      - Clean build artifacts"
    echo "  build      - Build the project"
    echo "  test       - Run tests (if available)"
    echo "  all        - Clean and build (default)"
    echo "  install    - Build and install binary to \$HOME/bin/"
    echo "  archive    - Create a zip archive of the project (excludes build folders)"
    echo "  run        - Build and run the command-line tool"
    echo ""
    echo "Configurations:"
    echo "  debug      - Debug build (default)"
    echo "  release    - Release build"
    echo ""
    echo "Options:"
    echo "  --force    - Force rebuild even if binary is up-to-date (install action only)"
    echo ""
    echo "Examples:"
    echo "  $0 all                # Clean and build in debug mode"
    echo "  $0 build release      # Build in release mode"
    echo "  $0 clean              # Clean build artifacts"
    echo "  $0 install            # Build and install to \$HOME/bin/"
    echo "  $0 install --force    # Force rebuild and install"
    echo "  $0 run                # Build and run the tool"
    echo "  $0 archive            # Create project archive"
}

# Function to get destination and configuration
get_destination() {
    echo "platform=macOS,arch=arm64"
}

get_configuration() {
    if [ "$CONFIGURATION" = "release" ]; then
        echo "Release"
    else
        echo "Debug"
    fi
}

# Function to clean the project
clean_project() {
    print_status "Cleaning project..."
    
    local destination=$(get_destination)
    local config=$(get_configuration)
    
    # Clean the build directory
    if [ -d "build" ]; then
        rm -rf build
        print_status "Removed local build directory"
    fi
    
    xcodebuild clean \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -destination "$destination" \
        -configuration "$config" \
        SYMROOT="$(pwd)/build" \
        CONFIGURATION_BUILD_DIR="$(pwd)/build/$config" \
        -quiet
    
    print_success "Project cleaned successfully"
}

# Function to build the project
build_project() {
    print_status "Building project for macOS ($CONFIGURATION)..."
    
    local destination=$(get_destination)
    local config=$(get_configuration)
    
    # Create build directory if it doesn't exist
    mkdir -p "build/$config"
    
    # Show progress for release builds (they take longer)
    if [ "$config" = "Release" ]; then
        print_status "Release builds include dependency compilation and may take 2-3 minutes..."
        print_status "Progress: Compiling dependencies and project..."
    fi
    
    xcodebuild build \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -destination "$destination" \
        -configuration "$config" \
        SYMROOT="$(pwd)/build" \
        CONFIGURATION_BUILD_DIR="$(pwd)/build/$config" \
        -quiet
    
    print_success "Project built successfully"
    
    # Show where the binary was created
    local binary_path="build/$config/$PROJECT_NAME"
    if [ -f "$binary_path" ]; then
        print_success "Binary created at: $binary_path"
        
        # Show binary size for release builds
        if [ "$config" = "Release" ]; then
            local size=$(du -h "$binary_path" | cut -f1)
            print_status "Release binary size: $size"
        fi
    else
        print_warning "Binary not found at expected location: $binary_path"
    fi
}

# Function to run tests
test_project() {
    print_status "Running tests..."
    
    local destination=$(get_destination)
    local config=$(get_configuration)
    
    # Run tests; propagate failure (do not swallow stderr — needed for real diagnostics)
    if xcodebuild test \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -destination "$destination" \
        -configuration "$config"; then
        print_success "Tests completed successfully"
    else
        print_error "Tests failed or xcodebuild test exited with an error"
        exit 1
    fi
}

# Function to run the built executable
run_project() {
    print_status "Building and running $PROJECT_NAME..."
    
    # Build first
    build_project
    
    # Find and run the executable
    local config=$(get_configuration)
    local executable_path="build/$config/$PROJECT_NAME"
    
    if [ -f "$executable_path" ]; then
        print_status "Running executable: $executable_path"
        "$executable_path"
    else
        print_error "Could not find built executable at: $executable_path"
        print_status "Make sure the build completed successfully"
        exit 1
    fi
}

# Function to install the built executable
install_project() {
    print_status "Installing $PROJECT_NAME to \$HOME/bin/..."
    
    local executable_path="build/Release/$PROJECT_NAME"
    local install_name="FlaschenTaschen"
    local install_path="$HOME/bin/$install_name"
    
    # Check if release binary already exists and is recent
    local skip_build=false
    if [ "$FORCE_REBUILD" = true ]; then
        print_status "Force rebuild requested..."
    elif [ -f "$executable_path" ]; then
        local binary_age=$(stat -f "%m" "$executable_path" 2>/dev/null || echo "0")
        local source_newest=$(find Sources/ FlaschenTaschen/ -name "*.swift" -exec stat -f "%m" {} \; 2>/dev/null | sort -nr | head -1 || echo "0")
        
        if [ "$binary_age" -gt "$source_newest" ]; then
            print_status "Release binary is up-to-date, skipping build..."
            skip_build=true
        fi
    fi
    
    # Build only if needed (release mode for install)
    if [ "$skip_build" = false ]; then
        print_status "Building in release mode (this may take a few minutes for dependencies)..."
        local original_config="$CONFIGURATION"
        CONFIGURATION="release"
        build_project
        CONFIGURATION="$original_config"
    fi
    
    if [ ! -f "$executable_path" ]; then
        print_error "Could not find built executable at: $executable_path"
        print_status "Make sure the build completed successfully"
        exit 1
    fi
    
    # Create $HOME/bin if it doesn't exist
    if [ ! -d "$HOME/bin" ]; then
        print_status "Creating $HOME/bin directory..."
        mkdir -p "$HOME/bin"
    fi
    
    # Copy the executable
    print_status "Copying $executable_path to $install_path..."
    cp "$executable_path" "$install_path"
    
    # Make it executable
    chmod +x "$install_path"
    
    print_success "Successfully installed $install_name to $HOME/bin/"
    print_status "You can now run the tool from anywhere using: $install_name"
    
    # Check if $HOME/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        print_warning "$HOME/bin is not in your PATH"
        print_status "Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        print_status "  export PATH=\"\$HOME/bin:\$PATH\""
    fi
}

# Function to create project archive
archive_project() {
    print_status "Creating project archive..."
    
    # Use folder name for archive name
    local parent_dir=$(dirname "$(pwd)")
    local current_dir=$(basename "$(pwd)")
    local archive_name="${current_dir}.zip"
    
    print_status "Archive name: $archive_name"
    print_status "Archive location: $parent_dir/$archive_name"
    print_status "Excluding build folders and user-specific files..."
    
    # Create archive from parent directory to include the project folder
    cd "$parent_dir"
    
    # Create zip with exclusions for build artifacts and user-specific files
    zip -r "$archive_name" "$current_dir" \
        -x "*/build/*" \
        -x "*/.build/*" \
        -x "*/DerivedData/*" \
        -x "*/xcuserdata/*" \
        -x "*/*.xcuserstate" \
        -x "*/*.xcuserdatad/*" \
        -x "*/.DS_Store" \
        -x "*/Pods/*" \
        -x "*/Carthage/Build/*" \
        -x "*/fastlane/report.xml" \
        -x "*/fastlane/Preview.html" \
        -x "*/fastlane/screenshots" \
        -x "*/fastlane/test_output" \
        -x "*/.swiftpm/*" \
        -x "*/Package.resolved" \
        -x "*/*.dSYM/*" \
        -x "*/.coverage.lcov" \
        -x "*/.coverage/*" \
        -x "*/coverage/*" \
        -x "*/.nyc_output/*" \
        -x "*/*.log" \
        -x "*/.vscode/*" \
        -x "*/.idea/*" \
        -x "*/*.tmp" \
        -x "*/*.temp" \
        -x "*/*.cache" \
        -x "*/.env" \
        -x "*/.env.local" \
        --quiet
    
    # Stay in parent directory - don't move the archive
    cd "$current_dir"
    
    # Get archive size
    local archive_size=$(du -h "$parent_dir/$archive_name" | cut -f1)
    
    print_success "Archive created successfully: $archive_name"
    print_success "Archive location: $parent_dir/$archive_name"
    print_success "Archive size: $archive_size"
    print_status "Archive includes:"
    print_status "  ✓ Source code files"
    print_status "  ✓ Project configuration"
    print_status "  ✓ Documentation"
    print_status "  ✓ Git history (.git folder)"
    print_status "  ✓ Assets and resources"
    print_status "Archive excludes:"
    print_status "  ✗ Build artifacts (build/, .build/)"
    print_status "  ✗ User-specific files (xcuserdata/, .DS_Store)"
    print_status "  ✗ Dependency caches (Pods/, Carthage/Build/)"
    print_status "  ✗ Temporary and log files"
}

# Function to check if Xcode project exists
check_project_exists() {
    if [ ! -d "$PROJECT_FILE" ]; then
        print_error "Xcode project '$PROJECT_FILE' not found in current directory"
        exit 1
    fi
}

# Function to check if xcodebuild is available
check_xcodebuild() {
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild command not found. Please install Xcode Command Line Tools."
        exit 1
    fi
}

# Function to check if zip is available
check_zip() {
    if ! command -v zip &> /dev/null; then
        print_error "zip command not found. Please install zip utility."
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        clean|build|test|all|install|archive|run)
            ACTION="$1"
            shift
            ;;
        debug|release)
            CONFIGURATION="$1"
            shift
            ;;
        --force)
            FORCE_REBUILD=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    # Check if no action was provided
    if [ -z "$ACTION" ]; then
        print_warning "No action specified."
        show_usage
        exit 1
    fi
    
    print_status "Starting build process for $PROJECT_NAME"
    print_status "Action: $ACTION, Configuration: $CONFIGURATION"
    
    # Perform checks based on action
    if [ "$ACTION" = "archive" ]; then
        check_zip
        check_project_exists
    else
        check_xcodebuild
        check_project_exists
    fi
    
    # Execute requested action
    case $ACTION in
        clean)
            clean_project
            ;;
        build)
            build_project
            ;;
        test)
            test_project
            ;;
        all)
            clean_project
            build_project
            ;;
        install)
            install_project
            ;;
        run)
            run_project
            ;;
        archive)
            archive_project
            ;;
        *)
            print_error "Invalid action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
    
    print_success "Build process completed successfully!"
}

# Check if running in correct directory
if [ ! -f "$PROJECT_FILE/project.pbxproj" ]; then
    print_error "Not in the correct directory. Please run this script from the project root."
    exit 1
fi

# Run main function
main "$@" 