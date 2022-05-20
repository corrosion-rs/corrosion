#include <iostream>

extern "C" void cpp_function2(char const *name) {
    std::cout << "Hello, " << name << "! I'm C++ library Number 2!\n";
}

