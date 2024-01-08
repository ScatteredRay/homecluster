job "mbsync_image" {
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
  pkgs = import <nixpkgs> {};
  mbsync = pkgs.dockerTools.buildLayeredImage {
    name = "mbsync";
    tag = "latest";
    config = {
      Cmd = [ "/bin/mbsync" ];
    };
    contents = [
      pkgs.isync
      pkgs.busybox
    ];
  };
  pushImage = pkgs.writeShellScriptBin "push-image" ''
{{- range service "registry"}}
echo ${pkgs.skopeo}/bin/skopeo copy docker-archive:${mbsync} docker://{{ .Address }}:{{ .Port }}/nd/mbsync:latest
${pkgs.skopeo}/bin/skopeo copy --insecure-policy --dest-tls-verify=false docker-archive:${mbsync} docker://{{ .Address }}:{{ .Port }}/nd/mbsync:latest
{{end -}}
'';
in
  pushImage
EOF
        destination = "local/build.nix"
      }

      config {
        image = "nixos/nix:2.13.1-arm64"

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