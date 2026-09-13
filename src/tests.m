#import <Foundation/Foundation.h>
#import "AudioRender.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        Gain g = {0};
        atomic_init(&g.target, 0.25f);
        g.current = 0.25f; g.step = 1.f / 960;
        float input[] = {0.8f, -0.4f, 0.2f, -0.6f};
        float output[] = {9, 9, 9, 9};
        AudioBufferList in = {1, {{2, sizeof(input), input}}};
        AudioBufferList out = {1, {{2, sizeof(output), output}}};
        HushRender(0, NULL, &in, NULL, &out, NULL, &g);
        for (int i = 0; i < 4; i++) assert(fabsf(output[i] - input[i] * 0.25f) < 0.000001);
        assert(atomic_load(&g.callbacks) == 1);
        assert(fabsf(atomic_load(&g.outputPeak) - 0.2f) < 0.000001);
        atomic_store(&g.target, 0);
        for (int i = 0; i < 1000; i++) nextGain(&g);
        HushRender(0, NULL, &in, NULL, &out, NULL, &g);
        for (int i = 0; i < 4; i++) assert(output[i] == 0);
        atomic_store(&g.target, 1);
        float previous = g.current;
        for (int i = 0; i < 960; i++) {
            float current = nextGain(&g);
            assert(current >= previous && current - previous <= g.step + 0.000001 && current <= 1);
            previous = current;
        }
        assert(fabsf(g.current - 1) < 0.0001);
        assert(safeSample(NAN, 1) == 0 && safeSample(INFINITY, 1) == 0);
        assert(safeSample(5, 1) == 1 && safeSample(-5, 1) == -1);
        struct { UInt32 count; AudioBuffer buffers[2]; } planarIn, planarOut;
        float left[] = {0.1f, 0.3f}, right[] = {-0.2f, -0.4f}, outLeft[2], outRight[2];
        planarIn.count = planarOut.count = 2;
        planarIn.buffers[0] = (AudioBuffer){1, sizeof(left), left};
        planarIn.buffers[1] = (AudioBuffer){1, sizeof(right), right};
        planarOut.buffers[0] = (AudioBuffer){1, sizeof(outLeft), outLeft};
        planarOut.buffers[1] = (AudioBuffer){1, sizeof(outRight), outRight};
        g.current = 0.25f; atomic_store(&g.target, 0.25f);
        HushRender(0, NULL, (AudioBufferList *)&planarIn, NULL, (AudioBufferList *)&planarOut, NULL, &g);
        assert(fabsf(outLeft[1] - 0.075f) < 0.000001 && fabsf(outRight[1] + 0.1f) < 0.000001);
        HushRender(0, NULL, &in, NULL, (AudioBufferList *)&planarOut, NULL, &g);
        assert(fabsf(outLeft[0] - 0.2f) < 0.000001 && fabsf(outRight[0] + 0.1f) < 0.000001);
        HushRender(0, NULL, (AudioBufferList *)&planarIn, NULL, &out, NULL, &g);
        assert(fabsf(output[2] - 0.075f) < 0.000001 && fabsf(output[3] + 0.1f) < 0.000001);
        HushRender(0, NULL, NULL, NULL, &out, NULL, &g);
        for (int i = 0; i < 4; i++) assert(output[i] == 0);
        // Short output buffers must not overrun, and trailing output remains silent.
        out.mBuffers[0].mDataByteSize = 2 * sizeof(float);
        output[2] = 123;
        HushRender(0, NULL, &in, NULL, &out, NULL, &g);
        assert(output[2] == 123);
        out.mBuffers[0].mDataByteSize = sizeof(output);
        in.mBuffers[0].mDataByteSize = 2 * sizeof(float);
        HushRender(0, NULL, &in, NULL, &out, NULL, &g);
        assert(output[2] == 0 && output[3] == 0);
        // Unexpected channel layouts must clear output without reading input.
        in.mBuffers[0].mNumberChannels = 0;
        HushRender(0, NULL, &in, NULL, &out, NULL, &g);
        for (int i = 0; i < 4; i++) assert(output[i] == 0);
        HushRender(0, NULL, &in, NULL, NULL, NULL, &g);
        HushRender(0, NULL, &in, NULL, &out, NULL, NULL);
        printf("PASS: stereo gain, mute, ramp, clipping, invalid samples, planar/interleaved conversion, missing input.\n");
    }
}
