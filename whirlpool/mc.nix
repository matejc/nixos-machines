{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  # networking.firewall.allowedUDPPorts = [
  #   24454 # SimpleVoiceChat
  # ];

  # Minecraft server settings
  services.minecraft-servers = {
    enable = false;
    eula = true;
    managementSystem.systemd-socket.enable = true;

    servers.vinland4 = {
      enable = true;
      autoStart = true;
      openFirewall = true;

      serverProperties = {
        difficulty = 1;
        gamemode = 0;
        max-players = 5;
        motd = "Vinland server!";
        white-list = true;
        allow-cheats = false;
        enable-rcon = false;
      };

      package = pkgs.fabricServers.fabric-1_21_11;

      symlinks = {
        mods = pkgs.linkFarmFromDrvs "mods" (
          builtins.attrValues {
            # FabricAPI = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/dQ3p80zK/fabric-api-0.138.3%2B1.21.10.jar";
            #   sha512 = "dc73a3653c299476d1f70cb692c4e35ac3f694b3b0873e3d0b729e952e992b878d1a8e0b1d1049a442a0d483d3068073194f15af52ea9938544616e20433cc38";
            # };
            # ForgeConfigAPIPort = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/ohNO6lps/versions/IKHTwwTv/ForgeConfigAPIPort-v21.10.1%2Bmc1.21.10-Fabric.jar";
            #   sha512 = "ecb322db9e2c1a0cec8fb06300e1568847980f336fe77f3dda16a89a73da59cbf2152e3ffb2337ad9019dc6bd247a7534e6046e8fd93a3cdb6de065a24093ab9";
            # };
            # OpenPartiesAndClaims = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/gF3BGWvG/versions/MZ9uI929/open-parties-and-claims-fabric-1.21.10-0.25.8.jar";
            #   sha512 = "bb9ef8c3a4503f990d484820c8d4c93c0a5d5e5603fffafbb5e2b575d24889ed198bf48024fcec8d482279c0639a8de3d2b5a3c463f3203fe6b03f9546e80267";
            # };
            # XaerosMinimap = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/1bokaNcj/versions/hztxb2W2/Xaeros_Minimap_25.2.15_Fabric_1.21.9.jar";
            #   sha512 = "12a4a3e5756c9d9d5dc1094e495a80464b4602e0b55281d69ac4a083a533ca4dcf2fb6b6d113dcd2e705c7bf40fc9ef0f813116210974e39269fd1c7841d06d0";
            # };
            # BoxLib = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/HAE5KvTA/versions/yRjXXil6/BoxLib-fabric-19.0.3-19.0.3.jar";
            #   sha512 = "790debc819b34840d608ac6946002b7694678458725df8486037afbd1c44c0211373bd3b392489bb4e23685ac7fd25be76cfbcf5a3ac9c055c0b9bc1e5766ad0";
            # };
            # CoordinatesDisplay = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/3mW8PdUo/versions/xgkiMyEo/coordinatesdisplay-fabric-1.21.10-18.0.2.jar";
            #   sha512 = "d13f9a5f6f03da60283c786a01d80506f1e787b0f275f48f47f9db46ce0dbb88a51826fec2e98dc51e075692fa1071bca4abad0644e80aa730a65ee8b3a02ee8";
            # };
            # SimpleVoiceChat = pkgs.fetchurl {
            #   url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/BjR2lc4k/voicechat-fabric-1.21.10-2.6.6.jar";
            #   sha512 = "fc0b838a0906ddafeabf9db3b459d4226a2f06458443ee1dee44d937e5896f0d8d3e7c7bbc2a93ea74b4665f37249e7da719bbabf8449c756d2a49116be61197";
            # };
          }
        );
      };
      jvmOpts = "-Xms6144M -Xmx8192M";
    };
  };
}
