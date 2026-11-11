// Copies neurosdk2 callback data into memory the Dart side owns (design D3).
//
// The SDK calls back on its own threads with pointers to buffers it frees as
// soon as the callback returns. A Dart NativeCallable.listener runs later on
// the Dart isolate, so it cannot read those buffers. These functions are
// registered with the SDK instead: they copy each batch into a malloc'd array
// of doubles and post it to the Dart listener passed as the SDK's userData.
// Dart frees the array with fm_free once it has read it.

#include <stdint.h>
#include <stdlib.h>

#include "cmn_type.h"

#define FM_EXPORT extern "C" __attribute__((visibility("default")))

// Values per sample or resistance report: O1, O2, T3, T4.
#define FM_CHANNELS 4

typedef void (*fm_listener)(double* data, int32_t count);

static double* fm_alloc(int64_t count) {
  return count > 0 ? (double*)malloc(sizeof(double) * count) : NULL;
}

static void fm_post(void* user, double* data, int32_t count) {
  if (user == NULL) {
    free(data);
    return;
  }
  ((fm_listener)user)(data, count);
}

template <typename T>
static void fm_copy_samples(const T* data, int32_t size, void* user) {
  if (data == NULL || size <= 0) return;
  double* out = fm_alloc((int64_t)size * FM_CHANNELS);
  if (out == NULL) return;
  for (int32_t i = 0; i < size; i++) {
    out[i * FM_CHANNELS + 0] = data[i].O1;
    out[i * FM_CHANNELS + 1] = data[i].O2;
    out[i * FM_CHANNELS + 2] = data[i].T3;
    out[i * FM_CHANNELS + 3] = data[i].T4;
  }
  fm_post(user, out, size * FM_CHANNELS);
}

template <typename T>
static void fm_copy_resist(const T& data, void* user) {
  double* out = fm_alloc(FM_CHANNELS);
  if (out == NULL) return;
  out[0] = data.O1;
  out[1] = data.O2;
  out[2] = data.T3;
  out[3] = data.T4;
  fm_post(user, out, FM_CHANNELS);
}

// Copies the first four values of each pack; missing values are NaN.
template <typename T>
static void fm_copy_first_four(const T* data, int32_t size, void* user,
                               uint32_t T::*count, double* T::*values) {
  if (data == NULL || size <= 0) return;
  double* out = fm_alloc((int64_t)size * FM_CHANNELS);
  if (out == NULL) return;
  for (int32_t i = 0; i < size; i++) {
    const uint32_t n = data[i].*count;
    const double* v = data[i].*values;
    for (uint32_t c = 0; c < FM_CHANNELS; c++) {
      out[i * FM_CHANNELS + c] = (v != NULL && c < n) ? v[c] : __builtin_nan("");
    }
  }
  fm_post(user, out, size * FM_CHANNELS);
}

FM_EXPORT void fm_headband_signal(Sensor* sensor, HeadbandSignalData* data,
                                  int32_t size, void* user) {
  fm_copy_samples(data, size, user);
}

FM_EXPORT void fm_brainbit_signal(Sensor* sensor, BrainBitSignalData* data,
                                  int32_t size, void* user) {
  fm_copy_samples(data, size, user);
}

FM_EXPORT void fm_brainbit2_signal(Sensor* sensor, SignalChannelsData* data,
                                   int32_t size, void* user) {
  fm_copy_first_four(data, size, user, &SignalChannelsData::SzSamples,
                     &SignalChannelsData::Samples);
}

FM_EXPORT void fm_headband_resist(Sensor* sensor, HeadbandResistData data,
                                  void* user) {
  fm_copy_resist(data, user);
}

FM_EXPORT void fm_brainbit_resist(Sensor* sensor, BrainBitResistData data,
                                  void* user) {
  fm_copy_resist(data, user);
}

FM_EXPORT void fm_brainbit2_resist(Sensor* sensor, ResistRefChannelsData* data,
                                   int32_t size, void* user) {
  // One report per callback is enough for the contact view: use the last.
  if (data == NULL || size <= 0) return;
  fm_copy_first_four(data + size - 1, 1, user,
                     &ResistRefChannelsData::SzSamples,
                     &ResistRefChannelsData::Samples);
}

FM_EXPORT void fm_free(double* data) { free(data); }
