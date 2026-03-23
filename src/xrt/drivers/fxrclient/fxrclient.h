#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct xrt_auto_prober*
fxrclient_create_auto_prober(void);

struct xrt_device*
fxrclient_hmd_create(void);

#ifdef __cplusplus
}
#endif
