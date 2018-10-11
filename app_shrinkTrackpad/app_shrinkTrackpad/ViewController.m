//
//  ViewController.m
//  app_shrinkTrackpad
//
//  Created by aa on 10/6/18.
//  Copyright © 2018 aa. All rights reserved.
//

#import "ViewController.h"
#import "MultitouchSupport.h"
#include <sys/ioctl.h>

@implementation ViewController

#define shrinkTP_CMD_KASLR        _IOWR(74728, 1, mach_vm_address_t)
#define shrinkTP_CMD_INIT        _IOWR(74728, 2, mach_vm_address_t)
#define shrinkTP_CMD_ADJUST        _IOWR(74728, 3, uint64_t)
extern int dd;
extern int global_get_shrinkdev(void);

extern const char *datafilePath;
extern const char *global_get_datafilePath(void);

NSTextField *label_collecting = NULL;
NSMutableDictionary *reddot_map = NULL;
bool reddot_appear = false; CGFloat reddot_dimen = 0;
NSView *minipad = NULL;
int16_t Xaxis_origin = 0, Yaxis_origin = 0;
uint16_t Xaxis_length = 0, Yaxis_length = 0;

void fullframe_callback(MTDeviceRef device, void *framedata, uint32_t framedata_len){
    if(framedata_len >= 0x44){
        
        framedata_len -= 0x26; framedata += 0x26;
        int nfinger = framedata_len/0x1E;
        for(int i=0; i<nfinger; i++){
            char *finger_data = framedata + 0x1E * i;
            __block int8_t iden = *(int8_t*)(finger_data);
            __block int8_t stat = *(int8_t*)(finger_data + 0x1);
            __block int16_t raw_x = *(int16_t*)(finger_data + 0x4);
            __block int16_t raw_y = *(int16_t*)(finger_data + 0x6);
            
            //printf("iden: %d stat: %d loc: %d, %d\n", iden, stat, raw_x, raw_y);
            if(label_collecting){
                dispatch_async(dispatch_get_main_queue(), ^{
                    label_collecting.stringValue = [NSString stringWithFormat:@"%d, %d", raw_x, raw_y];
                });
            }
            
            if(reddot_appear){
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    NSView *reddot = [reddot_map objectForKey:[NSString stringWithFormat:@"%d", iden]];
                    if(reddot == nil){
                        reddot = [[NSView alloc] initWithFrame:CGRectMake(0, 0, reddot_dimen, reddot_dimen)];
                        [reddot setWantsLayer:YES];
                        reddot.layer.backgroundColor = [NSColor redColor].CGColor;
                        reddot.layer.cornerRadius = 8;
                        [minipad addSubview:reddot];
                        [reddot_map setObject:reddot forKey:[NSString stringWithFormat:@"%d", iden]];
                    }
                    
                    if(stat == 0){
                        // Finger was left Trackpad
                        [reddot setHidden:YES];
                    }
                    else{
                        [reddot setHidden:NO];
                        raw_x = raw_x - Xaxis_origin;
                        raw_y = raw_y - Yaxis_origin;
                        [reddot setFrameOrigin:NSMakePoint((((float)raw_x / Xaxis_length) * NSWidth([minipad frame])) - (NSWidth([reddot frame]) / 2), (((float)raw_y / Yaxis_length) * NSHeight([minipad frame])) - (NSHeight([reddot frame]) / 2))];
                    }
                });
            }
        }
    }
}

bool DoesISP_disabled(){
    FILE *popen_fp = popen("/usr/bin/csrutil status|/usr/bin/tr -d \" \"|/usr/bin/cut -d \":\" -f2", "r");
    char popen_buf[32];
    fread(popen_buf, 1, sizeof(popen_buf), popen_fp);
    fclose(popen_fp);
    if(strstr(popen_buf, "disabled"))
        return true;
    else
        return false;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.label_ISP_indic setHidden:YES];
    [self.label_root_indic setHidden:YES];
    
    [self.direct_left setHidden:YES];
    [self.direct_right setHidden:YES];
    [self.direct_up setHidden:YES];
    [self.direct_down setHidden:YES];
    
    if(getuid() != 0){
        [self.label_root_indic setHidden:NO];
        [self.button_steps setEnabled:NO];
        [self.button_reset setEnabled:NO];
    }
    if(DoesISP_disabled() != true){
        [self.label_ISP_indic setHidden:NO];
        [self.button_steps setEnabled:NO];
        [self.button_reset setEnabled:NO];
    }
    
    extern void MTRegisterFullFrameCallback(MTDeviceRef, void (*)(MTDeviceRef, void*, uint32_t));
    
    MTDeviceRef dev = MTDeviceCreateDefault();
    MTRegisterFullFrameCallback(dev, fullframe_callback);
    //_MTUnregisterFullFrameCallback
    MTDeviceStart(dev, 0);
    
    dd = global_get_shrinkdev();
    datafilePath = global_get_datafilePath();
}

int label_num = 0;
- (NSTextField*)collecting_nextLabel{
    switch (label_num++) {
        case 0:
            return self.label_leftUpper;
            break;
        case 1:
            return self.label_rightUpper;
            break;
        case 2:
            return self.label_leftLower;
            break;
        case 3:
            return self.label_rightLower;
            break;
        default:
            return nil;
            break;
    }
    return nil;
}

int ticktock_num = 5;
- (void)start_collecting_with_timer{
    
    label_collecting = [self collecting_nextLabel];
    if(label_collecting == nil){
        // Step 1 - Ending
        [self.button_steps setEnabled:NO];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            [context setDuration:0.5];
            [[self.label_centernote animator] setAlphaValue:0.0];
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
                [context setDuration:0.5];
                self.label_centernote.stringValue = @"Now a red dot will be appear while your finger touching, try to move around to verify accuracy. Bad ? :( Close App and start over then.";
                self.button_steps.title = @"To start adjust ignore area!";
                [[self.label_centernote animator] setAlphaValue:1.0];
                [self.button_steps setTarget:self];
                [self.button_steps setAction:@selector(action_button_step2:)];
            } completionHandler:^{
                [self.label_author setHidden:YES];
                [self.label_donat setHidden:YES];
                [self.button_reset setHidden:YES];
                
                [self.button_steps setEnabled:YES];
                [self step1_reddot_appear];
            }];
        }];
        return;
    }
    
    label_collecting.textColor = [NSColor redColor];
    
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if(ticktock_num == 0){
            [timer invalidate];
            ticktock_num = 5;
            self.button_steps.title = @"Good, Next!";
            [self start_collecting_with_timer];
        }else
            self.button_steps.title = [NSString stringWithFormat:@"%d", ticktock_num--];
    }];
}

- (void)step1_reddot_appear{
    
    int16_t cmp1, cmp2;
    cmp1 = [[self.label_leftUpper.stringValue componentsSeparatedByString:@", "][0] integerValue];
    cmp2 = [[self.label_leftLower.stringValue componentsSeparatedByString:@", "][0] integerValue];
    Xaxis_origin = cmp1 > cmp2 ? cmp2 : cmp1;
    cmp1 = [[self.label_rightUpper.stringValue componentsSeparatedByString:@", "][0] integerValue];
    cmp2 = [[self.label_rightLower.stringValue componentsSeparatedByString:@", "][0] integerValue];
    Xaxis_length = abs(Xaxis_origin) + abs((cmp1 > cmp2 ? cmp1 : cmp2));
    
    cmp1 = [[self.label_leftLower.stringValue componentsSeparatedByString:@", "][1] integerValue];
    cmp2 = [[self.label_rightLower.stringValue componentsSeparatedByString:@", "][1] integerValue];
    Yaxis_origin = cmp1 > cmp2 ? cmp2 : cmp1;
    cmp1 = [[self.label_leftUpper.stringValue componentsSeparatedByString:@", "][1] integerValue];
    cmp2 = [[self.label_rightUpper.stringValue componentsSeparatedByString:@", "][1] integerValue];
    Yaxis_length = abs(Yaxis_origin) + abs((cmp1 > cmp2 ? cmp1 : cmp2));
    
    // Init mini Trackpad Area
    minipad = [[NSView alloc] initWithFrame:CGRectMake(0, 0, Xaxis_length / (Yaxis_length / (self.view.frame.size.height/1.4)), self.view.frame.size.height/1.4)];
    [minipad setFrameOrigin:NSMakePoint((NSWidth([self.view bounds]) - NSWidth([minipad frame])) / 2, (NSHeight([self.view bounds]) - NSHeight([minipad frame])) / 2)];
    [minipad setWantsLayer:YES];
    minipad.layer.backgroundColor = [[NSColor lightGrayColor] colorWithAlphaComponent:0.3].CGColor;
    minipad.alphaValue = 0.5;
    minipad.layer.cornerRadius = 8;
    [self.view addSubview:minipad];
    
    reddot_map = [NSMutableDictionary new];
    reddot_dimen = self.view.frame.size.height/18;
    reddot_appear = true;
}

- (IBAction)action_button_step1:(id)sender {
    
    [self.button_steps setEnabled:NO];
    [self start_collecting_with_timer];
}

- (IBAction)action_button_reset:(id)sender {
    uint64_t reset_v = 0;
    ioctl(dd, shrinkTP_CMD_ADJUST, &reset_v);
    
    FILE *fp = fopen(datafilePath, "wb");
    if(fp){
        fwrite(&reset_v, 1, sizeof(reset_v), fp);
        fclose(fp);
    }
}

id ArrowkeyMonitor = nil;
int ActiveArrowIndex = 0;
uint16_t ignore_amt_X = 0, ignore_amt_Y = 0;
uint16_t ignore_amt_X_minipad = 0, ignore_amt_Y_minipad = 0;
uint16_t ignore_Xaxis_left = 0, ignore_Xaxis_right = 0;
uint16_t ignore_Yaxis_up = 0, ignore_Yaxis_down = 0;
NSView *minipad_cover_left = NULL, *minipad_cover_right = NULL;
NSView *minipad_cover_up = NULL, *minipad_cover_down = NULL;
- (void)action_button_step2:(id)sender {
    [self.button_steps setEnabled:NO];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        [context setDuration:0.5];
        [[self.label_centernote animator] setAlphaValue:0.0];
    } completionHandler:^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            [context setDuration:0.5];
            self.label_centernote.stringValue = @"Step 2/2: select a button and press arrow keys to adjust. Complete? Click \"Save\" and close window.";
            self.button_steps.title = @"Save";
            [[self.label_centernote animator] setAlphaValue:1.0];
            [self.button_steps setTarget:self];
            [self.button_steps setAction:@selector(action_button_save_and_set_launch_at_login:)];
        } completionHandler:^{
            [self.label_leftUpper setHidden:YES];
            [self.label_leftLower setHidden:YES];
            [self.label_rightUpper setHidden:YES];
            [self.label_rightLower setHidden:YES];
            
            [self.button_steps setEnabled:YES];
            [self.direct_left setHidden:NO];
            [self.direct_right setHidden:NO];
            [self.direct_up setHidden:NO];
            [self.direct_down setHidden:NO];
            
            // Adjust 1/25 size each time
            ignore_amt_X = Xaxis_length / 25;
            ignore_amt_Y = Yaxis_length / 25;
            ignore_amt_X_minipad = minipad.frame.size.width / 25;
            ignore_amt_Y_minipad = minipad.frame.size.height / 25;
            
            minipad_cover_left = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 0, minipad.frame.size.height)];
            [minipad_cover_left setWantsLayer:YES];
            minipad_cover_left.layer.backgroundColor = [NSColor redColor].CGColor;
            minipad_cover_left.alphaValue = 0.25;
            [minipad addSubview:minipad_cover_left];
            
            minipad_cover_right = [[NSView alloc] initWithFrame:CGRectMake(minipad.frame.size.width, 0, 0, minipad.frame.size.height)];
            [minipad_cover_right setWantsLayer:YES];
            minipad_cover_right.layer.backgroundColor = [NSColor redColor].CGColor;
            minipad_cover_right.alphaValue = 0.25;
            [minipad addSubview:minipad_cover_right];
            
            minipad_cover_up = [[NSView alloc] initWithFrame:CGRectMake(0, minipad.frame.size.height, minipad.frame.size.width, 0)];
            [minipad_cover_up setWantsLayer:YES];
            minipad_cover_up.layer.backgroundColor = [NSColor redColor].CGColor;
            minipad_cover_up.alphaValue = 0.25;
            [minipad addSubview:minipad_cover_up];
            
            minipad_cover_down = [[NSView alloc] initWithFrame:CGRectMake(0, 0, minipad.frame.size.width, 0)];
            [minipad_cover_down setWantsLayer:YES];
            minipad_cover_down.layer.backgroundColor = [NSColor redColor].CGColor;
            minipad_cover_down.alphaValue = 0.25;
            [minipad addSubview:minipad_cover_down];
        }];
    }];
    
    
    ArrowkeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
        
        unichar character = [[event characters] characterAtIndex:0];
        switch (character) {
            case NSLeftArrowFunctionKey:{
                if(ActiveArrowIndex==1 && minipad_cover_left.frame.size.width > 0){
                    [minipad_cover_left setFrameSize:NSMakeSize(minipad_cover_left.frame.size.width - ignore_amt_X_minipad, minipad_cover_left.frame.size.height)];
                    ignore_Xaxis_left -= ignore_amt_X;
                } else if(ActiveArrowIndex==2 && minipad_cover_right.frame.size.width < minipad.frame.size.width){
                    [minipad_cover_right setFrameSize:NSMakeSize(minipad_cover_right.frame.size.width + ignore_amt_X_minipad, minipad_cover_right.frame.size.height)];
                    [minipad_cover_right setFrameOrigin:NSMakePoint(minipad_cover_right.frame.origin.x - ignore_amt_X_minipad, minipad_cover_right.frame.origin.y)];
                    ignore_Xaxis_right += ignore_amt_X;
                }
            }
                break;
            case NSRightArrowFunctionKey:{
                if(ActiveArrowIndex==1 && minipad_cover_left.frame.size.width < minipad.frame.size.width){
                    [minipad_cover_left setFrameSize:NSMakeSize(minipad_cover_left.frame.size.width + ignore_amt_X_minipad, minipad_cover_left.frame.size.height)];
                    ignore_Xaxis_left += ignore_amt_X;
                } else if(ActiveArrowIndex==2 && minipad_cover_right.frame.size.width > 0){
                    [minipad_cover_right setFrameSize:NSMakeSize(minipad_cover_right.frame.size.width - ignore_amt_X_minipad, minipad_cover_right.frame.size.height)];
                    [minipad_cover_right setFrameOrigin:NSMakePoint(minipad_cover_right.frame.origin.x + ignore_amt_X_minipad, minipad_cover_right.frame.origin.y)];
                    ignore_Xaxis_right -= ignore_amt_X;
                }
            }
                break;
            case NSUpArrowFunctionKey:{
                if(ActiveArrowIndex==3 && minipad_cover_up.frame.size.height > 0){
                    [minipad_cover_up setFrameSize:NSMakeSize(minipad_cover_up.frame.size.width, minipad_cover_up.frame.size.height - ignore_amt_Y_minipad)];
                    [minipad_cover_up setFrameOrigin:NSMakePoint(minipad_cover_up.frame.origin.x, minipad_cover_up.frame.origin.y + ignore_amt_Y_minipad)];
                    ignore_Yaxis_up -= ignore_amt_Y;
                } else if(ActiveArrowIndex==4 && minipad_cover_down.frame.size.height < minipad.frame.size.height){
                    [minipad_cover_down setFrameSize:NSMakeSize(minipad_cover_down.frame.size.width, minipad_cover_down.frame.size.height + ignore_amt_Y_minipad)];
                    ignore_Yaxis_down += ignore_amt_Y;
                }
            }
                break;
            case NSDownArrowFunctionKey:{
                if(ActiveArrowIndex==3 && minipad_cover_up.frame.size.height < minipad.frame.size.height){
                    [minipad_cover_up setFrameSize:NSMakeSize(minipad_cover_up.frame.size.width, minipad_cover_up.frame.size.height + ignore_amt_Y_minipad)];
                    [minipad_cover_up setFrameOrigin:NSMakePoint(minipad_cover_up.frame.origin.x, minipad_cover_up.frame.origin.y - ignore_amt_Y_minipad)];
                    ignore_Yaxis_up += ignore_amt_Y;
                } else if(ActiveArrowIndex==4 && minipad_cover_down.frame.size.height > 0){
                    [minipad_cover_down setFrameSize:NSMakeSize(minipad_cover_down.frame.size.width, minipad_cover_down.frame.size.height - ignore_amt_Y_minipad)];
                    ignore_Yaxis_down -= ignore_amt_Y;
                }
            }
                break;
            default:
                break;
        }
        
        uint64_t adjust_v = (uint64_t)(ignore_Xaxis_left + (uint16_t)Xaxis_origin) << 48 | (uint64_t)((Xaxis_origin + Xaxis_length) - ignore_Xaxis_right) << 32 | (uint64_t)((Yaxis_origin + Yaxis_length) - ignore_Yaxis_up) << 16 | (uint64_t)(ignore_Yaxis_down + (uint16_t)Yaxis_origin);
        ioctl(dd, shrinkTP_CMD_ADJUST, &adjust_v);
        
        //printf("%d %d %d %d\n", ignore_Xaxis_left, ignore_Xaxis_right, ignore_Yaxis_up, ignore_Yaxis_down);
        return event;
    }];
    
    
    //[self start_collecting_with_timer];
    //[self step1_reddot_appear];
}

- (void)off_allDirect{
    [self.direct_left setState:NSOffState];
    [self.direct_right setState:NSOffState];
    [self.direct_down setState:NSOffState];
    [self.direct_up setState:NSOffState];
}

- (IBAction)action_direct_left:(id)sender {
    [self off_allDirect];
    [self.direct_left setState:NSOnState];
    ActiveArrowIndex = 1;
}

- (IBAction)action_direct_right:(id)sender {
    [self off_allDirect];
    [self.direct_right setState:NSOnState];
    ActiveArrowIndex = 2;
}

- (IBAction)action_direct_up:(id)sender {
    [self off_allDirect];
    [self.direct_up setState:NSOnState];
    ActiveArrowIndex = 3;
}

- (IBAction)action_direct_down:(id)sender {
    [self off_allDirect];
    [self.direct_down setState:NSOnState];
    ActiveArrowIndex = 4;
}

- (void)action_button_save_and_set_launch_at_login:(id)sender{
    // ignore_Xaxis_left <= X <= ignore_Xaxis_right
    // ignore_Yaxis_down <= Y <= ignore_Yaxis_up
    
    uint64_t save_adjust_v = (uint64_t)(ignore_Xaxis_left + (uint16_t)Xaxis_origin) << 48 | (uint64_t)((Xaxis_origin + Xaxis_length) - ignore_Xaxis_right) << 32 | (uint64_t)((Yaxis_origin + Yaxis_length) - ignore_Yaxis_up) << 16 | (uint64_t)(ignore_Yaxis_down + (uint16_t)Yaxis_origin);
    
    FILE *fp = fopen(datafilePath, "wb");
    if(fp){
        fwrite(&save_adjust_v, 1, sizeof(save_adjust_v), fp);
        fclose(fp);
    }
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}


@end
