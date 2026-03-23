#include "main/comp_window.h"
#import <Foundation/Foundation.h>
#import <Syphon/Syphon.h>
#include "util/u_pacing.h"

struct comp_window_macos_syphon
{
    struct comp_target_swapchain base;
    SyphonMetalServer* syphon_server;
};

static bool comp_window_macos_syphon_init(struct comp_target *ct)
{
    return true;
}

static bool comp_window_macos_syphon_init_vulkan(struct comp_target *ct, uint32_t preferred_width, uint32_t preferred_height)
{
    U_LOG_I("trying to create macos_syphon backend");
    struct comp_window_macos_syphon *cwm = (struct comp_window_macos_syphon *)ct;
    struct vk_bundle* vk = cwm->base.base.c->nr.vk;

    VkExportMetalDeviceInfoEXT exportDeviceInfo = {
        .sType = VK_STRUCTURE_TYPE_EXPORT_METAL_DEVICE_INFO_EXT,
        .pNext = NULL,
        .mtlDevice = NULL,
    };

    VkExportMetalObjectsInfoEXT exportInfo = {
        .sType = VK_STRUCTURE_TYPE_EXPORT_METAL_OBJECTS_INFO_EXT,
        .pNext = &exportDeviceInfo,
    };

    vk->vkExportMetalObjectsEXT(vk->device, &exportInfo);

    if (exportDeviceInfo.mtlDevice == NULL)
    {
        U_LOG_W("failed to get MTLDevice from compositor VkDevice");
        return false;
    }

    NSLog(@"got MTLDevice = %@", exportDeviceInfo.mtlDevice);

    SyphonMetalServer* syphon_server = [[SyphonMetalServer alloc] initWithName:@"Monado (placeholder)" device:exportDeviceInfo.mtlDevice options:nil];
    if (syphon_server == nil)
    {
        U_LOG_W("failed to initialize Syphon Server");
        return false;
    }
    cwm->syphon_server = syphon_server;

    VkHeadlessSurfaceCreateInfoEXT info = {
        .sType = VK_STRUCTURE_TYPE_HEADLESS_SURFACE_CREATE_INFO_EXT,
        .pNext = NULL,
        .flags = 0,
    };
    VkResult ret = vk->vkCreateHeadlessSurfaceEXT(vk->instance, &info, NULL, &cwm->base.surface.handle);
    if (ret != VK_SUCCESS) {
        COMP_ERROR(ct->c, "failed to create headless surface '%s'!", vk_result_string(ret));
        return false;
    }
    return true;
}

static void comp_window_macos_syphon_set_title(struct comp_target *ct, const char *title)
{
    struct comp_window_macos_syphon *cwm = (struct comp_window_macos_syphon *)ct;
    [cwm->syphon_server setName:[NSString stringWithUTF8String:title]];
}

static VkResult comp_window_macos_syphon_present(
    struct comp_target *ct,
    struct vk_bundle_queue *present_queue,
    uint32_t index,
    uint64_t timeline_semaphore_value,
    int64_t desired_present_time_ns,
    int64_t present_slop_ns
)
{
    struct comp_window_macos_syphon *cwm = (struct comp_window_macos_syphon *)ct;
    struct vk_bundle* vk = cwm->base.base.c->nr.vk;

    VkExportMetalCommandQueueInfoEXT exportCommandQueueInfo = {
        .sType = VK_STRUCTURE_TYPE_EXPORT_METAL_COMMAND_QUEUE_INFO_EXT,
        .pNext = NULL,
        .queue = present_queue->queue,
        .mtlCommandQueue = NULL,
    };

    {
        VkExportMetalObjectsInfoEXT exportInfo = {
            .sType = VK_STRUCTURE_TYPE_EXPORT_METAL_OBJECTS_INFO_EXT,
            .pNext = &exportCommandQueueInfo,
        };
        vk->vkExportMetalObjectsEXT(vk->device, &exportInfo);
    }

    VkExportMetalTextureInfoEXT textureExportInfo = {
        .sType = VK_STRUCTURE_TYPE_EXPORT_METAL_TEXTURE_INFO_EXT,
        .pNext = NULL,

        .image = cwm->base.base.images[index].handle,
        .imageView = NULL,
        .bufferView = NULL,
        .plane = 0,

        .mtlTexture = NULL,
    };

    VkExportMetalObjectsInfoEXT exportInfo = {
        .sType = VK_STRUCTURE_TYPE_EXPORT_METAL_OBJECTS_INFO_EXT,
        .pNext = &textureExportInfo,
    };

    vk->vkExportMetalObjectsEXT(vk->device, &exportInfo);

    id<MTLTexture> texture = textureExportInfo.mtlTexture;
    id<MTLCommandBuffer> commandBuffer = [exportCommandQueueInfo.mtlCommandQueue commandBuffer];
    [cwm->syphon_server publishFrameTexture:texture onCommandBuffer:commandBuffer imageRegion:NSMakeRect(0, 0, texture.width, texture.height) flipped:false];
    [commandBuffer commit];
    [commandBuffer release];

    return VK_SUCCESS;
}

static void comp_window_macos_syphon_flush(struct comp_target *ct)
{
}

struct comp_target *
comp_window_macos_syphon_create(struct comp_compositor *c)
{
    struct comp_window_macos_syphon *w = U_TYPED_CALLOC(struct comp_window_macos_syphon);

    comp_target_swapchain_init_and_set_fnptrs(&w->base, COMP_TARGET_FORCE_FAKE_DISPLAY_TIMING);

    w->base.base.name = "Syphon macOS";
    w->base.display = VK_NULL_HANDLE;
    w->base.base.init_pre_vulkan = comp_window_macos_syphon_init;
    w->base.base.init_post_vulkan = comp_window_macos_syphon_init_vulkan;
    w->base.base.set_title = comp_window_macos_syphon_set_title;
    // TODO: probably we want to allocate BGRA8_Unorm texture (instead of RGBA8_*),
    // because Syphon would uses fast path (MTLBlitCommandEncoder) if user supplies BGRA8_Unorm texture
    // @see https://github.com/Syphon/Syphon-Framework/blob/71351d4b484cd2d1917867f7846a5cdca724552d/SyphonMetalServer.m#L56
    // w->base.base.create_images = comp_window_macos_syphon_create_images;
    w->base.base.present = comp_window_macos_syphon_present;
    w->base.base.flush = comp_window_macos_syphon_flush;

    uint64_t now_ns = os_monotonic_get_ns();
    u_pc_fake_create(c->settings.nominal_frame_interval_ns, now_ns, &w->base.upc);

    w->base.base.c = c;

    return &w->base.base;
}

static bool detect(const struct comp_target_factory *ctf, struct comp_compositor *c)
{
    return true;
}

static bool create_target(const struct comp_target_factory *ctf,
                          struct comp_compositor *c,
                          struct comp_target **out_ct)
{
    struct comp_target *ct = comp_window_macos_syphon_create(c);
    if (ct == NULL) {
        return false;
    }

    *out_ct = ct;
    return true;
}

static const char *required_instance_extensions[] = {
    VK_EXT_HEADLESS_SURFACE_EXTENSION_NAME,
};

static const char *optional_instance_extensions[] = {
    VK_EXT_METAL_OBJECTS_EXTENSION_NAME, // I'm not really sure why, but my MoltenVK fails if I require it
};

const struct comp_target_factory comp_target_factory_macos_syphon = {
    .name = "macos_syphon",
    .identifier = "macos_syphon",
    .requires_vulkan_for_create = false,
    .is_deferred = true,
    .required_instance_version = 0,
    .required_instance_extensions = required_instance_extensions,
    .required_instance_extension_count = ARRAY_SIZE(required_instance_extensions),
    .optional_device_extensions = optional_instance_extensions,
    .optional_device_extension_count = ARRAY_SIZE(optional_instance_extensions),
    .detect = detect,
    .create_target = create_target,
};
