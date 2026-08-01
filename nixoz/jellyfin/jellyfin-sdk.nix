{ pkgs ? import <nixpkgs> {} }:
let
  module = {
    buildPythonPackage,
    fetchFromGitHub,
    uv-build,
    requests,
    urllib3,
    websockets,
    python-dateutil,
    aiohttp,
    aiohttp-retry,
    pydantic,
    lazy-imports,
    httpx,
    httpx-oauth,
    distro,
    rich,
    pytestCheckHook,
  }:
  buildPythonPackage rec {
    pname = "jellyfin-sdk";
    version = "0.3.0";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "webysther";
      repo = "jellyfin-sdk-python";
      tag = version;
      hash = "sha256-LdmJTetYa/I/VcpfcH+OZZj44WZOdQUeTLzJ7mLc+EY=";
    };

    preConfigure = ''
      substituteInPlace pyproject.toml \
        --replace-fail "uv_build>=0.8.13,<0.9.0" "uv_build"
      substituteInPlace pyproject.toml \
        --replace-fail "websockets >= 11.0.3, < 12.0.0" "websockets"
    '';

    build-system = [ uv-build ];

    dependencies = [
      requests
      urllib3
      websockets
      python-dateutil
      aiohttp
      aiohttp-retry
      pydantic
      lazy-imports
      httpx
      httpx-oauth
      distro
      rich
    ];

    doCheck = false;

    nativeCheckInputs = [ pytestCheckHook ];

    pythonImportsCheck = [ "jellyfin" ];
  };
  package = pkgs.python3Packages.callPackage module {};
in
  package
