{
  description = "OpenMM plugin to define forces with neural networks";

  # Flake inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs"; # also valid: "nixpkgs"
  };

  # Flake outputs
  outputs = { self, nixpkgs }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = import nixpkgs { inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };
      });

    in
    {
      # Development environment output
      devShells = forAllSystems ({ pkgs }: {
        default = pkgs.mkShell {
          # The Nix packages provided in the environment
          packages = with pkgs; [
            direnv # For setting nix enviroment
            gcc12 # The GNU Compiler Collection
            cmake
            cudaPackages.cudatoolkit
            # Other libraries
            libtorch-bin
            python310Packages.openmm
            swig4
            python310Packages.python
            python310Packages.pip
          ];
          shellHook = "
          echo 'You are in a nix shell'
          export LD_LIBRARY_PATH=${pkgs.cudaPackages.cudatoolkit.lib}/lib:$LD_LIBRARY_PATH
          export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}
          export CUDA_LIB=${pkgs.cudaPackages.cudatoolkit.lib}
          export OPENMM_HOME=${pkgs.openmm}
          # For debuggin
          echo ${pkgs.cudaPackages.cudatoolkit.lib}
          echo $LD_LIBRARY_PATH
          ";
        };
      });

      packages = forAllSystems ({ pkgs }: {
        default =
          let
            buildDependencies = with pkgs ; [
                gcc12
                cmake
                cudaPackages.cudatoolkit
            ];
            cppDependencies = with pkgs; [
                libtorch-bin
                openmm
                swig4
                python310Packages.python
                python310Packages.pip
            ];
            projectName = "openmm-torch";
          in
          pkgs.stdenv.mkDerivation {
            name = projectName;
            version = "1.1.0";
            src = self;
            nativeBuildInputs = buildDependencies;
            buildInputs = cppDependencies;
            preConfigure = ''
                export LD_LIBRARY_PATH=${pkgs.cudaPackages.cudatoolkit.lib}/lib:$LD_LIBRARY_PATH
                export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}
                export CUDA_LIB=${pkgs.cudaPackages.cudatoolkit.lib}
                export OPENMM_HOME=${pkgs.openmm}
            '';
#            buildPhase = ''
#                make
#            '';
#            installPhase = ''
#                make install
#            '';
            postInstall = ''
                make PythonInstall
            '';
          };
      });
    };
}