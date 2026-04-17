{ pkgs, ... }:

let
  src = pkgs.fetchgit {
    url = "https://github.com/LizardByte/Sunshine.git";
    rev = "5053c1d259dc56e226ae9759121f61883351f298";
    hash = "sha256-19rg6R7axhDh1x6Rzse0KvhIoUPuAVLjMu7/REHZtrk=";
    fetchSubmodules = true;
  };
  version = "2026.04.16.vulkan";
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

  buildInputs = old.buildInputs ++ [
    pkgs.boost189
    pkgs.vulkan-headers
    pkgs.vulkan-loader
    #pkgs.glslang
    #pkgs.shaderc
  ];

  cmakeFlags = old.cmakeFlags ++ [
    (pkgs.lib.cmakeBool "SUNSHINE_ENABLE_VULKAN" true)
  ];

  postFixup = pkgs.lib.optionalString true ''
    wrapProgram $out/bin/sunshine \
      --set LD_LIBRARY_PATH ${pkgs.lib.makeLibraryPath [ pkgs.vulkan-loader ]}
  '';

})
