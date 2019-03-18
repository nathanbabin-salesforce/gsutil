#!/bin/bash

# This shell script is used for setting up our Kokoro Ubuntu environment
# with necessary dependencies for running integration tests, and then
# running tests when PRs are submitted.

# For now, continuous.sh and presubmit.sh are both symlinks to this file.
# Kokoro looks for files with those names, but our continuous and presubmit jobs
# should be identical on Linux.

# -e : Fail on any error
# -x : Display commands being run
# -u : Disallow unset variables
# Doc: https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html#The-Set-Builtin
set -xu


GITHUB_REPO="https://github.com/GoogleCloudPlatform/gsutil"
GSUTIL_KEY="./keystore/74008_gsutil_kokoro_service_key.json"
GSUTIL_SRC_PATH="/src/gsutil"
GSUTIL_ENTRYPOINT="$GSUTIL_SRC_PATH/gsutil.py"
PYTHON_PATH="/usr/local/bin/python"
CONFIG_JSON=".boto_json"
CONFIG_XML=".boto_xml"

# Processes to use based on default Ubuntu Kokoro specs here:
# go/gcp-ubuntu-vm-configuration-v32i
PROCS="4"

# PYMAJOR and PYMINOR environment variables are set for each Kokoro job in:
# go/kokoro-gsutil-configs
PYVERSION="$PYMAJOR.$PYMINOR"

function latest_python_release {
  # Return string with latest Python version triplet for a given version tuple.
  # Example: PYVERSION="2.7"; latest_python_release -> "2.7.15"
  pyenv install --list \
    | grep -vE "(^Available versions:|-src|dev|rc|alpha|beta|(a|b)[0-9]+)" \
    | grep -E "^\s*$PYVERSION" \
    | sed 's/^\s\+//' \
    | tail -1
}

function install_latest_python {
  #rm -rf ~/.pyenv/.git/refs/tags
  #pyenv update
  pyenv install -s "$PYVERSIONTRIPLET"
}

function write_config {
GSUTIL_KEY=$1
API=$2
OUTPUT_FILE=$3

cat > "$3" <<- EOM
[Credentials]
gs_service_key_file = "$GSUTIL_KEY"

[GSUtil]
test_notification_url = https://bigstore-test-notify.appspot.com/notify
default_project_id = bigstore-gsutil-testing
prefer_api = "$API"

[OAuth2]
client_id = 909320924072.apps.googleusercontent.com
client_secret = p3RlpR10xMFh9ZXBS/ZNLYUu
EOM
}

function init_configs {
  # Create config files for gsutil if they don't exist already
  # https://cloud.google.com/storage/docs/gsutil/commands/config
  touch "$CONFIG_JSON" "$CONFIG_XML"
  ls -la "$CONFIG_JSON" "$CONFIG_XML"
  ls -la .
  ls -la ..
  write_config "$GSUTIL_KEY" "json" "$CONFIG_JSON"
  write_config "$GSUTIL_KEY" "xml" "$CONFIG_XML"
  ls -la "$CONFIG_JSON" "$CONFIG_XML"
  write_config "$GSUTIL_KEY" "json" "$CONFIG_JSON"
  cat "test/ci/kokoro/$CONFIG_JSON" | grep -v private_key
  cat "test/ci/kokoro$CONFIG_XML" | grep -v private_key
}

function init_python {
  # Ensure latest release of desired Python version is installed, and that
  # dependencies, e.g. crcmod, are installed.
  PYVERSIONTRIPLET=$(latest_python_release)
  install_latest_python
  pyenv global "$PYVERSIONTRIPLET"
  python -m pip install -U crcmod
}

init_configs
cd github/src/gsutil
init_python
git submodule update --init --recursive

# Run integration tests
python ./gsutil.py test -p "$PROCS"

