#include "rust_lib.h"

int main(int argc, char **argv) {
    if (argc < 2) {
        rust_function("C++");
    } else {
        rust_function(argv[1]);
    }
}
