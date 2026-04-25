{ pkgs, ... }:

let
  buildDeps = pkgs.callPackage ./build-deps.nix { };
  coreutilsForService = pkgs.coreutils.overrideAttrs (_: {
    # Local Nix rebuilds of coreutils can fail an unrelated cp test under this
    # container filesystem. We only need a stable sleep path in the generated
    # user service, so skip coreutils' self-tests for this narrowly-scoped use.
    doCheck = false;
    doInstallCheck = false;
  });
  pythonForGlad = pkgs.python3.withPackages (ps: [
    ps.jinja2
    ps.setuptools
  ]);
  src = pkgs.fetchgit {
    url = "https://github.com/LizardByte/Sunshine.git";
    rev = "5cf5e8c1ceb0a0d3630851a09b19577a96bbe9b8";
    hash = "sha256-z6e8BEEnvLzeh5mE4nR0SDv5NOGnZjJgxljguwFvJuE=";
    fetchSubmodules = true;
  };
  version = "2026.04.23.vulkan";
  boostVersion = pkgs.boost.version;
in

pkgs.sunshine.overrideAttrs (old: {
  # Build sunshine from the source in this directory.
  inherit src version;

  ui = pkgs.buildNpmPackage {
    inherit src version;

    pname = "sunshine-ui";
    npmDepsHash = "sha256-rNLb3vbabQyiM4XBQ5sFZpQ0+YyyJKxeZM0rhjbyP3Y=";
    nodejs = pkgs.nodejs_24;

    # use generated package-lock.json as upstream does not provide one
    postPatch = ''
      cp ${./package-lock.json} ./package-lock.json
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -a . "$out"/

      runHook postInstall
    '';
  };

  postPatch = ''
    substituteInPlace cmake/targets/common.cmake \
      --replace-fail 'find_program(NPM npm REQUIRED)' ""

    sed -i -E 's|set\(BOOST_VERSION "[^"]+"\)|set(BOOST_VERSION "${boostVersion}")|' \
      cmake/dependencies/Boost_Sunshine.cmake
    grep -Fq 'set(BOOST_VERSION "${boostVersion}")' \
      cmake/dependencies/Boost_Sunshine.cmake
    echo 'set(FETCH_CONTENT_BOOST_USED TRUE)' >> cmake/dependencies/Boost_Sunshine.cmake

    substituteInPlace cmake/packaging/linux.cmake \
      --replace-fail 'find_package(Systemd)' "" \
      --replace-fail 'find_package(Udev)' ""

    substituteInPlace packaging/linux/dev.lizardbyte.app.Sunshine.desktop \
      --subst-var-by PROJECT_NAME 'Sunshine' \
      --subst-var-by PROJECT_DESCRIPTION 'Self-hosted game stream host for Moonlight' \
      --subst-var-by SUNSHINE_DESKTOP_ICON 'sunshine' \
      --subst-var-by CMAKE_INSTALL_FULL_DATAROOTDIR "$out/share" \
      --replace-fail 'Exec=/usr/bin/env systemctl start --u app-@PROJECT_FQDN@' 'Exec=sunshine'

    substituteInPlace packaging/linux/app-dev.lizardbyte.app.Sunshine.service.in \
      --replace-fail '/bin/sleep' '${pkgs.lib.getExe' coreutilsForService "sleep"}'

    python <<'PY'
from pathlib import Path

path = Path('src/nvenc/nvenc_base.cpp')
text = path.read_text()
text = text.replace(
    '#if NVENCAPI_VERSION != MAKE_NVENC_VER(12U, 0U)\n  #error Check and update NVENC code for backwards compatibility!\n#endif',
    '#if NVENCAPI_VERSION < MAKE_NVENC_VER(12U, 0U) || NVENCAPI_VERSION > MAKE_NVENC_VER(13U, 0U)\n  #error Check and update NVENC code for backwards compatibility!\n#endif'
)
text = text.replace(
    '          if (buffer_is_10bit()) {\n            format_config.pixelBitDepthMinus8 = 2;\n          }',
    '          if (buffer_is_10bit()) {\n#if NVENCAPI_MAJOR_VERSION >= 13\n            format_config.inputBitDepth = NV_ENC_BIT_DEPTH_10;\n            format_config.outputBitDepth = NV_ENC_BIT_DEPTH_10;\n#else\n            format_config.pixelBitDepthMinus8 = 2;\n#endif\n          }'
)
text = text.replace(
    '          if (buffer_is_10bit()) {\n            format_config.inputPixelBitDepthMinus8 = 2;\n            format_config.pixelBitDepthMinus8 = 2;\n          }',
    '          if (buffer_is_10bit()) {\n#if NVENCAPI_MAJOR_VERSION >= 13\n            format_config.inputBitDepth = NV_ENC_BIT_DEPTH_10;\n            format_config.outputBitDepth = NV_ENC_BIT_DEPTH_10;\n#else\n            format_config.inputPixelBitDepthMinus8 = 2;\n            format_config.pixelBitDepthMinus8 = 2;\n#endif\n          }'
)
path.write_text(text)
PY
  '';

  nativeBuildInputs = [
    pythonForGlad
    pkgs.glslang
  ] ++ old.nativeBuildInputs;

  buildInputs = old.buildInputs ++ [
    pkgs.pipewire
    pkgs.vulkan-headers
    pkgs.vulkan-loader
  ];

  cmakeFlags = old.cmakeFlags ++ [
    (pkgs.lib.cmakeBool "SUNSHINE_ENABLE_VULKAN" true)
    (pkgs.lib.cmakeBool "GLAD_SKIP_PIP_INSTALL" true)
    (pkgs.lib.cmakeFeature "Python_EXECUTABLE" "${pythonForGlad}/bin/python3")
    (pkgs.lib.cmakeFeature "FFMPEG_PREPARED_BINARIES" "${buildDeps}/ffmpeg")
    (pkgs.lib.cmakeFeature "SUNSHINE_EXECUTABLE_PATH" "${placeholder "out"}/bin/sunshine")
    (pkgs.lib.cmakeFeature "SUNSHINE_ASSETS_DIR_DEF" "assets")
    (pkgs.lib.cmakeBool "UDEV_FOUND" true)
    (pkgs.lib.cmakeFeature "UDEV_RULES_INSTALL_DIR" "lib/udev/rules.d")
    (pkgs.lib.cmakeBool "SYSTEMD_FOUND" true)
    (pkgs.lib.cmakeFeature "SYSTEMD_USER_UNIT_INSTALL_DIR" "lib/systemd/user")
    (pkgs.lib.cmakeFeature "SYSTEMD_MODULES_LOAD_DIR" "lib/modules-load.d")
  ];

  postFixup = pkgs.lib.optionalString true ''
    wrapProgram $out/bin/sunshine \
      --chdir "$out" \
      --set LD_LIBRARY_PATH ${pkgs.lib.makeLibraryPath [ pkgs.vulkan-loader ]}
  '';

})
