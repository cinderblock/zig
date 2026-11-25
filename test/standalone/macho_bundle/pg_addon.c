// A PostgreSQL-style extension: it calls a function of the program that loads
// it, hash_create(), whose name libSystem also exports (BSD's hsearch-style
// hash_create). Linked with -bundle -bundle_loader <program>, the call must
// bind to the program, not to libSystem.
extern int hash_create(void);

int addon_value(void) {
    return hash_create() + 1;
}
