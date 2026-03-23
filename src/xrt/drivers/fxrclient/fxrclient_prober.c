#include "xrt/xrt_prober.h"
#include "util/u_misc.h"
#include "util/u_logging.h"
#include "fxrclient.h"

/*!
 * @implements xrt_auto_prober
 */

struct fxrclient_auto_prober
{
	struct xrt_auto_prober base;
};

//! @private @memberof fxrclient_auto_prober
static inline struct fxrclient_auto_prober *
fxrclient_auto_prober(struct xrt_auto_prober *xap)
{
	return (struct fxrclient_auto_prober *)xap;
}

//! @public @memberof fxrclient_auto_prober
static void
fxrclient_auto_prober_destroy(struct xrt_auto_prober *p)
{
	struct fxrclient_auto_prober *ap = fxrclient_auto_prober(p);
	free(ap);
}

//! @public @memberof fxrclient_auto_prober
static int
fxrclient_prober_autoprobe(struct xrt_auto_prober *xap,
			   cJSON *attached_data,
			   bool no_hmds,
			   struct xrt_prober *xp,
			   struct xrt_device **out_xdevs)
{
	if (no_hmds) {
		return 0;
	}
	out_xdevs[0] = fxrclient_hmd_create();
	return 1;
}

struct xrt_auto_prober *
fxrclient_create_auto_prober(void)
{
	struct fxrclient_auto_prober *ap = U_TYPED_CALLOC(struct fxrclient_auto_prober);
	ap->base.name = "FruitXR Client Auto-Prober";
	ap->base.destroy = fxrclient_auto_prober_destroy;
	ap->base.lelo_dallas_autoprobe = fxrclient_prober_autoprobe;

	U_LOG_I("hi from fxrclient driver");

	return &ap->base;
}
