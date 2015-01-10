function error()
{
    local msg=$1
    local nofunc=$2
    local -i start=1

    echo -n "ERROR"

    if [ -z $nofunc ]; then
        echo -n " : ${FUNCNAME[$start]}()"
    fi

    if [[ -n $msg ]]; then
        echo " : $msg"
    fi

    if [ -n $nofunc ]; then
        exit
    fi

    local -i end=${#BASH_SOURCE[@]}
    local -i i=0
    local -i j=0

    for((i=${start}; i<${end}; i++)); do
        j=$(($i-1))
        local func="${FUNCNAME[$i]}"
        local file="${BASH_SOURCE[$i]}"
        local line="${BASH_LINENO[$j]}"
        echo " ${func}() : ${file} : ${line}" 1>&2
    done 
    exit
}

function getprop
{
    local propname=$1

    if [ -z $propname ]; then error "property name missing"; fi

    $adb wait-for-device
    local prop=$(adb shell getprop $propname | tr -d '\r')

    echo -n $prop
}

function intent()
{
    local action=$1
    local arg=$2

    $adb wait-for-device
    $adb shell am start -a android.intent.action.$action -d $arg
}

function remount()
{
    local mode=$1
    local dir=$2

    if [ -z "$mode" ]; then error "mode not set"; fi
    if [ $mode != "ro" ] && [ $mode != "rw" ]; then error "invalid mode"; fi
    if [ -z "$dir" ]; then error "dir not set"; fi

    $adb wait-for-device
    adb shell su -c "mount -o remount,$mode auto $dir"
}

# ...and let's hope it's not the old shit from android-sdk-linux...
adb=`which adb`
if [ -z "$adb" ]; then
    error "adb not found" 1
fi

if [ -z "$($adb devices 2>&1 | tail -n +2 | sed '/^$/d')" ]; then
    error "No devices found" 1
fi
