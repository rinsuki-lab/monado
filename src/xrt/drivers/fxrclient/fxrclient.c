#include "xrt/xrt_device.h"
#include "math/m_mathinclude.h"
#include "util/u_device.h"
#include "util/u_logging.h"
#include "util/u_distortion_mesh.h"

struct fxrclient_hmd
{
	struct xrt_device base;
};

static xrt_result_t
fxrclient_hmd_get_tracked_pose(
	struct xrt_device *xdev,
	enum xrt_input_name name,
	int64_t at_timestamp_ns,
	struct xrt_space_relation *out_relation
)
{
	return XRT_SUCCESS;
}

struct xrt_device *
fxrclient_hmd_create(void)
{
	enum u_device_alloc_flags flags =
	    (enum u_device_alloc_flags)(U_DEVICE_ALLOC_HMD | U_DEVICE_ALLOC_TRACKING_NONE);
	struct fxrclient_hmd *hmd = U_DEVICE_ALLOCATE(struct fxrclient_hmd, flags, 1, 0);

	hmd->base.name = XRT_DEVICE_GENERIC_HMD;
	hmd->base.device_type = XRT_DEVICE_TYPE_HMD;

	snprintf(hmd->base.str, XRT_DEVICE_NAME_LEN, "FruitXR HMD");
	snprintf(hmd->base.serial, XRT_DEVICE_NAME_LEN, "FXRCLIENT_HMD_SERIAL");

	// setup hmd
	{
		hmd->base.hmd->view_count = 2;
		hmd->base.hmd->blend_modes[0] = XRT_BLEND_MODE_OPAQUE;
		hmd->base.hmd->blend_mode_count = 1;

		// i didn't understand those values
		{
			hmd->base.hmd->distortion.models = XRT_DISTORTION_MODEL_NONE;
			hmd->base.hmd->distortion.preferred = XRT_DISTORTION_MODEL_NONE;
		}

		// equal to encoded video width/height
		hmd->base.hmd->screens[0].w_pixels = 1920;
		hmd->base.hmd->screens[0].h_pixels = 1080;

		for (uint32_t i=0; i<2; i++) {
			hmd->base.hmd->views[i].display.w_pixels = hmd->base.hmd->screens[0].w_pixels;
			hmd->base.hmd->views[i].display.h_pixels = hmd->base.hmd->screens[0].h_pixels;
			hmd->base.hmd->views[i].viewport.w_pixels = hmd->base.hmd->screens[0].w_pixels / 2;
			hmd->base.hmd->views[i].viewport.h_pixels = hmd->base.hmd->screens[0].h_pixels;
			hmd->base.hmd->views[i].viewport.x_pixels = i * hmd->base.hmd->views[i].viewport.w_pixels;
			hmd->base.hmd->views[i].viewport.y_pixels = 0;
			hmd->base.hmd->views[i].rot = u_device_rotation_ident;
		}

		// STUB: those values are for Quest 3, please update them if you have another headset
		{
			hmd->base.hmd->distortion.fov[0].angle_up = 43.98f * (M_PI / 180.0f);
			hmd->base.hmd->distortion.fov[0].angle_down = -54.27f * (M_PI / 180.0f);
			hmd->base.hmd->distortion.fov[0].angle_left = -54.00f * (M_PI / 180.0f);
			hmd->base.hmd->distortion.fov[0].angle_right = 40.00f * (M_PI / 180.0f);

			hmd->base.hmd->distortion.fov[1].angle_up = hmd->base.hmd->distortion.fov[0].angle_up;
			hmd->base.hmd->distortion.fov[1].angle_down = hmd->base.hmd->distortion.fov[0].angle_down;
			hmd->base.hmd->distortion.fov[1].angle_left = -hmd->base.hmd->distortion.fov[0].angle_right;
			hmd->base.hmd->distortion.fov[1].angle_right = -hmd->base.hmd->distortion.fov[0].angle_left;
		}
	}

	hmd->base.update_inputs = u_device_noop_update_inputs;
	hmd->base.get_tracked_pose = fxrclient_hmd_get_tracked_pose;
	hmd->base.get_view_poses = u_device_get_view_poses;
	u_distortion_mesh_set_none(&hmd->base);
	return &hmd->base;
}
