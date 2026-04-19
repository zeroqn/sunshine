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
  libxau,
  libxcb,
  libxdmcp,
  libxext,
  libxfixes,
  libxrandr,
  libxrender,
  meson,
  nasm,
  numactl,
  pkg-config,
  SDL2,
  texinfo,
  wayland,
  wayland-scanner,
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
    (lib.getBin wayland-scanner)
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
    libxau
    libxcb
    libxdmcp
    libxext
    libxfixes
    libxrandr
    libxrender
    numactl
    wayland
    (lib.getDev wayland-scanner)
    zlib
  ];

  postPatch = ''
    cp -r ${libvaSrc} third-party/local-libva
    # Sources copied from the Nix store keep their read-only modes, but libva's
    # autogen.sh needs to create m4/ and autom4te.cache in-place.
    chmod -R u+w third-party/local-libva

    # Nix builds are offline and fetchgit strips VCS metadata, so the upstream
    # opportunistic tag refresh fails before CMake can configure FFmpeg.
    sed -i '/^foreach(repo "x265_git" "SVT-AV1")$/,/^endforeach()$/d' \
      cmake/ffmpeg/_main.cmake

    substituteInPlace cmake/ffmpeg/libva.cmake \
      --replace-fail 'CPMGetPackage(libva)' "" \
      --replace-fail 'set(LIBVA_GENERATED_SRC_PATH ''${libva_SOURCE_DIR})' \
                     'set(LIBVA_GENERATED_SRC_PATH ''${CMAKE_CURRENT_SOURCE_DIR}/third-party/local-libva)' \
      --replace-fail '        --enable-x11' '        --disable-x11' \
      --replace-fail '        --enable-glx' '        --disable-glx' \
      --replace-fail '"''${CMAKE_CURRENT_BINARY_DIR}/libva/lib/libva-x11.a"' "" \
      --replace-fail '"''${CMAKE_CURRENT_BINARY_DIR}/libva/lib/libva-glx.a"' ""

    substituteInPlace cmake/ffmpeg/x264.cmake \
      --replace-fail 'COMMAND ''${SHELL_CMD} "''${MAKE_COMPILER_FLAGS} ./configure \' \
                     'COMMAND ''${SHELL_CMD} "AS=${lib.getBin nasm}/bin/nasm ''${MAKE_COMPILER_FLAGS} ./configure \'

    substituteInPlace cmake/ffmpeg/svt_av1.cmake \
      --replace-fail '# PKG_CONFIG_PATH already set since this is installed directly to the prefix' \
                     'set(PKG_CONFIG_PATH "''${_original_cmake_install_prefix}/lib/pkgconfig:''${PKG_CONFIG_PATH}")'

    substituteInPlace cmake/ffmpeg/ffmpeg.cmake \
      --replace-fail 'set(WORKING_DIR "''${FFMPEG_GENERATED_SRC_PATH}")' \
                     'set(PKG_CONFIG_PATH "''${_original_cmake_install_prefix}/lib/pkgconfig:''${PKG_CONFIG_PATH}")\nset(WORKING_DIR "''${FFMPEG_GENERATED_SRC_PATH}")'
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
