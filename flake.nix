{
  description = "Uchan Music - a native music streaming client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      forEachSystem =
        fn:
        lib.genAttrs lib.systems.flakeExposed (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ (import rust-overlay) ];
            };
          in
          fn pkgs
        );

      release = {
        version = "0.39.0";
        assets = {
          x86_64-linux = {
            target = "x86_64-unknown-linux-gnu";
            hash = "sha256-8F62YAO47qJg2Vb49Hy4Ub+oUp5xiOV3s5A4yaIP4IE=";
          };
          aarch64-linux = {
            target = "aarch64-unknown-linux-gnu";
            hash = "sha256-qJrGw09li3B3HpkipN6aDkEuU7oQ6CTZ3z+PDiB9ESA=";
          };
          aarch64-darwin = {
            target = "macos";
            hash = "sha256-ejQfGmupW/07Xc+eYkYKZj0C2jKLmCgZSqdebZhbB/o=";
          };
        };
      };
    in
    {
      packages = forEachSystem (
        pkgs:
        let
          runtimeLibraries =
            with pkgs;
            if pkgs.stdenv.hostPlatform.isLinux then
              [
                vulkan-loader
                wayland
                libxkbcommon
                libxcb
                libx11
                libxcursor
                libxi
                fontconfig
                freetype
                alsa-lib
                dbus
                sqlite
                webkitgtk_4_1
                glib-networking
              ]
            else
              [ ];

          asset = release.assets.${pkgs.stdenv.hostPlatform.system};

          # WebKit plays a page's media through GStreamer and aborts its web process when no
          # audio sink element exists. The Nix webkitgtk closure carries only core and base, and
          # autoaudiosink lives in good, so the plugin path has to name all three.
          gstPluginPath = pkgs.lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (
            with pkgs.gst_all_1;
            [
              gstreamer
              gst-plugins-base
              gst-plugins-good
            ]
          );

          alsaPluginDirectory = pkgs.symlinkJoin {
            name = "uchan-music-alsa-plugins";
            paths = [
              "${pkgs.pipewire}/lib/alsa-lib"
              "${pkgs.alsa-plugins}/lib/alsa-lib"
            ];
          };

          uchan-music = pkgs.rustPlatform.buildRustPackage (final: {
            pname = "uchan-music";
            inherit ((lib.importTOML (final.src + /Cargo.toml)).workspace.package) version;

            src = ./.;
            cargoLock = {
              lockFile = final.src + /Cargo.lock;
              allowBuiltinFetchGit = true;
            };

            nativeBuildInputs =
              with pkgs;
              lib.flatten [
                cmake
                pkg-config
                (lib.optionals stdenv.hostPlatform.isLinux [
                  autoPatchelfHook
                  mold
                ])
                (lib.optionals stdenv.hostPlatform.isDarwin [
                  (
                    let
                      pkgs' = import nixpkgs {
                        inherit (stdenv.hostPlatform) system;
                        config.allowUnfree = true;
                      };
                    in
                    runCommandLocal "metal-shader-compiler" { } ''
                      mkdir -p "$out/bin"
                      ln -s ${pkgs'.darwin.xcode}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/metal "$out/bin/metal"
                      ln -s ${pkgs'.darwin.xcode}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/metallib "$out/bin/metallib"
                    ''
                  )
                ])
              ];
            buildInputs =
              with pkgs;
              lib.flatten [
                sqlite
                (lib.optionals stdenv.hostPlatform.isLinux [
                  dbus
                  fontconfig
                  libxcb
                  libxkbcommon
                  libX11
                  pipewire
                  stdenv.cc.cc.lib
                  (alsa-lib-with-plugins.override {
                    plugins = [
                      alsa-plugins
                      pipewire
                    ];
                  })
                ])
                (lib.optionals stdenv.hostPlatform.isDarwin [
                  apple-sdk_15
                  (darwinMinVersionHook "10.15")
                ])
              ];
            runtimeDependencies =
              with pkgs;
              lib.optionals stdenv.hostPlatform.isLinux [
                vulkan-loader
                wayland
              ];

            installPhase = ''
              runHook preInstall

              install -Dm755 target/release/uchan-music "$out/bin/uchan-music"
              ${
                if pkgs.stdenv.hostPlatform.isDarwin then
                  ''
                    install -Dm755 target/release/uchan-music "$out/Applications/Uchan Music.app/Contents/MacOS/uchan-music"
                    install -Dm444 "$src/assets/macos/uchan-music.icns" \
                      "$out/Applications/Uchan Music.app/Contents/Resources/uchan-music.icns"

                    sed \
                      "s/@VERSION@/$version/g" \
                      "$src/assets/macos/Info.plist" \
                      > "$out/Applications/Uchan Music.app/Contents/Info.plist"

                    LICENSE_DIR="$out/Applications/Uchan Music.app/Contents/Resources"
                  ''
                else
                  ''
                    install -Dm444 "$src/assets/linux/uchan-music.desktop" \
                      "$out/share/applications/uchan-music.desktop"
                    install -Dm444 "$src/assets/linux/uchan-music.svg" \
                      "$out/share/icons/hicolor/scalable/apps/uchan-music.svg"
                    for icon in "$src"/assets/linux/icons/hicolor/*/apps/uchan-music.png; do
                      size="$(basename "$(dirname "$(dirname "$icon")")")"
                      install -Dm444 "$icon" \
                        "$out/share/icons/hicolor/$size/apps/uchan-music.png"
                    done

                    LICENSE_DIR="$out/share/licenses/uchan-music"
                  ''
              }
              install -Dm444 "$src/COPYING" "$LICENSE_DIR/LICENSE"
              install -Dm444 "$src/THIRD-PARTY.md" "$LICENSE_DIR/THIRD-PARTY.md"
              install -Dm444 "$src/assets/fonts/LICENSE.txt" \
                "$LICENSE_DIR/uchan-music/LICENSE.Inter"
              for licence in "$src/assets/icons"/*/LICENSE; do
                pack="$(basename "$(dirname "$licence")")"
                install -Dm444 "$licence" \
                  "$LICENSE_DIR/icons/LICENSE.$pack"
              done
              install -Dm444 "$src/assets/icons/LICENSE" \
                "$LICENSE_DIR/icons/LICENSE"

              runHook postInstall
            '';

            inherit (uchan-music-bin) meta;
          });

          uchan-music-bin = pkgs.stdenv.mkDerivation {
            pname = "uchan-music-bin";
            inherit (release) version;

            src = pkgs.fetchurl {
              url = "https://github.com/sonorahq/sonora/releases/download/v${release.version}/sonora-v${release.version}-${asset.target}${
                if pkgs.stdenv.hostPlatform.isDarwin then ".dmg" else ""
              }";
              inherit (asset) hash;
            };

            dontUnpack = true;
            dontStrip = true;

            nativeBuildInputs =
              lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.makeWrapper ]
              ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
                pkgs.makeBinaryWrapper
                pkgs.undmg
              ];

            installPhase =
              if pkgs.stdenv.hostPlatform.isLinux then
                ''
                  runHook preInstall
                  install -Dm755 "$src" "$out/bin/uchan-music"
                  install -Dm444 ${./assets/linux/uchan-music.desktop} \
                    "$out/share/applications/uchan-music.desktop"
                  install -Dm444 ${./assets/linux/uchan-music.svg} \
                    "$out/share/icons/hicolor/scalable/apps/uchan-music.svg"
                  for icon in ${./assets/linux/icons}/hicolor/*/apps/uchan-music.png; do
                    size="$(basename "$(dirname "$(dirname "$icon")")")"
                    install -Dm444 "$icon" \
                      "$out/share/icons/hicolor/$size/apps/uchan-music.png"
                  done
                  install -Dm444 ${./COPYING} "$out/share/licenses/uchan-music/LICENSE"
                  install -Dm444 ${./THIRD-PARTY.md} "$out/share/licenses/uchan-music/THIRD-PARTY.md"
                  install -Dm444 ${./assets/fonts/LICENSE.txt} \
                    "$out/share/licenses/uchan-music/LICENSE.Inter"
                  for licence in ${./assets/icons}/*/LICENSE; do
                    pack="$(basename "$(dirname "$licence")")"
                    install -Dm444 "$licence" \
                      "$out/share/licenses/uchan-music/icons/LICENSE.$pack"
                  done
                  install -Dm444 ${./assets/icons/LICENSE} \
                    "$out/share/licenses/uchan-music/icons/LICENSE"
                  runHook postInstall
                ''
              else
                ''
                  runHook preInstall
                  mnt="$(mktemp -d)"
                  /usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$mnt" "$src"
                  mkdir -p "$out/Applications" "$out/bin"
                  cp -R "$mnt/Uchan Music.app" "$out/Applications/Uchan Music.app"
                  /usr/bin/hdiutil detach "$mnt"
                  makeBinaryWrapper \
                    "$out/Applications/Uchan Music.app/Contents/MacOS/uchan-music" \
                    "$out/bin/uchan-music"
                  runHook postInstall
                '';

            postFixup = lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
              patchelf \
                --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" \
                --add-rpath "${lib.makeLibraryPath (runtimeLibraries ++ [ pkgs.stdenv.cc.cc.lib ])}" \
                "$out/bin/uchan-music"
              wrapProgram "$out/bin/uchan-music" \
                --set ALSA_PLUGIN_DIR ${alsaPluginDirectory} \
                --prefix GIO_EXTRA_MODULES : ${pkgs.glib-networking}/lib/gio/modules \
                --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${gstPluginPath}
            '';

            meta = {
              description = "A native music streaming client, built with Rust and GPUI";
              mainProgram = "uchan-music";
              license = with lib.licenses; [
                gpl3Plus
                ofl
                isc
              ];
              platforms = lib.platforms.linux ++ lib.platforms.darwin;
            };
          };
        in
        {
          inherit uchan-music;
          default = uchan-music;
        }
        // lib.optionalAttrs (builtins.hasAttr pkgs.stdenv.hostPlatform.system release.assets) {
          inherit uchan-music-bin;
          uchan-music = uchan-music-bin;
          default = uchan-music-bin;
        }
      );

      devShells = forEachSystem (
        pkgs:
        let
          rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          runtimeLibraries =
            with pkgs;
            if pkgs.stdenv.hostPlatform.isLinux then
              [
                vulkan-loader
                wayland
                libxkbcommon
                libxcb
                libx11
                libxcursor
                libxi
                fontconfig
                freetype
                alsa-lib
                dbus
                sqlite
                openssl
                webkitgtk_4_1
                glib-networking
              ]
            else
              [ ];
          # Apple's own xcrun, so `xcrun metal` can reach the Metal toolchain that
          # Xcode 26 mounts outside DEVELOPER_DIR. The xcbuild shim the Apple SDK
          # drags onto PATH cannot, and neither can any xcrun pointed at the Nix SDK.
          xcodeXcrun = pkgs.runCommandLocal "xcode-xcrun" { } ''
            mkdir -p $out/bin
            ln -s /usr/bin/xcrun $out/bin/xcrun
          '';
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs =
              (with pkgs; [
                pkg-config
                cmake
                rustToolchain
                sccache
              ])
              ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.mold ];

            buildInputs = runtimeLibraries;

            LD_LIBRARY_PATH = lib.makeLibraryPath runtimeLibraries;

            ALSA_PLUGIN_DIR =
              if pkgs.stdenv.hostPlatform.isLinux then
                "${pkgs.symlinkJoin {
                  name = "alsa-plugins-combined";
                  paths = [
                    "${pkgs.alsa-plugins}/lib/alsa-lib"
                    "${pkgs.pipewire}/lib/alsa-lib"
                  ];
                }}"
              else
                "";

            shellHook =
              # WebKit composites through EGL, which has to find the same drivers.
              pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                if [ ! -d /run/opengl-driver ]; then
                  export VK_DRIVER_FILES="${pkgs.mesa}/share/vulkan/icd.d"
                  export VK_IMPLICIT_LAYER_PATH="${pkgs.mesa}/share/vulkan/implicit_layer.d"
                  export __EGL_VENDOR_LIBRARY_DIRS="${pkgs.mesa}/share/glvnd/egl_vendor.d"
                  export LIBGL_DRIVERS_PATH="${pkgs.mesa}/lib/dri"
                  export GBM_BACKENDS_PATH="${pkgs.mesa}/lib/gbm"
                fi
                export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules''${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"
                export GST_PLUGIN_SYSTEM_PATH_1_0="${
                  pkgs.lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (
                    with pkgs.gst_all_1;
                    [
                      gstreamer
                      gst-plugins-base
                      gst-plugins-good
                    ]
                  )
                }''${GST_PLUGIN_SYSTEM_PATH_1_0:+:$GST_PLUGIN_SYSTEM_PATH_1_0}"
              ''
              # gpui_apple compiles its shaders with `xcrun -sdk macosx metal` at build
              # time. The Nix Apple SDK has no Metal toolchain, so hand xcrun back to the
              # installed Xcode. Clang follows DEVELOPER_DIR too and then reads Xcode's C
              # headers beside the Nix libc++, which breaks any C++ a build script compiles,
              # so C++ compiles are pinned to the Nix SDK through CXXFLAGS. Only compiles: the
              # link still has to see Xcode's SDK, which is where libsqlite3 comes from.
              + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
                # xcode-select echoes DEVELOPER_DIR back when it is set, so ask with it unset.
                if xcode="$(env -u DEVELOPER_DIR /usr/bin/xcode-select -p 2>/dev/null)"; then
                  export DEVELOPER_DIR="$xcode"
                  export PATH="${xcodeXcrun}/bin:$PATH"
                  export CXXFLAGS="''${CXXFLAGS:-} -isysroot $SDKROOT"
                fi
              '';
          };
        }
      );

      overlays.default = final: _prev: {
        uchan-music = self.packages.${final.stdenv.hostPlatform.system}.default;
      };

      homeManagerModules = {
        default = import ./nix/modules/hm-module.nix self;
        uchan-music = import ./nix/modules/hm-module.nix self;
      };

      homeModules = self.homeManagerModules;
    };
}
