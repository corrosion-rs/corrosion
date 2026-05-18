#include <iostream>

#include "rust_lib.h"

int main() {
  base64::engine::GeneralPurpose engine = rust_lib::make_engine();
  std::cout << "Successfully linked crubit generated C++ api: "
            << rust_lib::add(1, 2) << std::endl;
  return 0;
}
