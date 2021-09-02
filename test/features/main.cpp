extern "C" void rust_function(char const *name);
extern "C" void rust_second_function(char const *name);
extern "C" void rust_third_function(char const *name);

int main(int argc, char **argv) {
    if (argc < 2) {
        rust_function("C++");
        rust_second_function("C++ again");
        rust_third_function("C++ again");
    } else {
        rust_function(argv[1]);
    }
}
