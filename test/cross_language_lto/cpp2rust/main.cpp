#include <cstdio>

extern "C" unsigned int rust_add(unsigned int a, unsigned int b);

int main() {
    if (rust_add(40, 2) != 42) {
        std::printf("FAIL\n");
        return 1;
    }
    std::printf("Ok\n");
    return 0;
}
