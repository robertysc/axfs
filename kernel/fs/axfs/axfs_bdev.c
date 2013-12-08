/*
 * Advanced XIP File System for Linux - AXFS
 *   Readonly, compressed, and XIP filesystem for Linux systems big and small
 *
 * Copyright(c) 2008 Numonyx
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * Authors:
 *  Jared Hulbert <jaredeh@gmail.com>
 *
 * Project url: http://axfs.sourceforge.net
 *
 * axfs_bdev.c -
 *   Allows axfs to use block devices or has dummy functions if block
 *   device support is compiled out of the kernel.
 *
 */
#include "axfs.h"

#include <linux/mount.h>
#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,18)
#else
#define CONFIG_BLOCK
#endif
#ifdef CONFIG_BLOCK
#include <linux/buffer_head.h>
#include <linux/namei.h>

struct block_device *axfs_bdev(struct super_block *sb)
{
	return sb->s_bdev;
}

int axfs_has_bdev(struct super_block *sb)
{
	if (axfs_bdev(sb) == NULL)
		return false;

	return true;
}

#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,38)
struct dentry *axfs_get_sb_bdev(struct file_system_type *fs_type, int flags,
		     const char *dev_name, struct axfs_super *sbi)
#else
int axfs_get_sb_bdev(struct file_system_type *fs_type, int flags,
		     const char *dev_name, struct axfs_super *sbi,
		     struct vfsmount *mnt, int *err)
#endif
{
#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,38)
	return mount_bdev(fs_type, flags, dev_name, sbi, axfs_fill_super);
#else
#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,17)
	*err = get_sb_bdev(fs_type, flags, dev_name, sbi, axfs_fill_super, mnt);

	if (*err)
		return false;
#else
	mnt->mnt_sb =
	    get_sb_bdev(fs_type, flags, dev_name, (void *)sbi, axfs_fill_super);
	if (IS_ERR(mnt->mnt_sb)) {
		*err = PTR_ERR(mnt->mnt_sb);
		return false;
	}
#endif
	return true;
#endif
}

void axfs_kill_block_super(struct super_block *sb)
{
	kill_block_super(sb);
}

void axfs_copy_block(struct super_block *sb, void *dst_addr, u64 fsoffset,
		     u64 len)
{
	struct axfs_super *sbi = AXFS_SB(sb);
	u64 boffset = axfs_fsoffset_to_devoffset(sbi, fsoffset);
	u64 blksize = sb->s_blocksize;
	unsigned long dst;
	unsigned long src;
	sector_t block;
	size_t bytes;
	struct buffer_head *bh;
	u64 copied = 0;

	if (len == 0)
		return;

	while (copied < len) {
		block = boffset + copied;
		block = do_div(block, blksize);
		bh = sb_bread(sb, block);
		src = (unsigned long)bh->b_data;
		dst = (unsigned long)dst_addr;
		if (copied == 0) {
			/* Explicit casting for ARM linker errors. */
			bytes = (size_t) blksize;
			bytes -= (size_t) boffset % (size_t) blksize;
			if (bytes > len)
				bytes = len;
			/* Explicit casting for ARM linker errors. */
			src += (unsigned long)boffset % (unsigned long)blksize;
		} else {
			dst += copied;
			if ((len - copied) < blksize)
				bytes = len - copied;
			else
				bytes = blksize;
		}
		memcpy((void *)dst, (void *)src, bytes);
		copied += bytes;
		brelse(bh);
	}
}
#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,38)
#else

int axfs_is_dev_bdev(char *path)
{
	struct nameidata nd;
	int ret = false;

	if (!path)
		return false;

	if (path_lookup(path, LOOKUP_FOLLOW, &nd))
		return false;

#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,24)
	if (S_ISBLK(nd.path.dentry->d_inode->i_mode))
#else
	if (S_ISBLK(nd.dentry->d_inode->i_mode))
#endif
		ret = true;

#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,24)
	path_put(&nd.path);
#else
	path_release(&nd);
#endif
	return ret;
}
#endif

int axfs_verify_bdev_sizes(struct super_block *sb, int *err)
{
	u64 io_dev_size;
	loff_t bdev_size;

	*err = 0;

	if (!axfs_has_bdev(sb))
		return false;

	io_dev_size = axfs_get_io_dev_size(sb);

	if (!io_dev_size)
		return false;

	bdev_size = i_size_read(axfs_bdev(sb)->bd_inode);
	if (io_dev_size <= bdev_size)
		return true;

	printk(KERN_ERR "axfs: image (%lluB) doesn't fit in blkdev(%lluB)\n",
	       io_dev_size, bdev_size);
	*err = -EIO;
	return true;
}

#else

int axfs_get_sb_bdev(struct file_system_type *fs_type, int flags,
		     const char *dev_name, struct axfs_super *sbi,
		     struct vfsmount *mnt, int *err)
{
	return false;
}

void axfs_kill_block_super(struct super_block *sb)
{
}

int axfs_copy_block(struct super_block *sb, void *dst_addr, u64 fsoffset,
		    u64 len)
{
	return -EINVAL;
}
#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,38)
#else

int axfs_is_dev_bdev(char *path)
{
	return false;
}
#endif

int axfs_verify_bdev_sizes(struct super_block *sb, int *err)
{
	*err = 0;
	return true;
}

#endif /* CONFIG_BLOCK */
