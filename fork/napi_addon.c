// A minimal Node-API addon. Built with
//   zig cc -target <arch>-macos -bundle -undefined dynamic_lookup -I<node>/include/node
// it must load with require() and return 42 from value().
#include <node_api.h>

static napi_value value(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value result;
    napi_create_int32(env, 42, &result);
    return result;
}

NAPI_MODULE_INIT() {
    napi_value fn;
    napi_create_function(env, "value", NAPI_AUTO_LENGTH, value, NULL, &fn);
    napi_set_named_property(env, exports, "value", fn);
    return exports;
}
