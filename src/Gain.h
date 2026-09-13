#pragma once
#include <stdatomic.h>
#include <math.h>
#include <stdint.h>

typedef struct {
    _Atomic float target;
    float current;
    float step;
    _Atomic uint64_t callbacks;
    _Atomic float inputPeak;
    _Atomic float outputPeak;
} Gain;

static inline float nextGain(Gain *g) {
    float target = atomic_load_explicit(&g->target, memory_order_relaxed);
    float delta = target - g->current;
    g->current += fmaxf(-g->step, fminf(g->step, delta));
    return g->current;
}

static inline float safeSample(float sample, float gain) {
    return isfinite(sample) ? fmaxf(-1, fminf(1, sample * gain)) : 0;
}
