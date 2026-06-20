#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(ICloudKVPlugin, "ICloudKV",
    CAP_PLUGIN_METHOD(get, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(set, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(remove, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(sync, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(available, CAPPluginReturnPromise);
)
