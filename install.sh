#!/usr/bin/env bash

#=======================================================================
# HEADER
#=======================================================================
#% BLAST
#%      BLAST - Briel’s Linux Auto-Setup Tool.
#%
#=======================================================================
#% SYNOPSIS
#+      ${scriptName} [OPTION]... [ARGUMENT]...
#+
#=======================================================================
#% DESCRIPTION
#+      BLAST (Briel’s Linux Auto-Setup Tool) is a post-install script
#+      that configures your Arch system exactly like mine: fast, clean,
#+      and fully automated.
#+
#=======================================================================
#+ OPTIONS
#+      -h, --help          Display this help message and exit
#%
#+      -v, --version       Display version information and exit
#%
#+      -l, --log-file      Custom log file location
#%                          Regex: ^[a-zA-Z0-9_/\.-]+$
#%
#+      -o, --option        Do nothing
#+
#=======================================================================
#+ EXAMPLES
#%      Example usages of ${scriptName}.
#+
#+      $ ${scriptName} -s full -p my_package_list.json
#%          This example shows how to use the script with the pacakge
#%          file set to "my_package_list.json", and -s option as full,
#%          that runs a complete setup for Arch Linux.
#+
#=======================================================================
#/ IMPLEMENTATION
#-      Version     ${scriptName} 1.0
#/      Author      Gabriel Nascimento
#/      Copyright   Copyright (c) Gabriel Nascimento (gnsilva.com)
#/      License     MIT License
#/
#=======================================================================
#) COPYRIGHT
#)      Copyright (c) 2023 Gabriel Nascimento:
#)      <https://opensource.org/licenses/MIT>.
#)
#)      Permission is hereby granted, free of charge, to any person
#)      obtaining a copy of this software and associated documentation
#)      files (the "Software"), to deal in the Software without
#)      restriction, including without limitation the rights to use,
#)      copy, modify, merge, publish, distribute, sublicense, and/or
#)      sell copies of the Software, and to permit persons to whom the
#)      Software is furnished to do so, subject to the following
#)      conditions:
#)
#)      The above copyright notice and this permission notice shall be
#)      included in all copies or substantial portions of the Software.
#)
#)      THE SOFTWARE IS PROVIDED "AS IS," WITHOUT WARRANTY OF ANY KIND,
#)      EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#)      OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#)      NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#)      HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#)      WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#)      FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#)      OTHER DEALINGS IN THE SOFTWARE.
#)
#=======================================================================
# DEBUG OPTIONS
set +o xtrace # Trace the execution of the script (DEBUG)
set +o noexec # Don't execute commands (Ignored by interactive shells)
#=======================================================================
# BASH OPTIONS
set -o nounset      # Exposes unset variables
set -o errexit      # Exit upon error, avoiding cascading errors
set -o pipefail     # Unveils hidden failures
set -o noclobber    # Avoid overwriting files (eg: echo "hi" > foo)
set -o errtrace     # Inherit trap on ERR to functions and commands
shopt -s nullglob   # Non-matching globs are removed ('*.foo' => '')
shopt -s failglob   # Non-matching globs throw errors
shopt -u nocaseglob # Case insensitive globs
shopt -s dotglob    # Wildcards match hidden files
shopt -s globstar   # Recursive matches ('a/**/*.e' => 'a/b/c/d.e')
#=======================================================================
# TRAPS
function _setTraps() {
  trap "" SIGTSTP
  trap _exitTrap EXIT
  trap _ctrlC INT
  trap _errTrapper ERR
}
function _ctrlC() {
  trap "" INT # Disable trap on CTRL_C to prevent recursion
  printf "\nInterrupt signal intercepted! Exiting now..."
  exit 130
}
function _errTrapper() {
  local exitCode="${?}"
  trap "" ERR # Disable trap on ERR to prevent recursion
  print "${scriptName}: An exception occurred during execution"
  print "Check the log file \"${scriptLogFile}\" for details."
  exit "${exitCode:-1}"
}
function _exitTrap() {
  local exitCode="${?}"
  trap "" EXIT # Disable trap on EXIT to prevent recursion
  rm --recursive --force "${scriptTempDir}" "${scriptTempFile}"
  cd "${currentDir}"
  log "Script Terminated with exit status: ${exitCode:-1}"
  exit "${exitCode:-1}"
}
#=======================================================================
# INITIALIZATION SCRIPTS
function _initVariables() {
  TERM=ansi
  IFS=$' \t\n'
  currentDir="${PWD}"
  scriptParams=("${@}")
  scriptName="$(basename "${0}")"
  scriptDir="$(cd "$(dirname "${0}")" && pwd)"
  scriptPath="${scriptDir:?}/${scriptName:?}"
  local script_head
  if ! script_head=$(grep --no-messages --line-number "^#: END_OF_HEADER$" "${0}" | head -1 | cut --fields=1 --delimiter=:); then
    error "${scriptName}: Failed to parse script head marker\n"
  fi
  if [[ -z "${script_head// /}" ]]; then
    error "${scriptName}: Header marker not found in script file\n"
  fi
  scriptHead="${script_head}"
  scriptTempDir=$(mktemp --directory -t tmp.XXXXXXXXXX)
  scriptTempFile=$(mktemp -t tmp.XXXXXXXXXX)
  scriptLogFile="${scriptDir}"/logs/script.log
  mkdir --parents "$(dirname "${scriptLogFile}")" \
    || {
      local exitCode="${?}"
      error "\nFailed to create log file on default directory:\n\"${scriptLogFile}\"\nMake sure it is a valid path and that you have write permission.\n" "${exitCode}"
    }
  msgInvalid="${scriptName}: invalid option"
  msgTryHelp="Try '${scriptName} --help' for more information."
}
function _initLogger() {
  local filePath
  local filename
  local directory
  local parentDir
  local dir
  local argUsed=false
  local valuesToRemove=()
  local filteredParams=()
  while [[ "${#}" -gt 0 ]]; do
    case "${1:-}" in
      -l | --log-file)
        if [[ "${argUsed}" == true ]]; then
          error "${scriptName}: too much arguments\n${msgTryHelp}\n"
        fi
        shift
        filePath="${1:-}"
        if [[ -z "${filePath}" ]]; then
          error "${scriptName}: missing file operand\n${msgTryHelp}\n"
        fi
        directory=$(dirname "${filePath}" 2> /dev/null)
        if [[ ! "${directory}" =~ ^/ ]]; then
          directory="${PWD?}/${directory}"
        fi
        filename=$(basename "${filePath}")
        if [[ ! "${directory}" =~ ^[a-zA-Z0-9_/\.-]+$ ||
          ! "${filename}" =~ ^[a-zA-Z0-9_/\.-]+$ ]]; then
          error "${scriptName}: Invalid file or directory name\n${msgTryHelp}\n"
        fi
        dir="${directory}"
        while true; do
          if [[ -w "${dir}" ]]; then
            break
          fi
          parentDir=$(dirname "${dir}")
          if [[ "${parentDir}" == "${dir}" ]]; then
            error "${scriptName}: cannot set log directory to \"${directory}\": Permission Denied\n"
          fi
          dir="${parentDir}"
        done
        mkdir "${directory}" --parents \
          && touch "${directory:?}/${filename}"
        scriptLogFile="${filePath}"
        argUsed=true
        valuesToRemove=("-l" "--log-file" "${filePath}")
        for element in "${scriptParams[@]}"; do
          # Check if the element is in the list of values to remove
          if [[ "${valuesToRemove[*]}" != *"${element}"* ]]; then
            filteredParams+=("${element}")
          fi
        done
        scriptParams=("${filteredParams[@]}")
        ;;
      *)
        :
        ;;
    esac
    shift
  done
  cp /dev/null "${scriptLogFile}"
  exec 3>> "${scriptLogFile}"
}
function _traceVariables() {
  log "Origin cwd: ${currentDir}"
  log "Script parameter: ${scriptParams[*]}"
  log "Script name: ${scriptName}"
  log "Script directory: ${scriptDir}"
  log "Script path: ${scriptPath}"
  log "Script head size: ${scriptHead}"
  log "Script temp directory: ${scriptTempDir}"
  log "Script temp file: ${scriptTempFile}"
  log "Script log file: ${scriptLogFile}"
  log "Message invalid: ${msgInvalid}"
  log "Message try help: ${msgTryHelp}"
}
function _enforceScriptDir() {
  local currDir
  currDir="$(pwd)"
  if [[ "${currDir}" != "${scriptDir}" ]]; then
    error "You must run this script from its own directory: cd \"${scriptDir}\" && ./$(basename "$0")"
  fi
}
function displayHelp() {
  local helpOption="${1}"
  local filter
  local header
  local filterheader
  local formatheader
  header="$(head -"${scriptHead:-99}" "${0}")"
  case "${helpOption}" in
    version)
      filter="^#-[ ]*"
      filterheader="$(echo "${header}" | grep --regexp="${filter}")"
      formatheader="$(
        echo "${filterheader}" \
          | sed --expression="s/${filter}//g" \
            --expression="s/\${scriptName}//g" \
            --expression="s/Version//g" \
            --expression="s/ //g"
      )"
      printf "%b\n" "${formatheader}" >&1
      ;;
    usage)
      filter="^#+[ ]*"
      filterheader="$(echo "${header}" | grep --regexp="${filter}")"
      formatheader="$(
        echo "${filterheader}" \
          | sed --expression="s/${filter}//g" \
            --expression="0,/\${scriptName}/s//Usage: ${scriptName}/" \
            --expression="s/\${scriptName}/${scriptName}/g"
      )"
      printf "%b\n" "${formatheader}" >&1
      ;;
    *)
      filter="^#[%/)+-]"
      filterheader="$(echo "${header}" | grep --regexp="${filter}")"
      formatheader="$(
        echo "${filterheader}" \
          | sed --expression="s/${filter}//g" \
            --expression="s/\${scriptName}/${scriptName}/g"
      )"
      printf "%b\n" "${formatheader}" >&1
      ;;
  esac
  exit 0
}
#=======================================================================
# HELPER FUNCTIONS
function error() {
  printf "%s: An exception occurred during execution:\n\t%s\n\n" "${scriptName}" "${1}" >&2
  printf "Check the log file \"%s\" for details.\n" "${scriptLogFile}" >&2
  exit "${2:-1}"
}
function log() {
  command printf "+++ (%s): %b\n" "${BASH_LINENO[0]}" "${*}" >&3
}
function print() {
  command printf "%b\n" "${*}" >&1
}
function validateArguments() {
  if [[ "${#}" -lt 1 ]]; then
    error "validade_str: missing required argument\ne.g, $ validateArguments -unzip '' --if-empty\n"
  fi
  local special
  local empty
  local args=()
  local badargsEmpty=()
  local badargsSpecial=()
  while [[ "${#}" -gt 0 ]]; do
    case "${1:-}" in
      -s | --special-chars)
        special=1
        ;;
      -e | --if-empty)
        empty=1
        ;;
      *)
        args+=("${1}")
        ;;
    esac
    shift
  done
  if [[ "${#args[@]}" == 0 ]]; then
    error "validade_str: missing required argument\ne.g, $ validateArguments -unzip '' --if-empty\n" >&2
  fi
  local i
  for i in "${args[@]}"; do
    if [[ "${i}" =~ ^- ]]; then
      badargsSpecial+=("${i}")
    fi
    if [[ -z "${i}" ]]; then
      badargsEmpty+=("${i}")
    fi
  done
  if [[ "${special:-}" == 1 && "${#badargsSpecial[@]}" -gt 0 ]]; then
    error "The argument(s) '%s', " "${badargsSpecial[*]}\ncannot start with a hyphen (-)\n" >&2
  fi
  if [[ "${empty:-}" == 1 && "${#badargsEmpty[@]}" -gt 0 ]]; then
    error "The argument(s) '%s', " "${badargsEmpty[*]}\ncannot be empty\n" >&2
  fi
}
function hasWritePermission() {
  if [[ "${#}" -ne 1 ]]; then
    error "hasWritePermission: missing required argument\ne.g, $ hasWritePermission path/to/file\n" >&2
  fi
  local dir="${1}"
  local parentDir
  while true; do
    if [[ -w "${dir}" ]]; then
      return 0
    fi
    parentDir=$(dirname "${dir}")
    if [[ "${parentDir}" == "${dir}" ]]; then
      return 1
    fi
    dir="${parentDir}"
  done
}
function create() {
  if [[ "${#}" -lt 1 ]]; then
    error "create: missing required argument\ne.g, $ create --directory PATH/TO/DIR\ne.g, $ create --file PATH/TO/FILE" >&2
  fi
  local createFile
  local createDirectory
  local paths=()
  while [[ "${#}" -gt 0 ]]; do
    case "${1:-}" in
      -f | --file)
        createFile=1
        ;;
      -d | --directory)
        createDirectory=1
        ;;
      *)
        paths+=("${1}")
        ;;
    esac
    shift
  done
  if [[ "${createFile:-}" -eq "${createDirectory:-}" ]]; then
    error "create: choose only one operation\ne.g, $ create --directory PATH/TO/DIR\ne.g, $ create --file PATH/TO/FILE\n" >&2
  fi
  if [[ "${#paths[@]}" -eq 0 ]]; then
    error "create: missing required argument\ne.g, $ create --directory PATH/TO/DIR\ne.g, $ create --file PATH/TO/FILE\n" >&2
  fi
  validateArguments "${paths[@]}" --if-empty --special-chars
  local i
  for i in "${paths[@]}"; do
    if [[ "${createFile:-}" == 1 ]]; then
      if [[ -f "${i}" ]]; then
        log "create: skipping file '${i}': already found\n"
        continue
      fi
      mkdir --parents "$(dirname "${i}")" \
        && touch "${i}"
      log "create: Created file '${i}'\n"
    fi
    if [[ "${createDirectory:-}" == 1 ]]; then
      if [[ -d "${i}" ]]; then
        log "create: skipping directory\n'${i}': already found.\n" ""
        continue
      fi
      mkdir --parents "${i}"
      log "Created directory '${i}'\n"
    fi
  done
}
function doCountdown() {
  if [[ "${#}" -ne 1 ]]; then
    error "doCountdown: missing required argument(s)\ne.g, $ doCountdown 15  # In seconds\n" >&2
  fi
  if [[ ! "${1}" =~ ^[0-9]+$ ]]; then
    error "doCountdown: requires a number to countdown from\ne.g, $ doCountdown 5  # In seconds\n" >&2
  fi
  local seconds="${1}"
  print "Continuing in: ${seconds}s\n"
  local i
  for ((i = seconds; i > -1; i--)); do
    printf "\rCountdown: %s seconds remaining." "${i}" >&1
    sleep 1
  done
  printf "\n" >&1
}
function _checkPrograms() {
  missingDependencies=()
  foundDependencies=()
  local i
  for i in "${@}"; do
    if ! command -v "${i}" > /dev/null 2>&1 && ! pacman -Qq "${i}" >&3; then
      missingDependencies+=("${i}")
      continue
    fi
    foundDependencies+=("${i}")
  done
}
function checkDependencies() {
  if [[ "${#}" -lt 1 ]]; then
    error "checkDependencies: missing required\ne.g, $ checkDependencies zip unzip --critical\n" >&2
  fi
  local do_exit
  local dependencies=()
  while [[ "${#}" -gt 0 ]]; do
    case "${1:-}" in
      -c | --critical)
        do_exit=1
        ;;
      *)
        dependencies+=("${1}")
        ;;
    esac
    shift
  done
  if [[ "${#dependencies[@]}" -eq 0 ]]; then
    error "checkDependencies: missing required\ne.g, $ checkDependencies zip unzip --critical\n" >&2
  fi
  validateArguments "${dependencies[@]}" --if-empty --special-chars
  _checkPrograms "${dependencies[@]}"
  if [[ "${#foundDependencies[@]}" -gt 0 ]]; then
    log "checkDependencies: found dependency(ies): '%s'." "${foundDependencies[*]}"
  fi
  if [[ "${#missingDependencies[@]}" -gt 0 ]]; then
    log "checkDependencies: couldn't find '%s'." "${missingDependencies[*]}"
  fi
  if [[ "${do_exit:-}" == 1 && "${#missingDependencies[@]}" -gt 0 ]]; then
    error "checkDependencies: make sure the program(s) \"${missingDependencies[*]}\" are installed." 127
  fi
}
#=======================================================================
#: END_OF_HEADER
#=======================================================================

# region: Script Functions
function cancelInstallation() {
  whiptail --title "Canceled" --msgbox "The installation process was successfully canceled." 10 60
  clear
  exit 0
}
function abortInstallation() {
  whiptail --title "Error" --msgbox "${1}" 10 60
  clear
  exit 1
}
function welcome() {
  whiptail --title "Welcome!" \
    --msgbox "This script will automatically install a fully-featured Linux desktop, which I use as my main machine.\\n\\n-Gabriel" 10 60 || cancelInstallation
  whiptail --title "Important Note!" \
    --yes-button "Go!" \
    --no-button "Return..." \
    --yesno "Please ensure your system has updated pacman updates and refreshed Arch keyrings.\\n\\nFailure to do so might result in installation errors for certain programs." 8 70 || cancelInstallation
}
function confirmInstall() {
  whiptail --title "Let's get this party started!" \
    --yes-button "Let's go!" \
    --no-button "No, nevermind!" \
    --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || cancelInstallation
}
function finalize() {
  whiptail --title "All done!" \
    --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"niri-session -l\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Luke" 13 80
  clear
  exit 0
}

function refreshKeys() {
  case "$(readlink -f /sbin/init)" in
    *systemd*)
      whiptail --infobox "Automatically refreshing Arch Keyring..." 10 80
      pacman-key --init >&3
      pacman-key --populate archlinux >&3
      pacman --sync --refresh --refresh --noconfirm >&3
      ;;
    *) ;;
  esac
}
function removePackage() {
  IFS=' ' read -r -a pkg_array <<< "${1}"
  pacman --noconfirm --remove -dd "${pkg_array[@]}" >&3 || echo "Conflicting package(s) not installed"
}
function installPackage() {
  IFS=' ' read -r -a pkg_array <<< "${1}"
  pacman --noconfirm --disable-download-timeout --needed --sync "${pkg_array[@]}" >&3
}
function maininstall() {
  local max_len=30
  local pkg="${1}"
  if [[ "${#pkg}" -gt "${max_len}" ]]; then
    pkg="${pkg:0:max_len}..."
  fi
  {
    echo $((n * 100 / total))
  } | whiptail --title "Installation in progress..." --gauge "Installing \"${pkg}\" (${n} of ${total}).\n\n${2}" 10 80 0
  if [[ "${3}" != '' ]]; then
    removePackage "${3}"
  fi
  installPackage "${1}"
}
function gitcloneinstall() {
  local url="${1}"
  local toPath="${2}"
  {
    echo $((n * 100 / total))
  } | whiptail --title "Installation in progress..." --gauge "Installing \"${url}\" (${n} of ${total}).\n\n${2}" 10 80 0

  sudo -u "${username}" bash -lc '
    set -euo pipefail

    [ -d "${HOME}/'"${toPath:?}"'" ] && rm -rf "${HOME}/'"${toPath:?}"'"
    git clone https://github.com/'"${url}"'.git "${HOME}"/'"${toPath}"' > /dev/null
  '
}
function getPinnedNerdFontsVersion() {
  local file="${scriptDir}/.nerd_font/version"
  if [[ ! -f "${file}" ]]; then
    abortInstallation "Missing pinned Nerd Fonts version file: ${file}"
  fi
  local version
  version="$(tr -d '\r\n' < "${file}")"
  version="${version//[[:space:]]/}"
  if [[ -z "${version}" || "${version}" =~ [^a-zA-Z0-9._-] ]]; then
    abortInstallation "Invalid pinned Nerd Fonts version in ${file}."
  fi
  printf '%s' "${version}"
}
function getPinnedNerdFontsChecksumsFile() {
  local f1="${scriptDir}/.nerd_font/sha256"
  if [[ -f "${f1}" ]]; then
    printf '%s' "${f1}"
    return
  fi
  abortInstallation "Missing pinned Nerd Fonts checksums file (.nerd_font/sha256 or .nerd_font/sha256)."
}
function _getExpectedSHA256() {
  local checksumsFile="${1}"
  local filename="${2}"
  # Format: <sha256><spaces><filename>
  awk -v fn="${filename}" '
    {
      # Handle CRLF files and optional leading "*" (binary mode output)
      f = $NF
      gsub(/\r$/, "", f)
      sub(/^\*/, "", f)
      sub(/^\.\//, "", f)
      if (f == fn) { print $1; exit 0 }
    }
  ' "${checksumsFile}"
}
function verifySHA256Checksum() {
  local filePath="${1}"
  local checksumsFile="${2}"

  if ! command -v sha256sum > /dev/null 2>&1; then
    abortInstallation "Missing dependency: sha256sum (coreutils)."
  fi

  local filename
  filename="$(basename "${filePath}")"

  local expected
  expected="$(_getExpectedSHA256 "${checksumsFile}" "${filename}")"
  if [[ -z "${expected}" ]]; then
    abortInstallation "Nerd Fonts checksum for '${filename}' was not found in '${checksumsFile}'."
  fi

  local actual
  actual="$(sha256sum "${filePath}" | awk '{ print $1 }')"
  if [[ "${actual}" != "${expected}" ]]; then
    abortInstallation "Checksum mismatch for '${filename}'.\n\nExpected: ${expected}\nActual:   ${actual}\n\nAborting to prevent installing a potentially tampered download."
  fi
}
function nerdfontinstall() {
  local fonts="${1}"
  local purpose="${2}"
  local fontsDir="/home/${username}/.local/share/fonts"
  local font_array
  IFS=' ' read -r -a font_array <<< "${fonts}"
  if [[ ! -d "${fontsDir}" ]]; then
    mkdir --parents --verbose "${fontsDir}" >&3
    chown -R "${username}:${username}" "${fontsDir}" >&3
  fi
  local version
  version="$(getPinnedNerdFontsVersion)"

  local checksumsFile
  checksumsFile="$(getPinnedNerdFontsChecksumsFile)"

  for font in "${font_array[@]}"; do
    if [[ -z "${font}" || "${font}" =~ [[:cntrl:]] || ! "${font}" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+-]*$ ]]; then
      abortInstallation "Invalid Nerd Font name: '${font}'"
    fi
    if [[ "${font}" == '.' || "${font}" == '..' || "${font}" == .* ]]; then
      abortInstallation "Invalid Nerd Font name: '${font}'"
    fi
    {
      echo $((n * 100 / total))
    } | whiptail --title "Installation in progress..." --gauge "Installing \"${font}\" (${n} of ${total}).\n\n${purpose}" 10 80 0
    if [[ -d "${fontsDir:?}"/"${font:?}" ]]; then
      rm --force --recursive --verbose "${fontsDir:?}"/"${font:?}" >&3
    fi
    local zipPath="${scriptTempDir:?}/${font:?}.zip"
    curl --fail --location --silent --show-error \
      --output "${zipPath}" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${font:?}.zip" >&3

    verifySHA256Checksum "${zipPath}" "${checksumsFile}"

    mkdir --verbose --parents "${fontsDir:?}"/"${font:?}" >&3
    unzip -o "${zipPath}" -d "${fontsDir:?}"/"${font:?}" >&3
    chown -R "${username}:${username}" "${fontsDir:?}"/"${font:?}" >&3
  done
  fc-cache --really-force >&3
}
function postInstallationLoop() {
  whiptail --title "Enabling services..." 10 80 0
  if pacman -Qq libvirt >&3; then
    systemctl enable libvirtd.service >&3
  fi
  if pacman -Qq cronie >&3; then
    systemctl enable cronie.service >&3
  fi
  if pacman -Qq openssh >&3; then
    systemctl enable sshd.service >&3
  fi
  if command -v ufw >&3 && pacman -Qq ufw >&3; then
    systemctl enable ufw.service >&3
    pacman -Qq openssh >&3 && ufw allow ssh >&3
    ufw default deny incoming >&3
    ufw default allow outgoing >&3
    ufw --force enable >&3
  fi
}
function installationloop() {
  local total

  total=$(jq length "${progsfile}")
  if [[ "${total}" -eq 0 ]]; then
    whiptail --title "Installation in progress..." --infobox "No programs to install. Skipping installation loop..." 10 80
    return
  fi

  n=0
  jq -c '.[]' "${progsfile}" | while read -r obj; do
    n=$((n + 1))
    type="$(jq -r '.type' <<< "${obj}")"
    purpose="$(jq -r '.purpose' <<< "${obj}")"

    case "${type}" in
      "github")
        repo="$(jq -r '.repo' <<< "${obj}")"
        dir="$(jq -r '.dir' <<< "${obj}")"
        gitcloneinstall "${repo}" "${dir}" "${purpose}"
        ;;
      "nerdfont")
        fonts="$(jq -r '.fonts | join(" ")' <<< "${obj}")"
        nerdfontinstall "${fonts}" "${purpose}"
        ;;
      *)
        conflicts="$(jq -r '.conflicts | join(" ")' <<< "${obj}")"
        packages="$(jq -r '.packages | join(" ")' <<< "${obj}")"
        maininstall "${packages}" "${purpose}" "${conflicts}"
        ;;
    esac
  done
}

function obtainTimezone() {
  timezone=$(whiptail --title "Timezone" --inputbox "First, please enter your timezone." 10 60 3>&1 1>&2 2>&3) || exit 1
  while [[ ! -f "/usr/share/zoneinfo/${timezone}" ]]; do
    timezone=$(whiptail --title "Timezone" --nocancel --inputbox "Timezone not valid. You can always check for your timezone in \"/usr/share/zoneinfo\" (e.g: America/New_York)" 10 70 3>&1 1>&2 2>&3)
  done
}
function configTimezone() {
  whiptail --title "Installation in progress..." --infobox "Configuring timezone..." 10 80
  ln --symbolic --force --verbose \
    /usr/share/zoneinfo/"${timezone}" \
    /etc/localtime >&3
  printf "%s\n" "${timezone}" | tee /etc/timezone >&3
  hwclock --systohc --verbose >&3
}

function obtainHostname() {
  hostname=$(whiptail --title "Hostname" --inputbox "Please, enter the desired hostname: " 10 60 3>&1 1>&2 2>&3) || exit 1
  while ! [[ "${hostname}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)$ && "${#hostname}" -le 253 ]]; do
    hostname=$(whiptail --title "Hostname" --nocancel --inputbox "Invalid hostname. Use only letters, numbers, and hyphens. Do not start or end with a hyphen. Max 253 characters, each part up to 63." 10 70 3>&1 1>&2 2>&3)
  done

  prettyHostname=$(whiptail --title "Hostname" --inputbox "Please, enter a human-readable machine identifier string for the hostname \"${hostname}\": " 10 60 3>&1 1>&2 2>&3) || exit 1
  while ! [[ "${prettyHostname}" =~ ^[^[:cntrl:]]{1,256}$ && "${prettyHostname}" =~ [^[:space:]] ]]; do
    prettyHostname=$(whiptail --title "Hostname" --nocancel --inputbox "Invalid pretty hostname. Can include spaces, accents, and symbols, but no line breaks or control characters. Max 256 characters." 10 70 3>&1 1>&2 2>&3)
  done

  chassis=$(
    whiptail --title "Pretty hostname - Chassis" --menu "Choose an option" 15 60 5 \
      "desktop" " I'm installing linux on a Desktop" \
      "laptop" " I'm installing linux on a Laptop" \
      "vm" " I'm installing linux on a VM" 3>&1 1>&2 2>&3
  ) || exit 1
}
function configHostname() {
  whiptail --title "Installation in progress..." --infobox "Configuring hostname..." 10 80
  printf "%s\n" "${hostname}" | tee /etc/hostname >&3
  {
    printf "# Static table lookup for hostnames.\n"
    printf "# See hosts(5) for details\n"
    printf "\n"
    printf "127.0.0.1    localhost\n"
    printf "::1          localhost\n"
    printf "127.0.1.1    %s.localhost    %s\n" "${hostname}" "${hostname}"
  } | tee /etc/hosts >&3
  {
    printf "PRETTY_HOSTNAME=\"%s\"\n" "${prettyHostname}"
    printf "ICON_NAME=computer\n"
    printf "CHASSIS=%s\n" "${chassis}"
    printf "DEPLOYMENT=production\n"
  } | tee /etc/machine-info >&3

  pacman --sync --needed networkmanager wpa_supplicant --noconfirm >&3
  systemctl enable NetworkManager.service >&3
}

function obtainBootLoader() {
  local disks
  local disk_menu=()
  local selected_disk
  local parts
  local parts_menu=()
  local selected_part
  local root_device

  bootLoader=$(
    whiptail --title "Bootloader" --menu "Choose an option" 15 60 5 \
      "1" "systemd-boot" \
      "2" "grub" 3>&1 1>&2 2>&3
  ) || exit 1

  mapfile -t disks < <(lsblk -dpno NAME,TYPE | awk '$2 == "disk" { print $1 }')
  [[ ${#disks[@]} -eq 0 ]] && abortInstallation "Nenhum disco encontrado."

  for d in "${disks[@]}"; do
    disk_menu+=("${d}" "")
  done

  if [[ ${#disks[@]} -eq 1 ]]; then
    selected_disk="${disks[0]}"
  else
    selected_disk=$(whiptail --title "Select root disk" \
      --menu "Choose the disk where the partition allocated to root (/) is located:" 15 60 6 \
      "${disk_menu[@]}" \
      3>&1 1>&2 2>&3) || cancelInstallation 'abortado'
  fi

  mapfile -t parts < <(lsblk -lnpo NAME,TYPE "${selected_disk}" | awk '$2 == "part" { print $1 }')
  [[ ((${#parts[@]} == 0)) ]] && abortInstallation "❌ Nenhuma partição encontrada em \"${selected_disk}\"."

  for d in "${parts[@]}"; do
    parts_menu+=("${d}" "")
  done

  if [[ ${#parts[@]} -eq 1 ]]; then
    selected_part="${parts[0]}"
  else
    selected_part=$(whiptail --title "Select root partition" \
      --menu "Choose the partition allocated to root (/):" 15 60 6 \
      "${parts_menu[@]}" \
      3>&1 1>&2 2>&3) || cancelInstallation 'abortado'
  fi

  partition_uuid=$(blkid -s UUID -o value "${selected_part}")
  partition_type=$(blkid -s TYPE -o value "${selected_part}")
  root_device=$(findmnt -n -o SOURCE /)
  root_device_uuid=$(blkid -s UUID -o value "${root_device}")
}
function obtainCPUVendor() {
  cpuVendor=$(
    whiptail --title "CPU Vendor" --menu "Choose an option" 15 60 5 \
      "intel" " Intel CPU" \
      "amd" " AMD CPU" 3>&1 1>&2 2>&3
  ) || cancelInstallation

}
function installMicrocode() {
  whiptail --title "Installation in progress..." --infobox "Installing microcode..." 10 80

  if [[ "${cpuVendor}" == "intel" ]]; then
    pacman --sync --needed intel-ucode --noconfirm >&3
  elif [[ "${cpuVendor}" == "amd" ]]; then
    pacman --sync --needed amd-ucode --noconfirm >&3
  fi
}
function configBootloader() {
  whiptail --title "Installation in progress..." --infobox "Configuring bootloader..." 10 80

  if [[ "${bootLoader}" == "1" ]]; then
    bootctl install >&3

    {
      printf "default      arch.conf\n"
      printf "timeout      1\n"
      printf "console-mode max\n"
      printf "editor       no\n"
    } | tee /boot/loader/loader.conf >&3
    if [[ "${partition_type}" == "crypto_LUKS" && "${root_device_uuid}" != "${partition_uuid}" ]]; then
      {
        printf "title   Arch Linux\n"
        printf "linux   /vmlinuz-linux\n"
        printf "initrd  /%s-ucode.img\n" "${cpuVendor}"
        printf "initrd  /initramfs-linux.img\n"
        printf 'options cryptdevice=UUID=%s:lvm root=UUID=%s rw\n' "${partition_uuid}" "${root_device_uuid}"
      } | tee /boot/loader/entries/arch.conf >&3
      {
        printf "title   Arch Linux (fallback initramfs)\n"
        printf "linux   /vmlinuz-linux\n"
        printf "initrd  /%s-ucode.img\n" "${cpuVendor}"
        printf "initrd  /initramfs-linux-fallback.img\n"
        printf 'options cryptdevice=UUID=%s:lvm root=UUID=%s rw\n' "${partition_uuid}" "${root_device_uuid}"
      } | tee /boot/loader/entries/arch-fallback.conf >&3
    else
      {
        printf "title   Arch Linux\n"
        printf "linux   /vmlinuz-linux\n"
        printf "initrd  /%s-ucode.img\n" "${cpuVendor}"
        printf "initrd  /initramfs-linux.img\n"
        printf 'options root=UUID=%s rw\n' "${root_device_uuid}"
      } | tee /boot/loader/entries/arch.conf >&3
      {
        printf "title   Arch Linux (fallback initramfs)\n"
        printf "linux   /vmlinuz-linux\n"
        printf "initrd  /%s-ucode.img\n" "${cpuVendor}"
        printf "initrd  /initramfs-linux-fallback.img\n"
        printf 'options root=UUID=%s rw\n' "${root_device_uuid}"
      } | tee /boot/loader/entries/arch-fallback.conf >&3
    fi

    mkinitcpio -p linux >&3
    systemctl enable systemd-boot-update.service >&3
  fi

  if [[ "${bootLoader}" == "2" ]]; then
    pacman --sync --needed --noconfirm grub efibootmgr >&3
    grub-install --target=x86_64-efi --efi-directory=/boot \
      --bootloader-id=GRUB --recheck >&3
    sed --expression 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' \
      --in-place /etc/default/grub >&3
    grub-mkconfig -o /boot/grub/grub.cfg >&3
  fi
}
function check_mkinitcipio_hooks() {
  if [[ "${partition_type}" == "crypto_LUKS" && "${root_device_uuid}" != "${partition_uuid}" ]]; then
    local lvm
    lvm=$(lsblk -no TYPE "$(findmnt -n -o SOURCE /)" | head -n1)

    if [[ "${lvm}" == "lvm" ]]; then
      if ! grep -q -E '(^HOOKS=.*lvm2.*)' /etc/mkinitcpio.conf; then
        abortInstallation "The 'lvm2' module is missing in '/etc/mkinitcpio.conf'. Please add it to your HOOKS."
      fi
    fi
    if ! grep -q -E '(^HOOKS=.*encrypt.*)' /etc/mkinitcpio.conf; then
      abortInstallation "The 'encrypt' hooks are missing in '/etc/mkinitcpio.conf'. Please add them to your HOOKS."
    fi
  fi
}

function configLocale() {
  whiptail --title "Installation in progress..." --infobox "Configuring locale..." 10 80

  if ! grep -q '^[^#]*en_US.UTF-8 UTF-8' /etc/locale.gen; then
    printf "en_US.UTF-8 UTF-8\n" | tee --append /etc/locale.gen >&3
  fi

  locale-gen >&3

  printf "LANG=en_US.UTF-8" | tee /etc/locale.conf >&3
}
function configKeyboardLayout() {
  whiptail --title "Installation in progress..." --infobox "Configuring console keyboard..." 10 80
  printf "KEYMAP=us-acentos\n" | tee /etc/vconsole.conf >&3
}
function configPackageManager() {
  whiptail --title "Installation in progress..." --infobox "Configuring pacman..." 10 80

  local multilib
  multilib=$(
    grep --line-number "\[multilib\]" /etc/pacman.conf \
      | head -1 \
      | cut --fields=1 --delimiter=:
  )
  sed --expression 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' \
    --expression 's/#Color/Color/g' \
    --expression 's/#CheckSpace/CheckSpace/g' \
    --expression 's/#VerbosePkgLists/VerbosePkgLists/g' \
    --expression 's/#UseSyslog/UseSyslog/g' \
    --in-place=.bak /etc/pacman.conf >&3

  if ! grep -q -E '^\s*ILoveCandy\s*$' /etc/pacman.conf; then
    if grep -q -E '^\s*VerbosePkgLists\s*$' /etc/pacman.conf; then
      sed -i "/^\s*VerbosePkgLists\s*$/a ILoveCandy" /etc/pacman.conf >&3
    elif grep -q -E '^\s*#\s*VerbosePkgLists\s*$' /etc/pacman.conf; then
      sed -i "/^\s*#\s*VerbosePkgLists\s*$/a ILoveCandy" /etc/pacman.conf >&3
    else
      printf "\nILoveCandy\n" | tee --append /etc/pacman.conf >&3
    fi
  fi

  if [[ -n "${multilib}" ]]; then
    sed --expression "${multilib}s/^#//g" \
      --expression "$((multilib + 1))s/^#//g" \
      --in-place /etc/pacman.conf >&3
  else
    {
      printf '\n\n'
      printf '[multilib]\n'
      printf 'Include = /etc/pacman.d/mirrorlist\n'
    } | tee --append /etc/pacman.conf >&3
  fi
}
function configSudo() {
  whiptail --title "Installation in progress..." --infobox "Configuring sudo..." 10 80

  local tmp
  tmp=$(mktemp)

  {
    printf '%%wheel ALL=(ALL:ALL) ALL\n'
    printf '\n'
    printf 'Defaults lecture=always\n'
    printf 'Defaults insults\n'
  } | tee "${tmp}" > /dev/null

  chmod 440 "${tmp}" >&3

  if ! visudo --check --file "${tmp}" > /dev/null 2>&1; then
    rm -f "${tmp}"
    abortInstallation "Syntax error in generated sudoers fragment."
  fi

  install -m 440 "${tmp}" /etc/sudoers.d/10-custom >&3
  rm -f "${tmp}"

  if ! visudo --check > /dev/null 2>&1; then
    abortInstallation "Global sudoers validation failed after installing /etc/sudoers.d/10-custom."
  fi
}
function configFiles() {
  whiptail --title "Installation in progress..." --infobox "Replacing config files..." 10 80

  cp --recursive --verbose \
    "${scriptDir}"/data/etc/X11 \
    "${scriptDir}"/data/etc/modules-load.d \
    "${scriptDir}"/data/etc/pam.d \
    "${scriptDir}"/data/etc/pulse \
    "${scriptDir}"/data/etc/systemd \
    "${scriptDir}"/data/etc/tmpfiles.d \
    /etc >&3
}
function configDefaultHomeDirectories() {
  whiptail --title "Installation in progress..." --infobox "Replacing default directories..." 10 80

  rm --force --recursive --verbose /etc/skel/* >&3

  mkdir --verbose \
    /etc/skel/.config \
    /etc/skel/.local \
    /etc/skel/.local/bin \
    /etc/skel/.local/share/ \
    /etc/skel/.local/share/BLAST \
    /etc/skel/.local/share/fonts \
    /etc/skel/.local/share/icons \
    /etc/skel/.local/share/themes \
    /etc/skel/Desktop \
    /etc/skel/Documents \
    /etc/skel/Downloads \
    /etc/skel/Music \
    /etc/skel/Pictures \
    /etc/skel/Pictures/Screenshots \
    /etc/skel/Pictures/Wallpapers \
    /etc/skel/Projects \
    /etc/skel/Public \
    /etc/skel/Templates \
    /etc/skel/Videos \
    /etc/skel/Virtual\ Machines \
    /etc/skel/Virtual\ Machines/Disks \
    /etc/skel/Virtual\ Machines/Images \
    /etc/skel/Work >&3
}
function configXDGBaseDirectory() {
  whiptail --title "Installation in progress..." --infobox "Configuring XDGBaseDir..." 10 80

  {
    printf "#!/usr/bin/env sh\n"
    printf "\n"
    printf "# Default Editor\n"
    printf "export EDITOR=nvim\n"
    printf "\n"
    printf "# XDG Base Directory\n"
    printf "export XDG_CONFIG_HOME=\"\${HOME}\"/.config\n"
    printf "export XDG_CACHE_HOME=\"\${HOME}\"/.local/cache\n"
    printf "export XDG_DATA_HOME=\"\${HOME}\"/.local/share\n"
    printf "export XDG_STATE_HOME=\"\${HOME}\"/.local/state\n"
  } | tee /etc/skel/.profile >&3
}

function obtainUser() {
  username=$(whiptail --title "Username" --inputbox "Please enter the username of the targeted user" 10 60 3>&1 1>&2 2>&3) || exit 1
  while ! [[ "${username}" =~ ^[a-z_][a-z0-9_-]*$ ]]; do
    username=$(whiptail --title "Username" --nocancel --inputbox "Invalid username. It must begin with a letter, contain only lowercase letters, numbers, hyphens, or underscores." 10 60 3>&1 1>&2 2>&3)
  done
}
function obtainUserAndPassword() {
  username=$(whiptail --title "Username" --inputbox "Please enter a username for the account." 10 60 3>&1 1>&2 2>&3) || exit 1
  while ! [[ "${username}" =~ ^[a-z_][a-z0-9_-]*$ ]]; do
    username=$(whiptail --title "Username" --nocancel --inputbox "Invalid username. It must begin with a letter, contain only lowercase letters, numbers, hyphens, or underscores." 10 60 3>&1 1>&2 2>&3)
  done
  name=$(whiptail --title "Username" --inputbox "Please enter a name for the \"${username}\" account." 10 60 3>&1 1>&2 2>&3) || exit 1
  while [[ -z "${name}" || "${name}" =~ ^[[:space:]] || "${name}" =~ [[:space:]]$ ]]; do
    name=$(whiptail --title "Username" --nocancel --inputbox "Invalid name." 10 60 3>&1 1>&2 2>&3)
  done
  password1=$(whiptail --title "Username" --nocancel --passwordbox "Enter a password for \"${username}\"." 10 60 3>&1 1>&2 2>&3)
  password2=$(whiptail --title "Username" --nocancel --passwordbox "Retype password for \"${username}\"." 10 60 3>&1 1>&2 2>&3)
  while [[ -z "${password1}" || -z "${password2}" || "${password1}" != "${password2}" ]]; do
    unset -v password2 password1
    password1=$(whiptail --title "Username" --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3)
    password2=$(whiptail --title "Username" --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3)
  done
}
function checkUserExists() {
  ! { id -u "${username}" >&3; } \
    || whiptail --title "WARNING" --yes-button "CONTINUE" \
      --no-button "No wait..." \
      --yesno "The user \`${username}\` already exists on this system. BLAST can install for a user already existing, but it will OVERWRITE any conflicting settings/dotfiles on the user account.\\n\\BLAST will NOT overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that BLAST will change ${username}'s password to the one you just gave." 14 70
}
function configUser() {
  whiptail --title "Installation in progress..." --infobox "Configuring username..." 10 80
  if ! id -u "${username}" >&3; then
    useradd --comment "${name}" \
      --create-home \
      --groups wheel \
      --shell /bin/zsh \
      "${username}" >&3
  else
    usermod --append --groups wheel \
      --comment "${name}" \
      --shell /bin/zsh \
      "${username}" >&3
    mkdir -p /home/"${username}" && {
      chown "${username}":wheel /home/"${username}"
    }
  fi

  printf '%s:%s\n' "${username}" "${password1}" | chpasswd --crypt-method SHA512

  unset password1 password2
}

function cloneConfigFiles() {
  whiptail --title "Installation in progress..." --infobox "Configuring dotfiles..." 10 80
  sudo -u "${username}" bash -lc '
    set -euo pipefail

    [ -d "${HOME}"/.local/share/BLAST/dotfiles ] && rm -rf "${HOME}"/.local/share/BLAST/dotfiles
    mkdir --parents "${HOME}"/.local/share/BLAST/dotfiles > /dev/null
    git clone --bare https://github.com/gabrielgnsilva/dotfiles -b dev "${HOME}"/.local/share/BLAST/dotfiles > /dev/null
    git --git-dir="${HOME}"/.local/share/BLAST/dotfiles --work-tree="${HOME}" checkout -f > /dev/null
    sed --expression "s/CURRENTUSERNAME/'"${username}"'/g" \
      --in-place "${HOME}"/.config/gtk-3.0/bookmarks
  '
}

function system_setup() {
  # Welcome the user and obtain the necessary data *before* processing it
  welcome
  obtainTimezone
  obtainHostname
  obtainCPUVendor
  obtainBootLoader
  check_mkinitcipio_hooks
  obtainUserAndPassword
  checkUserExists
  confirmInstall

  # Install
  refreshKeys
  configTimezone
  configHostname
  installMicrocode
  configBootloader
  configLocale
  configKeyboardLayout
  configPackageManager
  configSudo
  configFiles
  configDefaultHomeDirectories
  configXDGBaseDirectory
  configUser

  # End installation
  finalize
}

function programs_setup() {
  # Welcome the user and obtain the necessary data *before* processing it
  welcome
  obtainUser
  confirmInstall

  installationloop
  postInstallationLoop

  # End installation
  finalize
}

function full_setup() {
  # Welcome the user and obtain the necessary data *before* processing it
  welcome
  obtainTimezone
  obtainHostname
  obtainCPUVendor
  obtainBootLoader
  check_mkinitcipio_hooks
  obtainUserAndPassword
  checkUserExists
  confirmInstall

  # Install
  refreshKeys
  configTimezone
  configHostname
  installMicrocode
  configBootloader
  configLocale
  configKeyboardLayout
  configPackageManager
  configSudo
  configFiles
  configDefaultHomeDirectories
  configXDGBaseDirectory
  configUser
  installationloop
  postInstallationLoop
  cloneConfigFiles

  # End installation
  finalize
}
# regionend

# region: Main Program
function _main() {
  if [[ "${#}" -lt 1 ]]; then
    displayHelp "usage"
  fi
  local i
  for i in "${@}"; do
    case "${i}" in
      -h | --help | help)
        displayHelp 'full'
        ;;
      -v | --version | version)
        displayHelp 'version'
        ;;
      *) : ;;
    esac
  done

  # region: Options logic (Define options logic here)
  cd "${scriptDir}" || exit 1
  local option
  progsfile="${scriptDir}/data/packages.json"
  while [[ "${#}" -gt 0 ]]; do
    case "${1:-}" in
      -s | --setup)
        shift
        if [[ ! "${1:-}" =~ ^(f|full|p|programs|s|system)$ ]]; then
          error "${msgInvalid} \"${1:-}\"\n${msgTryHelp}"
        fi
        option="${1}"
        ;;
      -p | --programs-file)
        shift
        if [[ ! -f "${1}" ]]; then
          error "${msgInvalid} \"${1:-}\"\n${msgTryHelp}"
        fi
        progsfile="${1}"
        ;;
      *)
        error "${msgInvalid} \"${1:-}\". ${msgTryHelp}"
        ;;
    esac
    shift
  done
  # regionend

  # Install dependencies.
  pacman --noconfirm --needed --sync --refresh sudo jq libnewt git unzip curl \
    || error "Please ensure you are running this script as the root user, on an Arch-based distribution, and have an active internet connection."

  # region: Script logic (Define script logic here)
  if [[ "${option}" =~ ^(f|full)$ ]]; then
    full_setup
  fi

  if [[ "${option}" =~ ^(p|programs)$ ]]; then
    programs_setup
  fi

  if [[ "${option}" =~ ^(s|system)$ ]]; then
    system_setup
  fi
  # regionend
}
# regionend

# region: Invoke main with args only if not sourced
if ! (return 0 2> /dev/null); then
  _initVariables "${@}"
  _initLogger "${@}"
  _setTraps
  _traceVariables "${@}"
  _enforceScriptDir "${@}"
  _main "${scriptParams[@]}"
fi
# regionend
