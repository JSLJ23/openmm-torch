{
  description = "OpenMM plugin to define forces with neural networks";

  # Flake inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05"; # also valid: "nixpkgs"
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
        pkgs =
          import nixpkgs {
            inherit system;
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
        built = pkgs.mkShell {
          buildInputs = [ (pkgs.python3.withPackages (pkgs: [ self.packages.x86_64-linux.python ])) ];

          shellHook = "
          echo 'You are in a nix shell'
";
        };
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
            python310
            python310Packages.pip
          ];
          shellHook = "
          echo 'You are in a nix shell'
          export LD_LIBRARY_PATH=${pkgs.cudaPackages.cudatoolkit.lib}/lib:$LD_LIBRARY_PATH
          export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}
          export CUDA_LIB=${pkgs.cudaPackages.cudatoolkit.lib}
          export OPENMM_HOME=${pkgs.openmm.override { enableCuda = true; }}
          # For debuggin
          echo $LD_LIBRARY_PATH
          ";
        };
      });

      packages = forAllSystems ({ pkgs }: {
        python = pkgs.python310Packages.toPythonModule self.packages.x86_64-linux.default;
        default =
          let
            buildDependencies = with pkgs ; [
              #gcc12
              cmake
              cudaPackages.cudatoolkit
              addOpenGLRunpath
            ];
            cppDependencies = with pkgs; [
              libtorch-bin
              openmm
              swig4
              cudaPackages.cudatoolkit
              python3
            ];
            projectName = "openmm-torch";
          in
          pkgs.gcc11Stdenv.mkDerivation {
            name = projectName;
            version = "1.1.0";
            src = ./.;
            nativeBuildInputs = buildDependencies;
            buildInputs = cppDependencies;
            preConfigure = ''
              export OPENMM_HOME=${pkgs.openmm.override { enableCuda = true; }}
            '';
            propagatedBuildInputs = [
              pkgs.cudaPackages.cudatoolkit
              (pkgs.openmm.override { enableCuda = true; })
              pkgs.python3Packages.openmm
            ];
            postInstall = ''
              cd python
              swig -python -c++ -o TorchPluginWrapper.cpp "-I${pkgs.openmm}/include" ${./python/openmmtorch.i}
              ${pkgs.python3Packages.python.pythonForBuild.interpreter} setup.py build
              ${pkgs.python3Packages.python.pythonForBuild.interpreter} setup.py install --prefix=$out
            '';
            postFixup = ''
              addOpenGLRunpath $out/lib/plugins/*.so
              addOpenGLRunpath $out/lib/*.so

              for lib in $out/lib/python3.10/site-packages/*.so; do
                echo "Adding rpath to $lib"
                addOpenGLRunpath "$lib"
              done
            '';
          };
      });
    };
}
