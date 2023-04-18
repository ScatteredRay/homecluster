fun srcFile => {
  job = {
    name = "build_consuldns",
    id = "build_consuldns",
    datacenters = ["dc1"],
    taskgroups = [
      {
        name = "build_consuldns",
        count = 1,
        tasks = [
          {
            name = "build_consuldns",
            driver = "docker",
            config = {
              args = [
                "nix-build",
                "-E",
                "let pkgs = import <nixpkgs> {}; in pkgs.dockerTools.buildLayeredImage { name = \"testimage\"; config = [\"$${pkgs.hello}/bin/hello\"]; }"
              ],
              image = "nixos/nix:2.13.1-arm64",
              mount = {
                type = "bind",
                source = "local/consuldns",
                target = "/mnt/consuldns
              }
            },
            artifact = {
              source = "http://objectstore.home.nd.gl/artifacts/consuldns/%{srcFile}",
              destination = "local/consuldns"
            }
          }
        ]
      }
    ],
    type = "batch"
  }
}