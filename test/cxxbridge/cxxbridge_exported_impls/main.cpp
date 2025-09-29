#include "cxxbridge/lib.h"

#include <iostream>

int main()
{
    auto result = make_result();

    std::cout << static_cast<std::string>(result.ok->message) << std::endl;

    return 0;
}