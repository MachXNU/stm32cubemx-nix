{
  stdenv,
  lib,
  requireFile,
  makeWrapper,
  unzip,
  jre,
  autoPatchelfHook,
  patchelf,
  coreutils,
  findutils,
  bash,
  proot,
  less,
  gnugrep,
  gnused,
  file,
  auto-patchelf,

  # X11 n friends
  libx11,
  libxext,
  libxrender,
  libxrandr,
  libxcursor,
  libxfixes,
  libxi,
  libxtst,

  libxcb,
  libxcb-util,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-wm,

  # Wayland
  wayland,
  qt6,

  # GL / graphics
  libGL,
  mesa,

  # Core libs
  glib,
  zlib,
  fontconfig,
  freetype,

  # Extras seen in trace
  dbus,

  # Chromium
  gtk3,
  nss,
  nspr,
  alsa-lib,
  cups,
  at-spi2-core,
  pango,
  cairo,
  libdrm,
  libgbm,
}:

stdenv.mkDerivation rec {
  pname = "stm32cubemx";
  version = "6.17.0";

  dontWrapQtApps = true;

  autoPatchelfIgnoreMissingDeps = [
    "libQt6WaylandEglClientHwIntegration.so.6"

    # FFmpeg junk (multiple incompatible ABIs)
    "libavcodec.so"
    "libavcodec.so.54"
    "libavcodec.so.56"
    "libavcodec.so.57"
    "libavcodec.so.58"
    "libavcodec.so.59"
    "libavcodec.so.60"

    "libavformat.so"
    "libavformat.so.54"
    "libavformat.so.56"
    "libavformat.so.57"
    "libavformat.so.58"
    "libavformat.so.59"
    "libavformat.so.60"

    "libavcodec-ffmpeg.so.56"
    "libavformat-ffmpeg.so.56"

    "libasound.so.2"
  ];

  src = requireFile {
    name = "stm32cubemx-lin-v6-17-0.zip";
    url = "https://www.st.com/en/development-tools/stm32cubemx.html";
    sha256 = "sha256-mXEratSn145g08Fs/8UpvW13IRo4HJyl3Sv/jBEBJkg=";
  };

  nativeBuildInputs = [
    makeWrapper
    unzip
    jre
    autoPatchelfHook
    patchelf
    coreutils
    findutils
    bash
    proot
    less
    gnugrep
    gnused
    file
    auto-patchelf
  ];

  buildInputs = [
    stdenv.cc.cc.lib

    # X11
    libx11
    libxext
    libxrender
    libxrandr
    libxcursor
    libxfixes
    libxi
    libxtst

    # XCB
    libxcb
    libxcb-util
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm

    # Wayland
    wayland
    qt6.qtbase
    qt6.qtwayland

    # GL
    libGL
    mesa

    # Core
    glib
    zlib
    fontconfig
    freetype
    dbus

    # Chromium
    gtk3
    nss
    nspr
    alsa-lib
    cups
    at-spi2-core
    pango
    cairo
    libdrm
    libgbm
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    cd source
    unzip $src
    cd ..
    runHook postUnpack
  '';

  postUnpack = ''
    cd source

    chmod -R u+w .

    find jre -type f | while read f; do
      if file "$f" | grep -q "ELF"; then

        if file "$f" | grep -q "executable"; then
          echo "patching executable $f"

          patchelf \
          --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
          --set-rpath "\$ORIGIN/../lib:${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
          "$f"

        else
          echo "patching library $f"

          patchelf \
            --set-rpath "\$ORIGIN/../lib:${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
            "$f"

        fi

      fi
    done

    pwd
    ls

    chmod +x SetupSTM32CubeMX-${version}

    cd ..
  '';

  installPhase = ''
        cd source

        export HOME=$PWD/fake-home
        mkdir -p $HOME

        # Automated install config
        cat > install.xml <<EOF
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <AutomatedInstallation langpack="eng">
      <com.st.microxplorer.install.MXHTMLHelloPanel id="readme"/>
      <com.st.microxplorer.install.MXLicensePanel id="licence.panel"/>
      <com.st.microxplorer.install.MXAnalyticsPanel id="analytics.panel"/>
      <com.st.microxplorer.install.MXTargetPanel id="target.panel">
        <installpath>/install-root</installpath>
      </com.st.microxplorer.install.MXTargetPanel>
      <com.st.microxplorer.install.MXShortcutPanel id="shortcut.panel"/>
      <com.st.microxplorer.install.MXInstallPanel id="install.panel"/>
      <com.st.microxplorer.install.MXFinishPanel id="finish.panel"/>
    </AutomatedInstallation>
    EOF

        pwd
        ls
        chmod +x SetupSTM32CubeMX-${version}
        
        export INSTALL4J_JAVA_HOME=$PWD/jre
        export JAVA_HOME=$PWD/jre
        export PATH=$PWD/jre/bin:${coreutils}/bin:${bash}/bin:${proot}/bin:${stdenv.cc.cc.lib}/bin

        mkdir -p $PWD/bin

        ln -sf ${coreutils}/bin/* $PWD/bin/
        ln -sf ${bash}/bin/bash $PWD/bin/bash
        ln -sf ${bash}/bin/sh $PWD/bin/sh

        proot \
          --bind=/nix \
          --rootfs=$PWD \
          --cwd=/ \
          ${bash}/bin/bash -c 'export PATH=/bin:/usr/bin; export LD_LIBRARY_PATH=/jre/lib ; /jre/bin/java -jar SetupSTM32CubeMX-${version} install.xml'

        # Fixing permissions
        chmod -R u+rwX install-root

        # Move installed files into $out
        mkdir -p $out/opt
        cp -r install-root/* $out/opt/

        # Create wrapper
        mkdir -p $out/bin
        makeWrapper $out/opt/STM32CubeMX $out/bin/stm32cubemx \
          --chdir $out/opt \
          --set QT_QPA_PLATFORM wayland \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}
  '';

  preFixup = ''
    export PATH=${
      lib.makeBinPath [
        coreutils
        findutils
        bash
        patchelf
        gnugrep
        gnused
        file
        auto-patchelf
      ]
    }:$PATH
  '';

  postFixup = ''
    # Fixing RPATHs
    JRE_LIB="$out/opt/jre/lib"

    find $out/opt/jre -type f | while read f; do
      if file "$f" | grep -q ELF; then
        echo "Fixing RPATH for $f"

        patchelf \
          --set-rpath "$JRE_LIB:${lib.makeLibraryPath buildInputs}" \
          "$f" || true
      fi
    done
  '';

  meta = with lib; {
    description = "STM32CubeMX graphical configuration tool for STM32";
    homepage = "https://www.st.com/en/development-tools/stm32cubemx.html";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
