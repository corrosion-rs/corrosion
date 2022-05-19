#include <iostream>

extern "C" void cpp_function2(char const *name) {
    std::cout << "Hello, " << "my name is lib2.cpp" << "! I'm C++ library Number 2!\n";
}

