// Loads the bundle given as the first argument and checks that it can call
// back into this program. Only runs on macOS.
#include <dlfcn.h>
#include <stdio.h>

int host_value(void) {
    return 41;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: loader <bundle>\n");
        return 2;
    }
    void *handle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        fprintf(stderr, "dlopen failed: %s\n", dlerror());
        return 1;
    }
    int (*addon_value)(void) = (int (*)(void))dlsym(handle, "addon_value");
    if (addon_value == NULL) {
        fprintf(stderr, "dlsym failed: %s\n", dlerror());
        return 1;
    }
    int value = addon_value();
    if (value != 42) {
        fprintf(stderr, "addon_value() returned %d, expected 42\n", value);
        return 1;
    }
    return 0;
}
