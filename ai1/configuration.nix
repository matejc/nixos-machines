{ config, pkgs, ... }:
let
  vars = import ./vars.nix;
  anything-llm-env = pkgs.writeText ".env" ''
    SERVER_PORT=3001
    STORAGE_DIR="/app/server/storage"
    # UID='${toString config.users.users.llm.uid}'
    # GID='${toString config.users.groups.llm.gid}'
    JWT_SECRET="${vars.anything-llm.jwt_secret}" # Only needed if AUTH_TOKEN is set. Please generate random string at least 12 chars long.

    ###########################################
    ######## LLM API SElECTION ################
    ###########################################
    # LLM_PROVIDER='openai'
    # OPEN_AI_KEY=
    # OPEN_MODEL_PREF='gpt-3.5-turbo'

    # LLM_PROVIDER='gemini'
    # GEMINI_API_KEY=
    # GEMINI_LLM_MODEL_PREF='gemini-pro'

    # LLM_PROVIDER='azure'
    # AZURE_OPENAI_ENDPOINT=
    # AZURE_OPENAI_KEY=
    # OPEN_MODEL_PREF='my-gpt35-deployment' # This is the "deployment" on Azure you want to use. Not the base model.
    # EMBEDDING_MODEL_PREF='embedder-model' # This is the "deployment" on Azure you want to use for embeddings. Not the base model. Valid base model is text-embedding-ada-002

    # LLM_PROVIDER='anthropic'
    # ANTHROPIC_API_KEY=sk-ant-xxxx
    # ANTHROPIC_MODEL_PREF='claude-2'

    # LLM_PROVIDER='lmstudio'
    # LMSTUDIO_BASE_PATH='http://your-server:1234/v1'
    # LMSTUDIO_MODEL_TOKEN_LIMIT=4096

    # LLM_PROVIDER='localai'
    # LOCAL_AI_BASE_PATH='http://host.docker.internal:8080/v1'
    # LOCAL_AI_MODEL_PREF='luna-ai-llama2'
    # LOCAL_AI_MODEL_TOKEN_LIMIT=4096
    # LOCAL_AI_API_KEY="sk-123abc"

    LLM_PROVIDER='ollama'
    OLLAMA_BASE_PATH='http://127.0.0.1:11434'
    OLLAMA_MODEL_PREF='llama2:13b'
    OLLAMA_MODEL_TOKEN_LIMIT=4096

    # LLM_PROVIDER='togetherai'
    # TOGETHER_AI_API_KEY='my-together-ai-key'
    # TOGETHER_AI_MODEL_PREF='mistralai/Mixtral-8x7B-Instruct-v0.1'

    # LLM_PROVIDER='mistral'
    # MISTRAL_API_KEY='example-mistral-ai-api-key'
    # MISTRAL_MODEL_PREF='mistral-tiny'

    # LLM_PROVIDER='perplexity'
    # PERPLEXITY_API_KEY='my-perplexity-key'
    # PERPLEXITY_MODEL_PREF='codellama-34b-instruct'

    # LLM_PROVIDER='openrouter'
    # OPENROUTER_API_KEY='my-openrouter-key'
    # OPENROUTER_MODEL_PREF='openrouter/auto'

    # LLM_PROVIDER='huggingface'
    # HUGGING_FACE_LLM_ENDPOINT=https://uuid-here.us-east-1.aws.endpoints.huggingface.cloud
    # HUGGING_FACE_LLM_API_KEY=hf_xxxxxx
    # HUGGING_FACE_LLM_TOKEN_LIMIT=8000

    # LLM_PROVIDER='groq'
    # GROQ_API_KEY=gsk_abcxyz
    # GROQ_MODEL_PREF=llama2-70b-4096

    ###########################################
    ######## Embedding API SElECTION ##########
    ###########################################
    # Only used if you are using an LLM that does not natively support embedding (openai or Azure)
    # EMBEDDING_ENGINE='openai'
    # OPEN_AI_KEY=sk-xxxx
    # EMBEDDING_MODEL_PREF='text-embedding-ada-002'

    # EMBEDDING_ENGINE='azure'
    # AZURE_OPENAI_ENDPOINT=
    # AZURE_OPENAI_KEY=
    # EMBEDDING_MODEL_PREF='my-embedder-model' # This is the "deployment" on Azure you want to use for embeddings. Not the base model. Valid base model is text-embedding-ada-002

    # EMBEDDING_ENGINE='localai'
    # EMBEDDING_BASE_PATH='http://localhost:8080/v1'
    # EMBEDDING_MODEL_PREF='text-embedding-ada-002'
    # EMBEDDING_MODEL_MAX_CHUNK_LENGTH=1000 # The max chunk size in chars a string to embed can be

    EMBEDDING_ENGINE='ollama'
    EMBEDDING_BASE_PATH='http://127.0.0.1:11434'
    EMBEDDING_MODEL_PREF='nomic-embed-text:latest'
    EMBEDDING_MODEL_MAX_CHUNK_LENGTH=8192

    ###########################################
    ######## Vector Database Selection ########
    ###########################################
    # Enable all below if you are using vector database: Chroma.
    # VECTOR_DB="chroma"
    # CHROMA_ENDPOINT='http://host.docker.internal:8000'
    # CHROMA_API_HEADER="X-Api-Key"
    # CHROMA_API_KEY="sk-123abc"

    # Enable all below if you are using vector database: Pinecone.
    # VECTOR_DB="pinecone"
    # PINECONE_API_KEY=
    # PINECONE_INDEX=

    # Enable all below if you are using vector database: LanceDB.
    VECTOR_DB="lancedb"

    # Enable all below if you are using vector database: Weaviate.
    # VECTOR_DB="weaviate"
    # WEAVIATE_ENDPOINT="http://localhost:8080"
    # WEAVIATE_API_KEY=

    # Enable all below if you are using vector database: Qdrant.
    # VECTOR_DB="qdrant"
    # QDRANT_ENDPOINT="http://localhost:6333"
    # QDRANT_API_KEY=

    # Enable all below if you are using vector database: Milvus.
    # VECTOR_DB="milvus"
    # MILVUS_ADDRESS="http://localhost:19530"
    # MILVUS_USERNAME=
    # MILVUS_PASSWORD=

    # Enable all below if you are using vector database: Zilliz Cloud.
    # VECTOR_DB="zilliz"
    # ZILLIZ_ENDPOINT="https://sample.api.gcp-us-west1.zillizcloud.com"
    # ZILLIZ_API_TOKEN=api-token-here

    # Enable all below if you are using vector database: Astra DB.
    # VECTOR_DB="astra"
    # ASTRA_DB_APPLICATION_TOKEN=
    # ASTRA_DB_ENDPOINT=

    ###########################################
    ######## Audio Model Selection ############
    ###########################################
    # (default) use built-in whisper-small model.
    WHISPER_PROVIDER="local"

    # use openai hosted whisper model.
    # WHISPER_PROVIDER="openai"
    # OPEN_AI_KEY=sk-xxxxxxxx

    # CLOUD DEPLOYMENT VARIRABLES ONLY
    AUTH_TOKEN="${vars.anything-llm.auth_token}" # This is the password to your application if remote hosting.
    DISABLE_TELEMETRY="true"

    ###########################################
    ######## PASSWORD COMPLEXITY ##############
    ###########################################
    # Enforce a password schema for your organization users.
    # Documentation on how to use https://github.com/kamronbatman/joi-password-complexity
    # Default is only 8 char minimum
    # PASSWORDMINCHAR=8
    # PASSWORDMAXCHAR=250
    # PASSWORDLOWERCASE=1
    # PASSWORDUPPERCASE=1
    # PASSWORDNUMERIC=1
    # PASSWORDSYMBOL=1
    # PASSWORDREQUIREMENTS=4

    ###########################################
    ######## ENABLE HTTPS SERVER ##############
    ###########################################
    # By enabling this and providing the path/filename for the key and cert,
    # the server will use HTTPS instead of HTTP.
    #ENABLE_HTTPS="true"
    #HTTPS_CERT_PATH="sslcert/cert.pem"
    #HTTPS_KEY_PATH="sslcert/key.pem"
  '';
in {
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
      zfs = super.zfs.overrideAttrs(_: {
         meta.platforms = [];
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    nano curl iproute2 htop tmux pciutils ncdu
    config.hardware.nvidia.package
  ];

  services.openssh.enable = true;

  users = {
    mutableUsers = false;
    users."${vars.user}" = {
      isNormalUser = true;
      password = vars.password;
      openssh.authorizedKeys.keys = vars.authorizedKeys;
      extraGroups = [ "wheel" ];
    };
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" ];

  # hardware.enableRedistributableFirmware = true;

  networking.firewall = {
    allowedTCPPorts = [
      22
    ];
  };

  # networking.nameservers = vars.nameservers;
  networking.hostName = vars.hostname;

  # systemd.enableUnifiedCgroupHierarchy = false;

  services.tailscale.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.dc_535;
    nvidiaPersistenced = true;
    datacenter.enable = true;
  };
  systemd.services.nvidia-fabricmanager.serviceConfig.SuccessExitStatus = "0 1";

  # boot.initrd.kernelModules = [ "nvidia" ];
  # boot.extraModulePackages = [ config.hardware.nvidia.package ];

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
    autoPrune.enable = true;
    # enableNvidia = true;
    # daemon.settings  = {
    #   default-runtime = "nvidia";
      # exec-opts = ["native.cgroupdriver=cgroupfs"];
    #   runtimes.nvidia = let
    #     n = pkgs.runCommand "n" {
    #       nativeBuildInputs = [ pkgs.makeWrapper ];
    #     } ''
    #       mkdir -p $out/bin
    #       makeWrapper ${pkgs.nvidia-container-toolkit}/bin/nvidia-container-runtime $out/bin/nvidia-container-runtime \
    #         --prefix PATH : ${pkgs.libnvidia-container}/bin \
    #         --prefix LD_LIBRARY_PATH : ${config.hardware.nvidia.package}/lib
    #     '';
    #   in {
    #     path = "${n}/bin/nvidia-container-runtime";
    #     runtimeArgs = [];
    #   };
    # };
    # extraPackages = [ pkgs.libnvidia-container ];
  };
  # virtualisation.containers = {
  #   enable = true;
  #   cdi.dynamic.nvidia.enable = true;
  # };

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };

  services.upaas = {
    enable = true;
    plugins = false;
    configuration = {
      stack = {
        llm = {
          enable = true;
          autostart = true;
          user = "llm";
          directory = "/var/lib/llm";
          compose = {
            version = "3";
            # services.vllm = {
            #   image = "vllm/vllm-openai:latest";
            #   ipc = "host";
            #   # runtime = "nvidia";
            #   environment = {
            #     HUGGING_FACE_HUB_TOKEN = vars.huggingface_token;
            #     NVIDIA_VISIBLE_DEVICES = "all";
            #   };
            #   volumes = [
            #     "/var/lib/llm/huggingface:/root/.cache/huggingface"
            #   ];
            #   ports = [ "8000:8000" ];
            #   command = [ "--model=google/gemma-7b" "--dtype=half" ];
            #   deploy.resources.reservations.devices = [{
            #     driver = "nvidia";
            #     count = "all";
            #     capabilities = ["gpu"];
            #   }];
            # };
            # services.openwebui = {
            #   image = "ghcr.io/open-webui/open-webui:main";
            #   environment = {
            #     OLLAMA_BASE_URL = "http://127.0.0.1:11434";
            #   };
            #   volumes = [
            #     "/var/lib/llm/open-webui:/app/backend/data"
            #   ];
            #   # links = [ "vllm" ];
            #   # ports = [ "3000:8080" ];
            #   network_mode = "host";
            # };
            services.anything-llm = {
              image = "mintplexlabs/anythingllm:latest";
              volumes = [
                "/var/lib/llm/server/.env:/app/server/.env"
                "/var/lib/llm/server/storage:/app/server/storage"
                "/var/lib/llm/collector/hotdir:/app/collector/hotdir"
                "/var/lib/llm/collector/outputs:/app/collector/outputs"
              ];
              env_file = [ "/var/lib/llm/server/.env" ];
              network_mode = "host";
              cap_add = [ "SYS_ADMIN" ];
            };
          };
        };
      };
    };
  };

  system.activationScripts.llm.text = ''
    mkdir -p /var/lib/llm/server/storage
    mkdir -p /var/lib/llm/collector/hotdir
    mkdir -p /var/lib/llm/collector/outputs
    if [ ! -f /var/lib/llm/server/.env ]
    then
      cat ${anything-llm-env} > /var/lib/llm/server/.env
    fi
    chown -R 1000:1000 /var/lib/llm/{server,collector}
  '';

  users.users.llm = {
    isNormalUser = true;
    createHome = true;
    home = "/var/lib/llm";
    extraGroups = [ "docker" ];
    uid = 1005;
  };
  users.groups.llm.gid = 1005;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  system.stateVersion = "23.11";
}
