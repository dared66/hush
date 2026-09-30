// Exercise the real driver callbacks with simulated clocks, without installing a HAL device.
#include "ProxyAudioDevice.h"
#include "AudioRingBuffer.h"
#include <array>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <dispatch/dispatch.h>

struct Stream {
    static constexpr UInt32 frames = 512;
    ProxyAudioDevice device;
    AudioRingBuffer ring{8, 4096};
    std::array<float, frames * 2> input{}, output{}, work{};
    AudioServerPlugInDriverRef driver = (AudioServerPlugInDriverRef)ProxyAudio_Create(nullptr, kAudioServerPlugInTypeUUID);
    Stream() {
        device.audioOutputQueue = dispatch_queue_create("hush.test.audio", DISPATCH_QUEUE_SERIAL);
        input.fill(0.25f);
        device.inputBuffer = &ring;
        device.workBuffer = (Byte *)work.data();
        device.outputDevice.sampleRate = device.gDevice_SampleRate;
        device.outputDevice.bufferFrameSize = frames;
        device.outputDevice.safetyOffset = 0;
        device.gVolume_Output_L_Value = device.gVolume_Output_R_Value = 1;
    }
    ~Stream() {
        // Start/StopIO enqueue work; drain it before this fixture goes out of scope.
        if (device.audioOutputQueue) {
            dispatch_sync(device.audioOutputQueue, ^{});
            dispatch_release(device.audioOutputQueue);
        }
    }
    void write(double frame) {
        AudioServerPlugInIOCycleInfo cycle{};
        cycle.mOutputTime.mSampleTime = frame;
        assert(device.DoIOOperation(driver, 3, 4, 1, kAudioServerPlugInIOOperationWriteMix,
                                   frames, &cycle, input.data(), nullptr) == noErr);
    }
    void render(double frame) {
        output.fill(0);
        AudioBufferList buffers{1, {{2, sizeof(output), output.data()}}};
        AudioTimeStamp time{};
        time.mSampleTime = frame;
        time.mRateScalar = 1;
        assert(device.outputDeviceIOProc(0, &time, nullptr, &time, &buffers, &time) == noErr);
    }
    bool audible() const { for (float sample : output) if (std::abs(sample) > 0.001f) return true; return false; }
    void warm() { for (int i = 0; i < 8; ++i) write(10000 + i * frames); }
};

static void clockRecovery(double offset) {
    Stream s;
    s.warm();
    s.device.inputOutputSampleDelta = offset;
    for (int i = 0; i < 8; ++i) {
        s.write(14096 + i * Stream::frames);
        s.render(14096 + i * Stream::frames);
    }
    assert(s.audible() && "clock discontinuity must recover without reselecting Hush");
    for (float sample : s.output) assert(sample == 0.25f); // unity volume stays unity
}

int main() {
    clockRecovery(-1000000); // reader stranded behind retained audio
    clockRecovery(1000000);  // reader ahead after a clock jump
    {
        Stream s;
        s.warm();
        s.device.inputOutputSampleDelta = -1000000;
        s.device.inputCycleCount = 0;
        for (int i = 0; i < 20; ++i) { s.render(20000 + i * Stream::frames); assert(!s.audible()); }
        // No new writes: must not rewind and loop old audio.
    }
    {
        Stream s;
        s.warm();
        s.device.inputFinalFrameTime = s.device.lastInputFrameTime + Stream::frames;
        s.device.inputOutputSampleDelta = 1000000;
        for (int i = 0; i < 8; ++i) { s.render(20000 + i * Stream::frames); assert(!s.audible()); }
    }
    {
        Stream s;
        s.warm();
        s.device.inputOutputSampleDelta = -1000000;
        for (int i = 0; i < 8; ++i) {
            // A larger producer block need not arrive on every output callback.
            s.write(14096 + i * Stream::frames);
            s.render(14096 + i * Stream::frames);
            s.render(14096 + i * Stream::frames + Stream::frames / 2);
        }
        assert(s.audible());
    }
    {
        Stream s;
        s.warm();
        s.device.inputOutputSampleDelta = 1000000;
        s.render(14096); // a single scheduling miss must not move the clock
        assert(s.device.inputOutputSampleDelta == 1000000);
        s.device.gMute_Output_Mute = true;
        for (int i = 0; i < 8; ++i) {
            s.write(14096 + i * Stream::frames);
            s.render(14096 + i * Stream::frames);
            assert(!s.audible());
        }
        assert(s.device.inputOutputSampleDelta != 1000000);
    }
    {
        Stream s;
        assert(s.device.StartIO(s.driver, 3, 1) == noErr);
        s.warm();
        double end = s.ring.mEndFrame;
        assert(s.device.StartIO(s.driver, 3, 2) == noErr);
        assert(s.ring.mEndFrame == end && "another client starting must not clear live audio");
        assert(s.device.StopIO(s.driver, 3, 2) == noErr);
        assert(s.device.inputFinalFrameTime == -1 && "one client stopping must not stop all audio");
        s.render(14096);
        assert(s.audible());
        assert(s.device.StopIO(s.driver, 3, 1) == noErr);
        assert(s.device.inputFinalFrameTime == end);
        assert(s.device.StartIO(s.driver, 3, 1) == noErr);
        assert(s.device.inputFinalFrameTime == -1);
        assert(s.ring.mEndFrame == 0);
    }
    puts("PASS: clock recovery, no stale-audio replay, unity gain, and overlapping audio clients.");
}
