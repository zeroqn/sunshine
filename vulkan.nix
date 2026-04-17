{ pkgs, ... }:

let
  src = pkgs.fetchgit {
    url = "https://github.com/LizardByte/Sunshine.git";
    rev = "5053c1d259dc56e226ae9759121f61883351f298";
    hash = "sha256-19rg6R7axhDh1x6Rzse0KvhIoUPuAVLjMu7/REHZtrk=";
    fetchSubmodules = true;
  };
  version = "2026.04.16.vulkan";
  boostVersion = pkgs.boost.version;
in

pkgs.sunshine.overrideAttrs (old: {
  # Build sunshine from the source in this directory.
  inherit src version;

  ui = pkgs.buildNpmPackage {
    inherit src version;

    pname = "sunshine-ui";
    npmDepsHash = "sha256-Q2XeVJN9C9bQXQEfMriy34bctJHy7Fa7a3aZp+/w+vw=";
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
      --replace-fail '/bin/sleep' '${pkgs.lib.getExe' pkgs.coreutils "sleep"}'
  '';

  buildInputs = old.buildInputs ++ [
    pkgs.vulkan-headers
    pkgs.vulkan-loader
    #pkgs.glslang
    #pkgs.shaderc
  ];

  cmakeFlags = old.cmakeFlags ++ [
    (pkgs.lib.cmakeBool "SUNSHINE_ENABLE_VULKAN" true)
    (pkgs.lib.cmakeFeature "SUNSHINE_EXECUTABLE_PATH" "$out/bin/sunshine")
  ];

  postFixup = pkgs.lib.optionalString true ''
    wrapProgram $out/bin/sunshine \
      --set LD_LIBRARY_PATH ${pkgs.lib.makeLibraryPath [ pkgs.vulkan-loader ]}
  '';

})
