# Integrating Automatically Generated FFI Bindings

There are a number of tools to automatically generate bindings between Rust and different
foreign languages.

1. [bindgen](#bindgen)
2. [cbindgen](#cbindgen-integration)
3. [cxx](#cxx-integration)

## bindgen

[bindgen] is a tool to automatically generate Rust bindings from C headers.
As such, integrating bindgen [via a build-script](https://rust-lang.github.io/rust-bindgen/library-usage.html)
works well and their doesn't seem to be a need to create CMake rules for
generating the bindings.

[bindgen]: https://github.com/rust-lang/rust-bindgen

## cbindgen integration

⚠️⚠️⚠️ **EXPERIMENTAL** ⚠️⚠️⚠️

[cbindgen] is a tool that generates C/C++ headers from Rust code. When compiling C/C++
code that `#include`s such generated headers the buildsystem must be aware of the dependencies.
Generating the headers via a build-script is possible, but Corrosion offers no guidance here.

Instead, Corrosion offers an experimental function to add CMake rules using cbindgen to generate
the headers.
This is not available on a stable released version yet, and the details are subject to change.
{{#include ../../cmake/Corrosion.cmake:corrosion_cbindgen}}

### Current limitations

- The current version regenerates the bindings more often then necessary to be on the safe side,
  but an upstream PR is open to solve this in a future cbindgen version.

## cxx integration

⚠️⚠️⚠️ **EXPERIMENTAL** ⚠️⚠️⚠️

[cxx] is a tool which generates bindings for C++/Rust interop.

{{#include ../../cmake/Corrosion.cmake:corrosion_add_cxxbridge}}

### A note on circular linking

`cxx` rather pointedly makes [circularly referential static libraries](https://cxx.rs/build/other.html#linking-the-c-and-rust-together) once the interface gets more complicated. This may prove a challenge to link reliably on some systems.

If you have CMake 3.24 or above, then a call to `corrosion_add_cxxbridge(my-cxx-bridge ... )` will produced a self-contained linking target `my-cxx-bridge-link`, using CMake [LINK_GROUP](https://cmake.org/cmake/help/latest/manual/cmake-generator-expressions.7.html#genex:LINK_GROUP) statements. This will translate a correct linking statement through CMake target rules.

If you are using a linker that is not GNU `ld`, you may also be OK. `ldd` has been tested and show to deal with this circular situation correctly. Other options like `mold` or `gold` may also work, but are untested.

Beyond that - you may need to create your own way of wrapping the circular references up.

Link issues that look like

```
undefined reference to `cxxbridge1$shared_ptr$NewVal$uninit'
```

are an indication you are hitting this issue.
