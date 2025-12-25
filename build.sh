#!/bin/bash

# Audiofy Multi-Platform Build Script
# Supports: Linux, Windows, macOS, Android, iOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build configuration
BUILD_TYPE="${BUILD_TYPE:-release}"
OUTPUT_DIR="build/outputs"

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Display help
show_help() {
    cat << EOF
Audiofy Multi-Platform Build Script

Usage: ./build.sh [PLATFORM] [OPTIONS]

PLATFORMS:
    linux       Build for Linux (Debian package)
    windows     Build for Windows (MSIX)
    macos       Build for macOS (DMG)
    android     Build for Android (APK and AAB)
    ios         Build for iOS (requires macOS)
    all         Build for all available platforms
    
OPTIONS:
    --debug     Build in debug mode (default: release)
    --clean     Clean before building
    -h, --help  Show this help message

EXAMPLES:
    ./build.sh linux              # Build Linux package
    ./build.sh android --clean    # Clean and build Android
    ./build.sh all                # Build for all platforms
    BUILD_TYPE=debug ./build.sh linux  # Build Linux in debug mode

EOF
}

# Clean build artifacts
clean_build() {
    print_info "Cleaning build artifacts..."
    flutter clean
    rm -rf build/outputs
    print_success "Clean completed"
}

# Setup environment
setup_env() {
    print_info "Setting up build environment..."
    flutter pub get
    print_success "Dependencies installed"
}

# Create output directory
prepare_output() {
    mkdir -p "${OUTPUT_DIR}"/{linux,windows,macos,android,ios}
}

# Build for Linux
build_linux() {
    print_info "Building for Linux..."
    
    if [[ "$BUILD_TYPE" == "debug" ]]; then
        flutter build linux --debug
    else
        flutter build linux --release
    fi
    
    print_info "Creating Debian package..."
    flutter pub run flutter_to_debian
    
    # Copy outputs
    if [ -d "build/linux/x64/release/bundle" ]; then
        cp -r build/linux/x64/release/bundle "${OUTPUT_DIR}/linux/"
    fi
    
    # Copy .deb if created
    if ls debian/packages/*.deb 1> /dev/null 2>&1; then
        cp debian/packages/*.deb "${OUTPUT_DIR}/linux/" 2>/dev/null || true
    fi
    
    print_success "Linux build completed"
    print_info "Output: ${OUTPUT_DIR}/linux/"
}

# Build for Windows
build_windows() {
    print_info "Building for Windows..."
    
    if [[ "$BUILD_TYPE" == "debug" ]]; then
        flutter build windows --debug
    else
        flutter build windows --release
    fi
    
    # Copy outputs
    if [ -d "build/windows/x64/runner/Release" ]; then
        cp -r build/windows/x64/runner/Release "${OUTPUT_DIR}/windows/audiofy"
        
        # Create a simple zip archive
        if command -v zip &> /dev/null; then
            cd "${OUTPUT_DIR}/windows"
            zip -r "audiofy-windows-${BUILD_TYPE}.zip" audiofy/
            cd - > /dev/null
            print_success "Created Windows archive"
        fi
    elif [ -d "build/windows/runner/Release" ]; then
        cp -r build/windows/runner/Release "${OUTPUT_DIR}/windows/audiofy"
    fi
    
    print_success "Windows build completed"
    print_info "Output: ${OUTPUT_DIR}/windows/"
}

# Build for macOS
build_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "macOS builds require macOS. Skipping..."
        return 1
    fi
    
    print_info "Building for macOS..."
    
    if [[ "$BUILD_TYPE" == "debug" ]]; then
        flutter build macos --debug
    else
        flutter build macos --release
    fi
    
    # Copy outputs
    if [ -d "build/macos/Build/Products/Release/audiofy.app" ]; then
        cp -r build/macos/Build/Products/Release/audiofy.app "${OUTPUT_DIR}/macos/"
        
        # Create DMG if possible
        if command -v create-dmg &> /dev/null; then
            create-dmg \
                --volname "Audiofy Installer" \
                --window-pos 200 120 \
                --window-size 600 400 \
                "${OUTPUT_DIR}/macos/audiofy-${BUILD_TYPE}.dmg" \
                "${OUTPUT_DIR}/macos/audiofy.app"
            print_success "Created DMG installer"
        fi
    fi
    
    print_success "macOS build completed"
    print_info "Output: ${OUTPUT_DIR}/macos/"
}

# Build for Android
build_android() {
    print_info "Building for Android..."
    
    # Build APK
    if [[ "$BUILD_TYPE" == "debug" ]]; then
        flutter build apk --debug
    else
        flutter build apk --release
        # Also build app bundle for Play Store
        flutter build appbundle --release
    fi
    
    # Copy outputs
    if [ -f "build/app/outputs/flutter-apk/app-${BUILD_TYPE}.apk" ]; then
        cp build/app/outputs/flutter-apk/app-${BUILD_TYPE}.apk \
            "${OUTPUT_DIR}/android/audiofy-${BUILD_TYPE}.apk"
    fi
    
    if [ -f "build/app/outputs/bundle/${BUILD_TYPE}/app-${BUILD_TYPE}.aab" ]; then
        cp build/app/outputs/bundle/${BUILD_TYPE}/app-${BUILD_TYPE}.aab \
            "${OUTPUT_DIR}/android/audiofy-${BUILD_TYPE}.aab"
    fi
    
    print_success "Android build completed"
    print_info "Output: ${OUTPUT_DIR}/android/"
}

# Build for iOS
build_ios() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "iOS builds require macOS. Skipping..."
        return 1
    fi
    
    print_info "Building for iOS..."
    
    if [[ "$BUILD_TYPE" == "debug" ]]; then
        flutter build ios --debug --no-codesign
    else
        flutter build ios --release --no-codesign
    fi
    
    # Copy outputs
    if [ -d "build/ios/iphoneos/Runner.app" ]; then
        cp -r build/ios/iphoneos/Runner.app "${OUTPUT_DIR}/ios/"
    fi
    
    print_success "iOS build completed"
    print_info "Output: ${OUTPUT_DIR}/ios/"
    print_warning "Note: iOS builds require code signing for distribution"
}

# Build all platforms
build_all() {
    print_info "Building for all available platforms..."
    
    local failed_builds=()
    
    # Try each platform
    build_linux || failed_builds+=("linux")
    build_windows || failed_builds+=("windows")
    build_macos || failed_builds+=("macos")
    build_android || failed_builds+=("android")
    build_ios || failed_builds+=("ios")
    
    echo ""
    print_success "Build process completed"
    
    if [ ${#failed_builds[@]} -gt 0 ]; then
        print_warning "Some builds were skipped or failed: ${failed_builds[*]}"
    fi
}

# Main script
main() {
    local platform=""
    local should_clean=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --debug)
                BUILD_TYPE="debug"
                shift
                ;;
            --clean)
                should_clean=true
                shift
                ;;
            linux|windows|macos|android|ios|all)
                platform="$1"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # If no platform specified, show help
    if [ -z "$platform" ]; then
        show_help
        exit 1
    fi
    
    # Print build configuration
    echo ""
    print_info "Audiofy Build Script"
    print_info "Platform: ${platform}"
    print_info "Build Type: ${BUILD_TYPE}"
    echo ""
    
    # Clean if requested
    if [ "$should_clean" = true ]; then
        clean_build
    fi
    
    # Setup environment
    setup_env
    
    # Prepare output directory
    prepare_output
    
    # Build for specified platform
    case $platform in
        linux)
            build_linux
            ;;
        windows)
            build_windows
            ;;
        macos)
            build_macos
            ;;
        android)
            build_android
            ;;
        ios)
            build_ios
            ;;
        all)
            build_all
            ;;
    esac
    
    echo ""
    print_success "All done! 🎉"
    print_info "Build artifacts are in: ${OUTPUT_DIR}"
}

# Run main function
main "$@"
