# In-guest install script for the FreeBSD 15.x riscv64 images (piped into
# the guest sh by build.py with ANYVM_PKGS prepended).
#
# pkg.FreeBSD.org publishes NO riscv64 packages, so these images used to
# ship with none at all and could offer only the package-less sync
# methods. anyvm-org/freebsd-pkg-repo builds the ports tree for
# FreeBSD:15:riscv64 with poudriere under qemu-user and publishes the
# packages as GitHub release assets, signed with an ECDSA key; this
# script points pkg at that repository and then installs ANYVM_PKGS from
# it.
#
# The repository is sharded because a GitHub release holds a limited
# number of assets: anyvm.conf carries one repository block per shard, so
# it grows as the tree is built out. The copy baked in here is the one
# that existed when the image was built -- packages published into LATER
# shards are invisible until the image is rebuilt, or until the user
# refetches anyvm.conf from the index release (the URL below).
set -e

INDEX=https://github.com/anyvm-org/freebsd-pkg-repo/releases/download/idx-FreeBSD-15-riscv64
KEY_SHA256=a9e2f84083b916f0f9f2bda18ebf9cc581cfb28aaadb6827836f1ddc672a3040

mkdir -p /usr/local/etc/pkg/repos /usr/local/etc/pkg/keys

# Bounded retries: this is the guest's first network call of the build.
n=0
until fetch -q -o /usr/local/etc/pkg/keys/anyvm.pub "$INDEX/repo.pub" &&
      fetch -q -o /usr/local/etc/pkg/repos/anyvm.conf "$INDEX/anyvm.conf"; do
    n=$((n + 1))
    if [ "$n" -ge 5 ]; then
        echo "FATAL: cannot fetch the riscv64 package repository index" >&2
        exit 1
    fi
    echo "index fetch failed (attempt $n); retrying in 10s" >&2
    sleep 10
done

# The key is the whole trust anchor: a wrong or truncated one makes pkg
# reject every catalogue ("Invalid signature, removing repository"), so
# check it here where the message is readable instead of at first use.
got=$(sha256 -q /usr/local/etc/pkg/keys/anyvm.pub)
if [ "$got" != "$KEY_SHA256" ]; then
    echo "FATAL: repo.pub is $got, expected $KEY_SHA256" >&2
    exit 1
fi

# 15.0's riscv64 VM image ships only pkg's bootstrapper stub, and the
# bootstrap it wants (pkg.FreeBSD.org's Latest/pkg.pkg for
# FreeBSD:15:riscv64) does not exist -- the install step then fails with
# "The package management tool is not yet installed on your system". The
# index release carries the same package under a stable name for exactly
# this: extract pkg-static from it and let it register itself. 15.1 ships
# pkg already (pkgbase) and skips all of this.
if [ ! -x /usr/local/sbin/pkg-static ]; then
    echo "no pkg on this image; bootstrapping from $INDEX/pkg.pkg"
    fetch -q -o /tmp/pkgboot.pkg "$INDEX/pkg.pkg" || {
        echo "FATAL: cannot fetch the pkg bootstrap package" >&2
        exit 1
    }
    mkdir -p /tmp/pkgboot
    tar -x -f /tmp/pkgboot.pkg -C /tmp/pkgboot /usr/local/sbin/pkg-static 2>/dev/null ||
    tar -x -f /tmp/pkgboot.pkg -C /tmp/pkgboot usr/local/sbin/pkg-static || {
        echo "FATAL: pkg-static is not in the bootstrap package" >&2
        exit 1
    }
    /tmp/pkgboot/usr/local/sbin/pkg-static add /tmp/pkgboot.pkg
    pkg -v
fi

# On 15.x the stock repositories are the pkgbase set, and FreeBSD-ports is
# enabled by default. It has nothing for riscv64, and leaving it on makes
# every pkg update end in "Error updating repositories!" -- a non-zero
# exit that fails the install step below, and noise for the user forever
# after.
cat > /usr/local/etc/pkg/repos/FreeBSD.conf <<'CONF'
FreeBSD-ports: { enabled: no }
FreeBSD-ports-kmods: { enabled: no }
FreeBSD-base: { enabled: no }
CONF

echo "package repository: $(grep -c 'url:' /usr/local/etc/pkg/repos/anyvm.conf) shards from $INDEX"
pkg update
pkg install -y $ANYVM_PKGS
