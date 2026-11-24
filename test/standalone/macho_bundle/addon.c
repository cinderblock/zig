// A loadable module in the style of a Node.js addon: it calls back into the
// program that loads it, so it is linked with `-undefined dynamic_lookup`.
extern int host_value(void);

int addon_value(void) {
    return host_value() + 1;
}
