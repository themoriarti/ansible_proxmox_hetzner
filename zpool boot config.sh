zpool create -f\
    -o ashift=12 \
    -o autotrim=on \
    -o compatibility=grub2 \
    -o cachefile=/etc/zfs/zpool.cache \
    -o feature@extensible_dataset=disabled \
    -o feature@bookmarks=disabled \
    -o feature@filesystem_limits=disabled \
    -o feature@large_blocks=disabled \
    -o feature@large_dnode=disabled \
    -o feature@sha512=disabled \
    -o feature@skein=disabled \
    -o feature@edonr=disabled \
    -o feature@userobj_accounting=disabled \
    -o feature@encryption=disabled \
    -o feature@project_quota=disabled \
    -o feature@obsolete_counts=disabled \
    -o feature@bookmark_v2=disabled \
    -o feature@redaction_bookmarks=disabled \
    -o feature@redacted_datasets=disabled \
    -o feature@bookmark_written=disabled \
    -o feature@livelist=disabled \
    -o feature@zstd_compress=disabled \
    -o feature@zilsaxattr=disabled \
    -o feature@head_errlog=disabled \
    -o feature@blake3=disabled \
    -o feature@vdev_zaps_v2=disabled \
    -o feature@hole_birth=disabled \
    -O devices=off \
    -O acltype=posixacl -O xattr=sa \
    -O compression=lz4 \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off \
    -O mountpoint=/boot -R /mnt \
    bpool mirror \
    ${DISK1}-part2 \
    ${DISK2}-part2