#import "AudioRender.h"
#include <string.h>

static inline UInt32 minFrames(UInt32 a, UInt32 b) { return a < b ? a : b; }

// Called on Core Audio's real-time thread: no locks, allocation or Objective-C.
OSStatus HushRender(AudioDeviceID device, const AudioTimeStamp *now, const AudioBufferList *input,
                       const AudioTimeStamp *inputTime, AudioBufferList *out,
                       const AudioTimeStamp *outputTime, void *context) {
    Gain *g = context;
    if (!out || !g) return noErr;
    for (UInt32 b = 0; b < out->mNumberBuffers; b++)
        if (out->mBuffers[b].mData) memset(out->mBuffers[b].mData, 0, out->mBuffers[b].mDataByteSize);
    if (!input || !input->mNumberBuffers || !out->mNumberBuffers) return noErr;
    // The aggregate contains an output-only physical device followed by a stereo tap.
    BOOL inPlanar = input->mNumberBuffers == 2 && input->mBuffers[0].mNumberChannels == 1 && input->mBuffers[1].mNumberChannels == 1;
    BOOL outPlanar = out->mNumberBuffers == 2 && out->mBuffers[0].mNumberChannels == 1 && out->mBuffers[1].mNumberChannels == 1;
    if (!inPlanar && !(input->mNumberBuffers == 1 && input->mBuffers[0].mNumberChannels == 2)) return noErr;
    if (!outPlanar && !(out->mNumberBuffers == 1 && out->mBuffers[0].mNumberChannels == 2)) return noErr;
    UInt32 frames = UINT32_MAX;
    for (UInt32 b = 0; b < input->mNumberBuffers; b++) {
        if (!input->mBuffers[b].mData) return noErr;
        frames = minFrames(frames, input->mBuffers[b].mDataByteSize / (sizeof(float) * input->mBuffers[b].mNumberChannels));
    }
    for (UInt32 b = 0; b < out->mNumberBuffers; b++) {
        if (!out->mBuffers[b].mData) return noErr;
        frames = minFrames(frames, out->mBuffers[b].mDataByteSize / (sizeof(float) * out->mBuffers[b].mNumberChannels));
    }
    float ip = 0, op = 0;
    for (UInt32 f = 0; f < frames; f++) {
        float scale = nextGain(g);
        for (UInt32 c = 0; c < 2; c++) {
            float x = ((float *)input->mBuffers[inPlanar ? c : 0].mData)[inPlanar ? f : f * 2 + c];
            float y = safeSample(x, scale);
            ((float *)out->mBuffers[outPlanar ? c : 0].mData)[outPlanar ? f : f * 2 + c] = y;
            if (isfinite(x)) ip = fmaxf(ip, fabsf(x));
            op = fmaxf(op, fabsf(y));
        }
    }
    atomic_store_explicit(&g->inputPeak, ip, memory_order_relaxed);
    atomic_store_explicit(&g->outputPeak, op, memory_order_relaxed);
    atomic_fetch_add_explicit(&g->callbacks, 1, memory_order_relaxed);
    return noErr;
}
