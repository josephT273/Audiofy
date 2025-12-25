.PHONY: all clean build deb

# Default target
all: clean build deb

# Clean the project
clean:
	flutter clean

# Build the Linux release version
build:
	flutter pub get
	flutter build linux --release

# Create the Debian package
deb:
	flutter pub run flutter_to_debian
