{ pkgs, buildPackages, stdenv, lib, haskellLib, ghc, buildGHC, fetchurl, writeText, runCommand, pkgconfig, nonReinstallablePkgs, ghcForComponent, hsPkgs }:

{ flags
, package
, components
, cabal-generator

, name
, sha256
, src
, revision
, revisionSha256
, patches

, preUnpack
, postUnpack
, preConfigure
, postConfigure
, preBuild
, postBuild
, preCheck
, postCheck
, preInstall
, postInstall
, preHaddock
, postHaddock

, shellHook

, ...
}@config:

let
  cabalFile = if revision == null || revision == 0 then null else
    fetchurl {
      name = "${name}-${toString revision}.cabal";
      url = "https://hackage.haskell.org/package/${name}/revision/${toString revision}.cabal";
      sha256 = revisionSha256;
    };

  defaultSetupSrc = builtins.toFile "Setup.hs" ''
    import Distribution.Simple
    main = defaultMain
  '';
  defaultSetup = buildPackages.runCommand "default-Setup" { nativeBuildInputs = [buildGHC]; } ''
    cat ${defaultSetupSrc} > Setup.hs
    mkdir -p $out/bin
    ${buildGHC.targetPrefix}ghc Setup.hs --make -o $out/bin/Setup
  '';

  setup = if package.buildType == "Simple"
    then defaultSetup
    else haskellLib.weakCallPackage pkgs ./setup-builder.nix {
      ghc = buildGHC;
      setup-depends = package.setup-depends;
      hsPkgs = hsPkgs.buildPackages;
      inherit haskellLib nonReinstallablePkgs withPackage
              package name src flags pkgconfig
              ;
    };

  comp-builder = haskellLib.weakCallPackage pkgs ./comp-builder.nix { inherit ghc haskellLib nonReinstallablePkgs ghcForComponent hsPkgs; };

  buildComp = componentId: component: comp-builder {
    inherit componentId component package name src flags setup cabalFile cabal-generator patches revision
            preUnpack postUnpack preConfigure postConfigure
            preBuild postBuild preCheck postCheck
            preInstall postInstall preHaddock postHaddock
            shellHook
            ;
  };

in {
  components = haskellLib.applyComponents buildComp config;
  inherit (package) identifier;
  inherit setup cabalFile;
  isHaskell = true;
}
