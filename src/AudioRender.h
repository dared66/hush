#pragma once
#import <CoreAudio/CoreAudio.h>
#import "Gain.h"

OSStatus HushRender(AudioDeviceID device, const AudioTimeStamp *now,
                   const AudioBufferList *input, const AudioTimeStamp *inputTime,
                   AudioBufferList *output, const AudioTimeStamp *outputTime, void *context);
