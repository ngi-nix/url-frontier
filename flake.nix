# nixpkgs flake for URL-Frontier API, service, client and test suite
# https://github.com/crawler-commons/url-frontier
{
  inputs = {
    mvn2nix.url = "github:fzakaria/mvn2nix";
    utils.url = "github:numtide/flake-utils";
    url-frontier-src.url = "github:crawler-commons/url-frontier";
    url-frontier-src.flake = false;
  };

  outputs = { nixpkgs, mvn2nix, utils, url-frontier-src, ... }:
    let
      overlay = final: prev: {
        api-url-frontier = final.callPackage api-url-frontier {};
      };

      pkgsForSystem = system: import nixpkgs {
        overlays = [ mvn2nix.overlay overlay ];
        inherit system;
      };

      api-url-frontier =
        { lib
        , stdenv
        , buildMavenRepositoryFromLockFile
        , makeWrapper
        , maven
        , jdk11_headless
        , nix-gitignore
        }:
          let
            mavenRepository =
              buildMavenRepositoryFromLockFile { file = ./mvn2nix-lock.json; };
          in
            stdenv.mkDerivation rec {
              pname = "api-url-frontier";
              # TODO: update version
              version = "0.9.3";
              name = "${pname}-${version}";
              #src = nix-gitignore.gitignoreSource [ "*.nix" ] ./.;
              src = url-frontier-src;
              patches = [
                #./patches/grpc.patch
                #./patches/snapshot.patch
              ];

              nativeBuildInputs = [
                jdk11_headless
                maven
                makeWrapper
              ];
              # TODO: add the built API maven repo's path as offline repo source
              # for tests, client, services
              #
              #echo "Building with maven repository ${mavenRepository}"
              buildPhase = ''

                mvn --debug package
                #mvn --debug package --offline -Dmaven.repo.local=/home/ajz/summer/url-frontier/mavenrepo

              '';
              #mvn --debug --update-snapshots package --offline -Dmaven.repo.local=${mavenRepository}
              #mvn --debug --update-snapshots package -Dmaven.repo.local=${mavenRepository}

              installPhase = ''
                # create the bin directory
                mkdir -p $out/bin

                # create a symbolic link for the lib directory
                ln -s ${mavenRepository} $out/lib

                # copy out the JAR
                # Maven already setup the classpath to use m2 repository layout
                # with the prefix of lib/
                cp target/${name}.jar $out/

                # create a wrapper that will automatically set the classpath
                # this should be the paths from the dependency derivation
                makeWrapper ${jdk11_headless}/bin/java $out/bin/${pname} \
                      --add-flags "-jar $out/${name}.jar"
              '';
            }
      ;
    in
      utils.lib.eachSystem utils.lib.defaultSystems (
        system: rec {
          legacyPackages = pkgsForSystem system;

          packages = utils.lib.flattenTree {
            inherit (legacyPackages) api-url-frontier;
          };

          # TODO: replace with client when done
          defaultPackage = packages.api-url-frontier;

          devShell = with legacyPackages; mkShell {
            nativeBuildInputs = [ maven ];
          };

        }
      );
}
