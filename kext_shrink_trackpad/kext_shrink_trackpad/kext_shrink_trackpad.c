/*
 * This file is part of the https://github.com/cocoahuke/shrink_trackpad distribution
 * Copyright (c) 2018 cocoahuke.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
//
//  kext_shrink_trackpad.c
//  kext_shrink_trackpad
//  Copyright © 2018 cocoahuke All rights reserved.
//

#include <mach/mach_types.h>
#include <sys/types.h>
#include <sys/conf.h>
#include <miscfs/devfs/devfs.h>
#include <libkern/libkern.h>
#include <sys/proc.h>
#include <sys/kauth.h>
#include <sys/ioccom.h>
#include <sys/errno.h>
#include <sys/vnode.h>

mach_vm_offset_t kaslr = 0;
int16_t ignore_Xaxis_left = 0, ignore_Xaxis_right = 0;
int16_t ignore_Yaxis_up = 0, ignore_Yaxis_down = 0;

uint64_t (*orig_AppleMultitouchDevice__handleTouchFrame)(void *this, void *a2, void *a3, void *a4) = NULL;
uint64_t my_AppleMultitouchDevice__handleTouchFrame(void *this, void *framedata_arg, uint32_t *framedata_len_ptr, void *a4){
    
    if(framedata_len_ptr){
        void *framedata = framedata_arg;
        uint32_t framedata_len = *framedata_len_ptr;
        
        if(framedata_len >= 0x44 && !(ignore_Xaxis_left == ignore_Xaxis_right && ignore_Xaxis_right == ignore_Yaxis_up && ignore_Yaxis_up == ignore_Yaxis_down)){
            
            framedata_len -= 0x26; framedata += 0x26;
            int nfinger = framedata_len/0x1E;
            for(int i=0; i<nfinger; i++){
                char *finger_data = framedata + 0x1E * i;
                int8_t iden = *(int8_t*)(finger_data);
                int8_t stat = *(int8_t*)(finger_data + 0x1);
                int16_t raw_x = *(int16_t*)(finger_data + 0x4);
                int16_t raw_y = *(int16_t*)(finger_data + 0x6);
                
                if (ignore_Xaxis_left <= raw_x && raw_x <= ignore_Xaxis_right && ignore_Yaxis_down <= raw_y && raw_y <= ignore_Yaxis_up){
                }else{
                    *(int8_t*)(finger_data + 0x1) = 0;
                }
            }
        }
    }
    
    return orig_AppleMultitouchDevice__handleTouchFrame(this, framedata_arg, framedata_len_ptr, a4);
}

static int shrinkTP_open(dev_t dev, int flags, int devtype, struct proc *p) {
    return 0;
}

static int shrinkTP_close(dev_t dev, int flags, int devtype, struct proc *p) {
    return 0;
}

#define shrinkTP_CMD_KASLR        _IOWR(74728, 1, mach_vm_address_t)
#define shrinkTP_CMD_INIT        _IOWR(74728, 2, mach_vm_address_t)
#define shrinkTP_CMD_ADJUST        _IOWR(74728, 3, uint64_t)
static int shrinkTP_ioctl(dev_t dev, u_long cmd, caddr_t data, int fflag, struct proc *p){

    if(kauth_getuid() != 0)
        return EPERM;
    
    switch (cmd) {
        case shrinkTP_CMD_KASLR:{
            if(kaslr == 0){
                mach_vm_address_t vnode_close_addr = *(mach_vm_address_t*)data;
                kaslr = (mach_vm_address_t)vnode_close - vnode_close_addr;
            }
        }break;
        case shrinkTP_CMD_INIT:{
            if(kaslr != 0 && orig_AppleMultitouchDevice__handleTouchFrame == NULL){
                mach_vm_address_t vtable_addr = *(mach_vm_address_t*)data;
                mach_vm_address_t *vtable_addr_inMem = vtable_addr + kaslr;
                
                orig_AppleMultitouchDevice__handleTouchFrame = *vtable_addr_inMem;
                *vtable_addr_inMem = my_AppleMultitouchDevice__handleTouchFrame;
            }
        }break;
        case shrinkTP_CMD_ADJUST:{
            uint64_t data_ = *(mach_vm_address_t*)data;
            
            ignore_Yaxis_down = data_;
            ignore_Yaxis_up = data_ >> 16;
            ignore_Xaxis_right = data_ >> 32;
            ignore_Xaxis_left = data_ >> 48;
            
        }break;
    }
    
    return 0;
}

static struct cdevsw shrinkTP_device = {
    shrinkTP_open,  // open
    shrinkTP_close, // close
    eno_rdwrt,  // read
    eno_rdwrt,  // write
    shrinkTP_ioctl, // ioctl
    eno_stop,   // stop
    eno_reset,  // reset
    0,          // ttys
    eno_select, // select
    eno_mmap,   // mmap
    eno_strat,  // strategy
    eno_getc,   // getc
    eno_putc,   // putc
    0           // type
};

kern_return_t kext_shrink_trackpad_start(kmod_info_t * ki, void *d);
kern_return_t kext_shrink_trackpad_stop(kmod_info_t *ki, void *d);

int dp; void *dn;

kern_return_t kext_shrink_trackpad_start(kmod_info_t * ki, void *d)
{
    dp = cdevsw_add(-1, &shrinkTP_device);
    if(dp == -1){
        return KERN_FAILURE;
    }
    
    dn = devfs_make_node(makedev(dp, 0), DEVFS_CHAR, UID_ROOT, GID_WHEEL, 0666, "shrinkTP");
    
    return KERN_SUCCESS;
}

kern_return_t kext_shrink_trackpad_stop(kmod_info_t *ki, void *d)
{
    if(dn){
        devfs_remove(dn);
    }
    
    if(dp != -1){
        cdevsw_remove(dp, &shrinkTP_device);
    }
    return KERN_SUCCESS;
}
