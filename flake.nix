{
  description = "Flutter development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        # Android SDKの構成
        buildToolsVersion = "34.0.0";
        androidComposition = pkgs.androidenv.composeAndroidPackages {
          buildToolsVersions = [
            "35.0.0"
            buildToolsVersion
            "30.0.3"
            "28.0.3"
          ];
          platformVersions = [
            "36"
            "35"
            "34"
            "33"
            "30"
          ];
          abiVersions = [
            "armeabi-v7a"
            "arm64-v8a"
            "x86_64"
          ];
          ndkVersions = ["28.2.13676358"];
          cmakeVersions = ["3.22.1"];
          includeEmulator = true;
          includeSystemImages = true;
          systemImageTypes = ["google_apis_playstore"];
          includeNDK = true;
        };

        androidSdk = androidComposition.androidsdk;
      in
      {
        devShell =
          with pkgs;
          mkShell rec {
            ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
            ANDROID_HOME = ANDROID_SDK_ROOT;
            JAVA_HOME = jdk17.home;
            CHROME_EXECUTABLE = "${chromium}/bin/chromium";

            buildInputs = [
              flutter
              androidSdk
              jdk17

              # Web
              chromium

              # Linux
              pkg-config
              gtk3

              # Android emulator host GPU: libGL.so.1 dispatcher + Vulkan loader
              libglvnd
              vulkan-loader
            ];

            shellHook = ''
              export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
              export ANDROID_HOME=$ANDROID_SDK_ROOT

              # Fix TLS certificate issues for workerd (Cloudflare Workers)
              export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
              export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

              # Android emulator GPU acceleration on NixOS.
              # - libglvnd provides libGL.so.1 (dispatcher); /run/opengl-driver/lib has the mesa driver impl.
              # - vulkan-loader provides libvulkan.so.1; XDG_DATA_DIRS lets it discover the mesa Vulkan ICDs.
              # Without these the emulator falls back to swiftshader software rendering (~10 fps).
              export LD_LIBRARY_PATH="${libglvnd}/lib:${vulkan-loader}/lib:/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              export XDG_DATA_DIRS="/run/opengl-driver/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

              flutter config --android-sdk $ANDROID_SDK_ROOT

              flutter config --no-analytics

              echo "SDK: $ANDROID_SDK_ROOT"
              flutter --version
            '';
          };
      }
    );
}
