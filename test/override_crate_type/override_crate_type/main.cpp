extern "C" void rust_function(char const *name);
extern "C" int declared_staticlib_function();

int main(int argc, char **argv) {
    if (argc < 2) {
        rust_function("Cpp");
    } else {
        rust_function(argv[1]);
    }
    return declared_staticlib_function() == 42 ? 0 : 1;
}
