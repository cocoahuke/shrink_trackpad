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

#import <Cocoa/Cocoa.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

int dd = -1;
int global_get_shrinkdev(){
    if(dd == -1)
        dd = open("/dev/shrinkTP", O_RDONLY);
    return dd;
}

const char *datafilePath = NULL;
const char *global_get_datafilePath(){
    if(datafilePath == NULL){
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSLocalDomainMask, YES);
        const char *datafilePath_ = [[[paths firstObject] stringByAppendingString:@"/shrinkTrackpad/shrinkdata"] cStringUsingEncoding:NSUTF8StringEncoding];
        datafilePath = malloc(strlen(datafilePath_) + 1);
        strcpy((char*)datafilePath, datafilePath_);
    }
    return datafilePath;
}

void *file_read_with_offset(const char *filepath, uint32_t read_offset, uint32_t read_size){
    
    FILE *fp = fopen(filepath, "ro");
    if(!fp)
        return NULL;
    fseek(fp, read_offset, SEEK_SET);
    
    void *databuf = malloc(read_size);
    bzero(databuf, read_size);
    
    fread(databuf, 1, read_size, fp);
    fclose(fp);
    return databuf;
}

mach_vm_address_t obtain_vnode_close_static_addr(){
    const char *kernel_file_path = "/System/Library/Kernels/kernel";
    if(access(kernel_file_path, F_OK)){
        printf("file not exist\n");
        exit(1);
    }
    
    mach_vm_offset_t _vnode_close_func_addr = 0;
    
    struct mach_header_64 *kernel_macho_header = file_read_with_offset(kernel_file_path, 0, 0x2000);
    if(!kernel_macho_header){
        printf("kernel_macho_header empty\n");
        exit(1);
    }
    
    const uint32_t cmd_count = kernel_macho_header->ncmds;
    struct load_command *cmds = (struct load_command*)((char*)kernel_macho_header+sizeof(struct mach_header_64));
    struct load_command* cmd = cmds;
    for (uint32_t i = 0; i < cmd_count; ++i){
        switch (cmd->cmd) {
            case LC_SYMTAB:{
                struct symtab_command *sym_cmd = (struct symtab_command*)cmd;
                
                void *kernel_linkedit = file_read_with_offset(kernel_file_path, sym_cmd->symoff, (sym_cmd->stroff + sym_cmd->strsize) - sym_cmd->symoff);
                for(int i =0; i<sym_cmd->nsyms; i++){
                    struct nlist_64 *nn = (typeof(nn))((char*)kernel_linkedit + i * sizeof(struct nlist_64));
                    if(nn->n_type == 0xf){
                        char *def_str = (char*)kernel_linkedit + (sym_cmd->stroff - sym_cmd->symoff) + (uint32_t)nn->n_un.n_strx;
                        if(strstr(def_str, "_vnode_close")){
                            _vnode_close_func_addr = nn->n_value;
                            break;
                        }
                    }
                }
                free(kernel_linkedit);
            }
                break;
        }
        cmd = (struct load_command*)((char*)cmd + cmd->cmdsize);
    }
    free(kernel_macho_header);
    
    return _vnode_close_func_addr;
}

mach_vm_address_t obtain_handleTouchFrame_vtable_addr(){
    const char *driver_file_path = "/System/Library/Extensions/AppleMultitouchDriver.kext/Contents/MacOS/AppleMultitouchDriver";
    if(access(driver_file_path, F_OK)){
        printf("file not exist\n");
        exit(1);
    }
    
    mach_vm_offset_t _handleTouchFrame_vtable_addr = 0;
    
    struct mach_header_64 *driver_macho_header = file_read_with_offset(driver_file_path, 0, 0x1000);
    if(!driver_macho_header){
        printf("driver_macho_header empty\n");
        exit(1);
    }
    
    const uint32_t cmd_count = driver_macho_header->ncmds;
    struct load_command *cmds = (struct load_command*)((char*)driver_macho_header+sizeof(struct mach_header_64));
    struct load_command* cmd = cmds;
    for (uint32_t i = 0; i < cmd_count; ++i){
        switch (cmd->cmd) {
            case LC_SYMTAB:{
                struct symtab_command *sym_cmd = (struct symtab_command*)cmd;
                
                void *driver_linkedit = file_read_with_offset(driver_file_path, sym_cmd->symoff, (sym_cmd->stroff + sym_cmd->strsize) - sym_cmd->symoff);
                for(int i =0; i<sym_cmd->nsyms; i++){
                    struct nlist_64 *nn = (typeof(nn))((char*)driver_linkedit + i * sizeof(struct nlist_64));
                    if(nn->n_type == 0xf){
                        char *def_str = (char*)driver_linkedit + (sym_cmd->stroff - sym_cmd->symoff) + (uint32_t)nn->n_un.n_strx;
                        if(strstr(def_str, "_handleTouchFrame")){
                            
                            void *driver_linkedit_bef = file_read_with_offset(driver_file_path, 0, sym_cmd->symoff);
                            void *driver_linkedit_bef_mem = memmem(driver_linkedit_bef, sym_cmd->symoff, &nn->n_value, sizeof(nn->n_value));
                            _handleTouchFrame_vtable_addr = driver_linkedit_bef_mem - driver_linkedit_bef;
                            free(driver_linkedit_bef);
                            
                            break;
                        }
                    }
                }
                free(driver_linkedit);
            }
                break;
        }
        cmd = (struct load_command*)((char*)cmd + cmd->cmdsize);
    }
    free(driver_macho_header);
    
    FILE *popen_fp = popen("/usr/sbin/kextstat | /usr/bin/grep com.apple.driver.AppleMultitouchDriver | /usr/bin/tr -s \" \" | /usr/bin/cut -d \" \" -f4", "r");
    char popen_buf[32];
    fread(popen_buf, 1, sizeof(popen_buf), popen_fp);
    fclose(popen_fp);
    _handleTouchFrame_vtable_addr += strtoull(popen_buf, 0, 16);
    
    return _handleTouchFrame_vtable_addr;
}

const char *launch_config =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n\
<plist version=\"1.0\">\n\
<dict>\n\
<key>Label</key>\n\
<string>com.cocoahuke.shrinkTrackpad</string>\n\
<key>ProgramArguments</key>\n\
<array>\n\
<string>%s</string>\n\
<string>AutoBoot</string>\n\
</array>\n\
<key>UserName</key>\n\
<string>root</string>\n\
<key>RunAtLoad</key>\n\
<true/>\n\
</dict>\n\
</plist>\n";

#define shrinkTP_CMD_KASLR        _IOWR(74728, 1, mach_vm_address_t)
#define shrinkTP_CMD_INIT        _IOWR(74728, 2, mach_vm_address_t)
#define shrinkTP_CMD_ADJUST        _IOWR(74728, 3, uint64_t)
int main(int argc, const char * argv[]) {
    
    const char *kext_path = [[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/kext_shrink_trackpad.kext"] cStringUsingEncoding:NSUTF8StringEncoding];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSLocalDomainMask, YES);
    const char *applicationSupportDirectory = [[[paths firstObject] stringByAppendingString:@"/shrinkTrackpad"] cStringUsingEncoding:NSUTF8StringEncoding];
    datafilePath = global_get_datafilePath();
    
    if(getuid() == 0){

        system([[NSString stringWithFormat:@"/usr/sbin/chown -R root:wheel \"%s\"", kext_path] cStringUsingEncoding:NSUTF8StringEncoding]);
        system([[NSString stringWithFormat:@"/bin/chmod -R 755 \"%s\"", kext_path] cStringUsingEncoding:NSUTF8StringEncoding]);
        system([[NSString stringWithFormat:@"/usr/bin/kextutil \"%s\"", kext_path] cStringUsingEncoding:NSUTF8StringEncoding]);
        
        mach_vm_address_t vnode_close_addr = obtain_vnode_close_static_addr();
        mach_vm_address_t handleTouchFrame_vtable_addr = obtain_handleTouchFrame_vtable_addr();
        
        dd = global_get_shrinkdev();
        ioctl(dd, shrinkTP_CMD_KASLR, &vnode_close_addr);
        ioctl(dd, shrinkTP_CMD_INIT, &handleTouchFrame_vtable_addr);
        
        if(access(applicationSupportDirectory, F_OK))
            mkdir(applicationSupportDirectory, S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH);
        
        if(!access(datafilePath, F_OK)){
            FILE *fp = fopen(datafilePath, "ro");
            if(fp){
                uint64_t read_adjust_v = 0;
                fread(&read_adjust_v, 1, sizeof(read_adjust_v), fp);
                fclose(fp);
                ioctl(dd, shrinkTP_CMD_ADJUST, &read_adjust_v);
            }
        }
        
        char launch_config_formatted[strlen(launch_config) + 280];
        snprintf(launch_config_formatted, sizeof(launch_config_formatted), launch_config, argv[0]);
        
        const char *config_path = "/System/Library/LaunchDaemons/com.cocoahuke.shrinkTrackpad.plist";
        if(access(config_path, F_OK)){
            FILE *fp = fopen(config_path, "wb");
            if(fp){
                fwrite(launch_config_formatted, 1, strlen(launch_config_formatted), fp);
                fclose(fp);
            }
            
            system([[NSString stringWithFormat:@"/bin/launchctl load -w \"%s\"", config_path] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
    }
    
    if(argc > 1 && !strcmp(argv[1], "AutoBoot")){
        system([[NSString stringWithFormat:@"/usr/bin/kextutil \"%s\"", kext_path] cStringUsingEncoding:NSUTF8StringEncoding]);
        
        mach_vm_address_t vnode_close_addr = obtain_vnode_close_static_addr();
        mach_vm_address_t handleTouchFrame_vtable_addr = obtain_handleTouchFrame_vtable_addr();
        
        dd = global_get_shrinkdev();
        ioctl(dd, shrinkTP_CMD_KASLR, &vnode_close_addr);
        ioctl(dd, shrinkTP_CMD_INIT, &handleTouchFrame_vtable_addr);
        
        if(!access(datafilePath, F_OK)){
            FILE *fp = fopen(datafilePath, "ro");
            if(fp){
                uint64_t read_adjust_v = 0;
                fread(&read_adjust_v, 1, sizeof(read_adjust_v), fp);
                fclose(fp);
                ioctl(dd, shrinkTP_CMD_ADJUST, &read_adjust_v);
            }
        }
        return 0;
    }
    
    return NSApplicationMain(argc, argv);
}
