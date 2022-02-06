#include <iostream>
#include <string_view>

extern "C" void cpp_function2(char const *name) {
    std::string_view const name_sv = name;
    std::cout << "Hello, " << name_sv << "! I'm C++ library Number 2!\n";
}

