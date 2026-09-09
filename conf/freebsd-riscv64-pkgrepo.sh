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
