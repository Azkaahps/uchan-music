self:
{ pkgs, lib, ... }:
{
  imports = [ ./hm/uchan-music.nix ];
  programs.uchan-music.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
}
