{ lib, fetchurl, stdenvNoCC, releaseAsset }:

stdenvNoCC.mkDerivation {
  pname = "sunshine";
  inherit (releaseAsset) version;

  src = fetchurl {
    inherit (releaseAsset) url hash;
  };

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack

    mkdir source
    tar --extract --gzip --file "$src" --directory source

    runHook postUnpack
  '';

  sourceRoot = "source";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a . "$out"/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Prebuilt Sunshine bundle fetched from GitHub releases";
    homepage = "https://github.com/${releaseAsset.owner}/${releaseAsset.repo}/releases/tag/${releaseAsset.tag}";
    license = licenses.gpl3Only;
    mainProgram = "sunshine";
    platforms = [ releaseAsset.system ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
