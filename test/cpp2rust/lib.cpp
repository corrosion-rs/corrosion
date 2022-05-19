#include <iostream>

extern "C" void cpp_function(char const *name) {
    std::cout << "Hello, " << "my name is lib.cpp" << "! I'm C++!\n";
}
