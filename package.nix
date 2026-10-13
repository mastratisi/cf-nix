{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  autoPatchelfHook,
  nodejs_22,
  jq,
  versionCheckHook,
}:

let
  # Written by update.sh from the npm registry.
  release = lib.importJSON ./release.json;
in
buildNpmPackage {
  pname = "cf";
  inherit (release) version npmDepsHash;

  nodejs = nodejs_22;

  # The npm tarball ships the compiled CLI (dist/*.mjs). Upstream is a pnpm
  # monorepo built with vite-plus; building that is not needed, only its
  # runtime dependencies (miniflare and friends) have to be installed.
  src = fetchurl {
    inherit (release) url hash;
  };
  sourceRoot = "package";

  # The tarball has no lockfile, so update.sh generates package-lock.json from
  # its runtime dependencies. package.json also lists the bundled build-time
  # dependencies as devDependencies; drop them so it matches the lockfile.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${lib.getExe jq} 'del(.devDependencies)' package.json > package.json.new
    mv package.json.new package.json
  '';

  dontNpmBuild = true;

  # npm installs sharp's musl variants too; they are unused on glibc and
  # autoPatchelfHook cannot resolve libc.musl.
  postInstall = ''
    rm -rf $out/lib/node_modules/cf/node_modules/@img/*musl*
  '';

  # workerd (via miniflare) and sharp ship prebuilt ELF binaries.
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "The Cloudflare CLI (cf), Cloudflare's agentic command line tool";
    homepage = "https://github.com/cloudflare/cf";
    license = with lib.licenses; [ mit asl20 ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "cf";
  };
}
