{ lib, fetchurl, stdenvNoCC }:

let
  releaseTag = "v2026.516.30821";
  platformAssets = {
    x86_64-linux = {
      name = "Linux-x86_64-ffmpeg.tar.gz";
      hash = "sha256-wyMZ/MKGe+/o/zria006WDeMOpwb/vkCnJlpMhw7xuw=";
    };
    aarch64-linux = {
      name = "Linux-aarch64-ffmpeg.tar.gz";
      hash = "sha256-ELbJRAumF47DuUT2xvaXJTSXytUZbSOi0y0zXargBi4=";
    };
  };
  system = stdenvNoCC.hostPlatform.system;
  platformAsset =
    platformAssets.${system}
      or (throw "No prebuilt FFmpeg asset configured for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "sunshine-prebuilt-ffmpeg";
  version = releaseTag;

  src = fetchurl {
    url = "https://github.com/LizardByte/build-deps/releases/download/${releaseTag}/${platformAsset.name}";
    inherit (platformAsset) hash;
  };

  dontConfigure = true;
  dontBuild = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R ffmpeg "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Prebuilt LizardByte FFmpeg bundle for Sunshine";
    homepage = "https://github.com/LizardByte/build-deps/releases/tag/${releaseTag}";
    platforms = builtins.attrNames platformAssets;
  };
}
