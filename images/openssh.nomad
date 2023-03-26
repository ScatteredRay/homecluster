job "openssh_image" {
  datacenters = ["dc1"]
  type = "batch"

  group "build_image" {
    count = 1

    task "build_image" {
      driver = "docker"

      # If this is saved with DOS line endings /r get's sent in the shell script, which causes an error.
      template {
        data = <<EOF
let
  pkgs = import <nixpkgs> { system = "aarch64-linux"; };
  nonRootShadowSetup = { }: with pkgs; [
      (
      writeTextDir "etc/shadow" ''
        root:!x:::::::
      ''
      )
      (
      writeTextDir "etc/passwd" ''
        root:x:0:0::/root:${runtimeShell}
      ''
      )
      (
      writeTextDir "etc/group" ''
        root:x:0:
      ''
      )
      (
      writeTextDir "etc/gshadow" ''
        root:x::
      ''
      )
    ];
  openssh = pkgs.dockerTools.buildLayeredImage {
    name = "openssh";
    tag = "latest";
    contents = [
        pkgs.openssh
    ] ++ nonRootShadowSetup { };

    config = {
      Cmd = [ "/bin/ssh" ];
    };
  };
  pushImage = pkgs.writeShellScriptBin "push-image" ''
{{- range service "registry"}}
${pkgs.skopeo}/bin/skopeo copy --insecure-policy --dest-tls-verify=false docker-archive:${openssh} docker://{{ .Address }}:{{ .Port }}/nd/openssh:latest
{{end -}}
'';
in
  pushImage
EOF
        destination = "local/build.nix"
      }

      config {
        image = "nixos/nix:2.13.3-arm64"

        args = [
          "bash",
          "-c",
          "$(nix-build /etc/nixos/build.nix)/bin/push-image"
        ]

        mount {
          type = "bind"
          source = "local/build.nix"
          target = "/etc/nixos/build.nix"
          readonly = true
        }
      }
    }
  }
}