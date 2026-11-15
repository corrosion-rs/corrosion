#include <cstdio>
#include "crubit/incremental.h"
#include "crubit/incremental_dependency.h"

int main() {
    std::printf("%u %u", incremental::API_VERSION + incremental_dependency::DEP_VERSION,
                incremental::rust_value());
}
