#!/bin/sh

# interface:
# cd to top of tree
# sh ./build/do_build.sh
# magic happens :)
#

cd "$(dirname "$0")/.."

export root=$(pwd)
export FREENAS_ROOT=$root
: ${FREENAS_ARCH=$(uname -p)}
export NANO_LABEL="FreeNAS"
export FREENAS_ARCH
export NANO_CFG_BASE=$FREENAS_ROOT/nanobsd
export NANO_SRC=$FREENAS_ROOT/FreeBSD/src
export NANO_OBJ=${root}/obj.${FREENAS_ARCH}
PREP_SOURCE=${PREP_SOURCE:-""}

. build/functions.sh

# Make sure we have FreeBSD dirs
if [ ! -d FreeBSD ]; then
    mkdir FreeBSD
    mkdir FreeBSD/src
    mkdir FreeBSD/ports
fi

# Make sure we have FreeBSD src, fetch using csup if not
if [ ! -f FreeBSD/supfile -o -n "$force_update" ]; then
    if [ -z "$FREEBSD_CVSUP_HOST" ]; then
        echo "No sup host defined, please define FREEBSD_CVSUP_HOST and rerun"
        exit 1
    fi
    echo "Checking out tree from ${FREEBSD_CVSUP_HOST}..."
    cat <<EOF > FreeBSD/supfile
*default host=${FREEBSD_CVSUP_HOST}
*default base=${root}/FreeBSD/sup
*default prefix=${root}/FreeBSD
*default release=cvs
*default delete use-rel-suffix

src-all tag=RELENG_8_2
ports-all date=2011.07.17.00.00.00
EOF
    csup -L 1 ${root}/FreeBSD/supfile
# cvsup fixes any changes we make, it seems.  Repatch
    rm -f ${root}/FreeBSD/src-patches
    rm -f ${root}/FreeBSD/ports-patches
fi

# Make sure that all the patches are applied
touch ${root}/FreeBSD/src-patches
for i in $(cd ${root}/patches && echo freebsd-*.patch); do
    if ! grep $i ${root}/FreeBSD/src-patches > /dev/null 2>&1; then
        echo "Applying patch $i..."
        (cd FreeBSD/src && patch -p0 < ${root}/patches/$i)
        echo $i >> ${root}/FreeBSD/src-patches
    fi
done
touch ${root}/FreeBSD/ports-patches
for i in $(cd ${root}/patches && echo ports-*.patch); do
    if ! grep $i ${root}/FreeBSD/ports-patches > /dev/null 2>&1; then
        echo "Applying patch $i..."
        (cd FreeBSD/ports && patch -p0 < ${root}/patches/$i)
        echo $i >> ${root}/FreeBSD/ports-patches
    fi
done

if [ -n "${PREP_SOURCE}" ]; then
    exit
fi

# OK, now we can build
cd FreeBSD/src
args="-c ../../nanobsd/freenas-common"
: ${MAKE_JOBS=$(( 2 * $(sysctl -n kern.smp.cpus) + 1 ))}
args="$args -j $MAKE_JOBS"
if [ `whoami` != "root" ]; then
    echo "You must be root to run this"
    exit 1
fi
if [ -d ${NANO_OBJ} ]; then
	extra_args="-b"
fi
for i in $*; do
	case $i in
	-f)
		extra_args="" ;;
	*)	args="$args $i" ;;
	esac
	
done
echo $FREENAS_ROOT/build/nanobsd/nanobsd.sh $args $extra_args
if sh "$FREENAS_ROOT/build/nanobsd/nanobsd.sh" $args $extra_args; then
	echo "$NANO_LABEL build PASSED"
else
	error "$NANO_LABEL build FAILED; please check above log for more details"
fi
