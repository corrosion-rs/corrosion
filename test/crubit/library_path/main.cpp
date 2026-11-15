#include "crubit/library_path.h"

int main() {
    return library_path::value() == 42 ? 0 : 1;
}
