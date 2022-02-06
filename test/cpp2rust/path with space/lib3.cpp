// Check that libraries located at a path containing a space can also be linked.

#include <iostream>
#include <string_view>

extern "C" void cpp_function3(char const *name) {
    std::string_view const name_sv = name;
    std::cout << "Hello, " << name_sv << "! I'm C++ library Number 3!\n";
}

