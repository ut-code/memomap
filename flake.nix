{
  description = "Flutter development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Pinned to nixos-25.11 for a mesa build compatible with the androidenv
    # emulator's glibc 2.40. Newer mesa (in nixpkgs-unstable) requires
    # GLIBC_ABI_GNU2_TLS from glibc >= 2.41, which the bundled emulator lacks,
    # forcing a fallback to CPU (llvmpipe) Vulkan and breaking GL init.
    nixpkgs-mesa-compat.url = "github:NixOS/nixpkgs/b6018f87da91d19d0ab4cf979885689b469cdd41";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-mesa-compat,
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
        mesaCompat = (import nixpkgs-mesa-compat { inherit system; }).mesa;

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
              # - libglvnd provides libGL.so.1 (dispatcher); mesa-compat has the vendor impls.
              # - vulkan-loader provides libvulkan.so.1.
              # - mesa-compat is pinned to nixos-25.11's mesa (25.2.6, glibc 2.40) so the
              #   Vulkan/GL drivers load in the androidenv emulator process, which is itself
              #   linked against glibc 2.40. System /run/opengl-driver ships a newer mesa
              #   that requires GLIBC_ABI_GNU2_TLS from glibc >= 2.41 → emulator sees only
              #   llvmpipe (software Vulkan) and GL init fails ("Failed to find exactly 1
              #   GLES 2.x config"). Explicitly pointing VK_ICD / EGL vendor lookup at
              #   mesa-compat sidesteps that.
              export LD_LIBRARY_PATH="${mesaCompat}/lib:${libglvnd}/lib:${vulkan-loader}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              export VK_ICD_FILENAMES="${mesaCompat}/share/vulkan/icd.d/radeon_icd.x86_64.json"
              export __EGL_VENDOR_LIBRARY_FILENAMES="${mesaCompat}/share/glvnd/egl_vendor.d/50_mesa.json"
              export XDG_DATA_DIRS="${mesaCompat}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

              flutter config --android-sdk $ANDROID_SDK_ROOT

              flutter config --no-analytics

              echo "SDK: $ANDROID_SDK_ROOT"
              flutter --version
            '';
          };
      }
    );
}
