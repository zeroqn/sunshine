{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchgit,
  autoconf,
  automake,
  cmake,
  freetype,
  git,
  gnutls,
  gnumake,
  lame,
  libass,
  libdrm,
  libopus,
  libtool,
  libx11,
  libxcb,
  libxfixes,
  meson,
  nasm,
  numactl,
  pkg-config,
  SDL2,
  texinfo,
  wayland,
  wget,
  zlib,
}:

let
  buildDepsRev = "2844f04e89d2c4814cc7ebb2f2494cd62c8734ac";
  buildDepsSrc = fetchgit {
    url = "https://github.com/LizardByte/build-deps.git";
    rev = buildDepsRev;
    hash = "sha256-FE2DRalNwsfPpq85Nx1SXScQbK8My+W+SMHN332uNFU=";
    fetchSubmodules = true;
  };

  libvaSrc = fetchFromGitHub {
    owner = "intel";
    repo = "libva";
    rev = "2.23.0";
    hash = "sha256-ePtzZPzBnkhV0cV3Nw/pgOnKnzDkk7U2Svzo0e1YMbc=";
  };
in
stdenv.mkDerivation {
  pname = "sunshine-build-deps";
  version = "2026.04.17-master";
  src = buildDepsSrc;

  strictDeps = true;

  nativeBuildInputs = [
    autoconf
    automake
    cmake
    git
    gnumake
    libtool
    meson
    nasm
    pkg-config
    texinfo
    wget
  ];

  buildInputs = [
    SDL2
    freetype
    gnutls
    lame
    libass
    libdrm
    libopus
    libx11
    libxcb
    libxfixes
    numactl
    wayland
    zlib
  ];

  postPatch = ''
    cp -r ${libvaSrc} third-party/local-libva

    # Nix builds are offline and fetchgit strips VCS metadata, so the upstream
    # opportunistic tag refresh fails before CMake can configure FFmpeg.
    sed -i '/^foreach(repo "x265_git" "SVT-AV1")$/,/^endforeach()$/d' \
      cmake/ffmpeg/_main.cmake

    substituteInPlace cmake/ffmpeg/libva.cmake \
      --replace-fail 'CPMGetPackage(libva)' "" \
      --replace-fail 'set(LIBVA_GENERATED_SRC_PATH ''${libva_SOURCE_DIR})' \
                     'set(LIBVA_GENERATED_SRC_PATH ''${CMAKE_CURRENT_SOURCE_DIR}/third-party/local-libva)'
  '';

  cmakeFlags = [
    (lib.cmakeBool "BUILD_ALL" false)
    (lib.cmakeBool "BUILD_BOOST" false)
    (lib.cmakeBool "BUILD_FFMPEG" true)
  ];

  enableParallelBuilding = true;

  meta = {
    description = "Pinned LizardByte build-deps FFmpeg bundle for Sunshine";
    homepage = "https://github.com/LizardByte/build-deps";
    platforms = lib.platforms.linux;
  };
}
