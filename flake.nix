{
  description = "Flake for the Django based `agl-anonymizer` service";

  nixConfig = {
    substituters = [
        "https://cache.nixos.org"
        "https://cuda-maintainers.cachix.org"
      ];
    trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    extra-substituters = "https://cache.nixos.org https://nix-community.cachix.org https://cuda-maintainers.cachix.org";
    extra-trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=";
  };

  inputs = {
    poetry2nix.url = "github:nix-community/poetry2nix";
    poetry2nix.inputs.nixpkgs.follows = "nixpkgs";

    endoreg-db = {
      url = "github:wg-lux/endoreg-db";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cachix = {
      url = "github:cachix/cachix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, poetry2nix, ... } @ inputs: 
  let 
    system = "x86_64-linux";
    self = inputs.self;
    version = "0.1.${pkgs.lib.substring 0 8 inputs.self.lastModifiedDate}.${inputs.self.shortRev or "dirty"}";
    python_version = "311";
    cachix = inputs.cachix;

    nvidiaCache = cachix.lib.mkCachixCache {
      inherit (pkgs) lib;
      name = "nvidia";
      publicKey = "nvidia.cachix.org-1:dSyZxI8geDCJrwgvBfPH3zHMC+PO6y/BT7O6zLBOv0w=";
      secretKey = null;  # not needed for pulling from the cache
    };
  
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    lib = pkgs.lib;

    pypkgs-build-requirements = {
      gender-guesser = [ "setuptools" ];
      conllu = [ "setuptools" ];
      janome = [ "setuptools" ];
      pptree = [ "setuptools" ];
      wikipedia-api = [ "setuptools" ];
      django-flat-theme = [ "setuptools" ];
      django-flat-responsive = [ "setuptools" ];
    };

    poetry2nix = inputs.poetry2nix.lib.mkPoetry2Nix { inherit pkgs;};

    p2n-overrides = poetry2nix.defaultPoetryOverrides.extend (final: prev:
      builtins.mapAttrs (package: build-requirements:
        (builtins.getAttr package prev).overridePythonAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ (
            builtins.map (pkg:
              if builtins.isString pkg then builtins.getAttr pkg prev else pkg
            ) build-requirements
          );
        })
      ) pypkgs-build-requirements
    );

    poetryApp = poetry2nix.mkPoetryApplication {
      projectDir = ./.;
      src = lib.cleanSource ./.;
      python = pkgs."python${python_version}";
      overrides = p2n-overrides;
      preferWheels = true; # some packages, e.g. transformers break if false
      # propagatedBuildInputs =  with pkgs."python${python_version}Packages"; [];
      nativeBuildInputs = with pkgs."python${python_version}Packages"; [
        pip
        setuptools
        icecream
        pdfplumber
        inputs.endoreg-db.packages.x86_64-linux.poetryApp
      ];
      # postShellHook = ''
      #   python manage.py migrate  
      # '';
    };
    
  in
  {

    packages.x86_64-linux.poetryApp = poetryApp;
    packages.x86_64-linux.default = poetryApp;
    
    apps.x86_64-linux.default = {
      type = "app";
      program = "${poetryApp}/bin/django-server";
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      inputsFrom = [ self.packages.x86_64-linux.poetryApp ];
      packages = [ pkgs.poetry ];
      shellHook = ''
        export DJANGO_SETTINGS_MODULE=agl_monitor.settings_dev
        export DJANGO_SECRET_KEY=change-me
        export DJANGO_DEBUG=True
        export CELERY_BROKER_URL=redis://localhost:6382/0
        export CELERY_RESULT_BACKEND=redis://localhost:6382/0
        export CELERY_ACCEPT_CONTENT=application/json
        export CELERY_TASK_SERIALIZER=json
        export CELERY_RESULT_SERIALIZER=json
        export CELERY_TIMEZONE=UTC
        export CELERY_BEAT_SCHEDULER=django_celery_beat.schedulers:DatabaseScheduler
        export CELERY_SIGNAL_LOGFILE=/etc/custom-logs/agl-monitor-celery-signal.log
      '';
    };

    ## AGL Anonymizer Module
    nixosModules = {
      agl-monitor = { config, pkgs, lib, ...}: {
        ## Options
        options.services.agl-monitor = {
          enable = mkOption {
            default = false;
            description = "Enable the AGL Monitor service";
          };

          config-json-file = mkOption {
            type = lib.types.str;
            default = "/etc/agl-monitor.json";
            description = "The path to the configuration file for the AGL Monitor service";
          };

          user = mkOption {
            type = lib.types.str;
            default = "logging-user";
            description = "The user under which the AGL Monitor Server will run";
          };

          group = mkOption {
            type = lib.types.str;
            default = "service-user";
            description = "The group under which the AGL Monitor Server will run";
          };

          custom-logs-dir = mkOption {
            type = lib.types.str;
            default = "/etc/custom-logs";
            description = "The directory where the AGL Monitor logs will be stored";
          };

          django-debug = mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Django debug mode";
          };

          django-settings-module = mkOption {
              type = lib.types.str;
              default = "agl_monitor.settings_prod";
              description = "The settings module for the Django application";
            };

          django-port = mkOption {
            type = lib.types.int;
            default = 9243;
            description = "The port on which the Django server will listen";
          };

          django-secret-key = mkOption {
            type = lib.types.str;
            default = "change-me";
            description = "The secret key for the Django application";
          };

          # Define the address on which the Django server will listen
          bind = mkOption {
            type = lib.types.str;
            default = "localhost";
            description = "The address on which the Django server will listen";
          };

          redis-port = mkOption {
            type = lib.types.int;
            default = 6382; #FIXME: currently isnt used, the port is currently defined via config file (agl-monitor.json)
            description = "The port on which the Redis server will listen"; 
          };

          redis-bind = mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "The address on which the Redis server will listen";
          };

          conf = mkOption {
            type = lib.types.attrsOf lib.types.any;
            default = {
              CACHES = {
                "default" = {
                  BACKEND = "django_redis.cache.RedisCache";
                  LOCATION = "redis://localhost:6382/0";
                  TIMEOUT = "300";
                  OPTIONS = {
                    "CLIENT_CLASS" = "django_redis.client.DefaultClient";
                  };
                };
              };
              CELERY_BROKER_URL = "redis://localhost:6382/0";
              CELERY_RESULT_BACKEND = "redis://localhost:6382/0";
              CELERY_ACCEPT_CONTENT = "application/json";
              CELERY_TASK_SERIALIZER = "json";
              CELERY_RESULT_SERIALIZER = "json";
              CELERY_TIMEZONE = "UTC";
              CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler";

              CELERY_SIGNAL_LOGFILE = "/etc/custom-logs/agl-monitor-celery-signal.log";
            };
            description = "Other settings";
          };


        };

        # Service Implementation
        config = lib.mkIf config.services.agl-monitor.enable {



          # Create Redis Server

          services.redis.servers."agl-monitor" = {
            enable = true;
            bind = config.services.agl-monitor.redis-bind;
            port = config.services.agl-monitor.redis-port;
            # port = "${toString config.services.agl-monitor.redis-port}";
            settings = {};
          };




          # Create Celery Service

          systemd.services.agl-monitor-celery = {
            description = "AGL Monitor Celery Service";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.python311}/bin/python ${poetryApp}/bin/celery -A agl_monitor worker -l info";
              Restart = "always";
              RestartSec = "5";
              # WorkingDirectory = ./.; REQUIRED?!
              User = config.services.agl-monitor.user;
              Group = config.services.agl-monitor.group;
              Environment = [];
            };
            # script = ''
            #     nix develop
            #     exec celery -A agl_monitor worker --loglevel=info
            #   '';
          };

          # Create Celery Beat Service

          systemd.services.agl-monitor-celery-beat = {
            description = "AGL Monitor Celery Beat Service";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.python311}/bin/python ${poetryApp}/bin/celery -A agl_monitor beat -l info";
              Restart = "always";
              RestartSec = "5";
              # WorkingDirectory = ./.; REQUIRED?!
              User = config.services.agl-monitor.user;
              Group = config.services.agl-monitor.group;
              Environment = [];
            };
            # script = ''
            #   nix develop
            #   exec celery -A agl_monitor beat --loglevel=INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler
            # '';
          };

          # Create the AGL Monitor Service

          systemd.services.agl-monitor = {
            description = "AGL Monitor Service";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.python311}/bin/python ${poetryApp}/bin/django-server";
              Restart = "always";
              RestartSec = "5";
              # WorkingDirectory = ./.; REQUIRED?!
              User = config.services.agl-monitor.user;
              Group = config.services.agl-monitor.group;
              Environment = [
                "PATH=${poetryApp}/bin:/run/current-system/sw/bin"
                "DJANGO_SETTINGS_MODULE=${config.services.agl-monitor.django-settings-module}"
                "DJANGO_DEBUG=${toString config.services.agl-monitor.django-debug}"
                "CELERY_BROKER_URL=${config.services.agl-monitor.conf.CELERY_BROKER_URL}"
                "CELERY_RESULT_BACKEND=${config.services.agl-monitor.conf.CELERY_RESULT_BACKEND}"
                "CELERY_ACCEPT_CONTENT=${config.services.agl-monitor.conf.CELERY_ACCEPT_CONTENT}"
                "CELERY_TASK_SERIALIZER=${config.services.agl-monitor.conf.CELERY_TASK_SERIALIZER}"
                "CELERY_RESULT_SERIALIZER=${config.services.agl-monitor.conf.CELERY_RESULT_SERIALIZER}"
                "CELERY_TIMEZONE=${config.services.agl-monitor.conf.CELERY_TIMEZONE}"
                "CELERY_BEAT_SCHEDULER=${config.services.agl-monitor.conf.CELERY_BEAT_SCHEDULER}"
                "CELERY_SIGNAL_LOGFILE=${config.services.agl-monitor.conf.CELERY_SIGNAL_LOGFILE}"
              ];
            };
          };
        };

      };
    };

  
  };
}
