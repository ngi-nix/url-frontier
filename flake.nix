# nixpkgs flake for URL-Frontier API, service, client and test suite
# https://github.com/crawler-commons/url-frontier
{
  inputs = {
    mvn2nix.url = "github:fzakaria/mvn2nix";
    utils.url = "github:numtide/flake-utils";
    # pinned to release 1.0
    url-frontier-src.url =
      "github:crawler-commons/url-frontier?rev=daec31d4df4a0d1f906674ba3f2dd852121b55d1";
    url-frontier-src.flake = false;
  };

  outputs = { nixpkgs, mvn2nix, utils, url-frontier-src, ... }:
    let
      overlay = final: prev: {
        urlfrontier-API = final.callPackage urlfrontier-API {};
      };

      pkgsForSystem = system: import nixpkgs {
        overlays = [ mvn2nix.overlay overlay ];
        inherit system;
      };

      urlfrontier-API =
        { lib
        , stdenv
        , buildMavenRepositoryFromLockFile
        , makeWrapper
        , maven
        , jdk11_headless
        }:
          let
            mavenRepository =
              buildMavenRepositoryFromLockFile { file = ./mvn2nix-lock.json; };
          in
            stdenv.mkDerivation rec {
              pname = "urlfrontier-API";
              version = "1.0";
              name = "${pname}-${version}";
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
              buildPhase = ''
                echo "Building with maven repository ${mavenRepository}"
                mvn --debug package --offline -Dmaven.repo.local=${mavenRepository}
              '';

              installPhase = ''
                # create the bin directory
                mkdir -p $out/bin

                # create a symbolic link for the lib directory
                ln -s ${mavenRepository} $out/lib

                # copy out the JAR
                # Maven already setup the classpath to use m2 repository layout
                # with the prefix of lib/
                cp API/target/${name}.jar $out/

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
            inherit (legacyPackages) urlfrontier-API;
          };

          # TODO: replace with client when done
          defaultPackage = packages.urlfrontier-API;

          devShell = with legacyPackages; mkShell {
            nativeBuildInputs = [ maven ];
          };

        }
      );
}
