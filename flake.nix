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
            ];

            shellHook = ''
              export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
              export ANDROID_HOME=$ANDROID_SDK_ROOT

              flutter config --android-sdk $ANDROID_SDK_ROOT

              flutter config --no-analytics

              echo "SDK: $ANDROID_SDK_ROOT"
              flutter --version
            '';
          };
      }
    );
}
