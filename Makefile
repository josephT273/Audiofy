.PHONY: help all clean deps linux windows macos android ios deb

# Default target
all: help

# Show help
help:
	@echo "Audiofy Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help      - Show this help message"
	@echo "  clean     - Clean build artifacts"
	@echo "  deps      - Install dependencies"
	@echo "  linux     - Build for Linux and create .deb package"
	@echo "  windows   - Build for Windows"
	@echo "  macos     - Build for macOS (requires macOS)"
	@echo "  android   - Build Android APK and AAB"
	@echo "  ios       - Build for iOS (requires macOS)"
	@echo "  deb       - Create Debian package only"
	@echo ""
	@echo "Advanced:"
	@echo "  You can also use: ./build.sh [platform] for more options"
	@echo ""

# Clean the project
clean:
	@echo "Cleaning build artifacts..."
	@flutter clean
	@rm -rf build/outputs
	@echo "✓ Clean completed"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	@flutter pub get
	@echo "✓ Dependencies installed"

# Build for Linux
linux: deps
	@echo "Building for Linux..."
	@flutter build linux --release
	@echo "Creating Debian package..."
	@flutter pub run flutter_to_debian
	@echo "✓ Linux build completed"

# Build for Windows
windows: deps
	@echo "Building for Windows..."
	@flutter build windows --release
	@echo "✓ Windows build completed"

# Build for macOS
macos: deps
	@echo "Building for macOS..."
	@flutter build macos --release
	@echo "✓ macOS build completed"

# Build for Android
android: deps
	@echo "Building for Android..."
	@flutter build apk --release
	@flutter build appbundle --release
	@echo "✓ Android build completed"

# Build for iOS
ios: deps
	@echo "Building for iOS..."
	@flutter build ios --release --no-codesign
	@echo "✓ iOS build completed"

# Create Debian package only
deb:
	@echo "Creating Debian package..."
	@flutter pub run flutter_to_debian
	@echo "✓ Debian package created"

# Build everything (where possible)
build-all: clean linux windows android
	@echo ""
	@echo "✓ Multi-platform build completed"
	@echo "Note: macOS and iOS require macOS to build"
