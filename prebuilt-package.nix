{
  lib,
  fetchurl,
  stdenvNoCC,
  autoPatchelfHook,
  makeWrapper,
  releaseAsset,
  runtimeDeps ? [ ],
}:

stdenvNoCC.mkDerivation {
  pname = "sunshine";
  inherit (releaseAsset) version;

  src = fetchurl {
    inherit (releaseAsset) url hash;
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = map lib.getLib runtimeDeps;

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

    # Release artifacts are produced from a Nix source build, so bin/sunshine
    # is already a wrapper with absolute paths to the builder's output. Replace
    # it with a wrapper for this package output instead of preserving stale
    # /nix/store references from the publishing machine.
    chmod u+w "$out/bin" "$out/bin/sunshine"
    rm "$out/bin/sunshine"
    makeWrapper "$out/bin/.sunshine-wrapped" "$out/bin/sunshine" \
      --inherit-argv0

    # Upstream bundles both share/systemd/user and a compatibility symlink at
    # lib/systemd/user -> ../../share/systemd/user. Nix's systemd hook later
    # migrates lib/systemd/user into share/systemd/user, which makes it try to
    # move files onto themselves. Drop only that redundant symlink copy here and
    # keep the canonical share/systemd/user payload intact.
    if [ -L "$out/lib/systemd/user" ] \
      && [ "$(readlink -f "$out/lib/systemd/user")" = "$out/share/systemd/user" ]; then
      chmod u+w "$out/lib/systemd"
      rm "$out/lib/systemd/user"
      rmdir "$out/lib/systemd" 2>/dev/null || true
    fi

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
