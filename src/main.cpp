
// We know that `main.cpp` is going to be first in unity builds.
// Therefore, we include our precompiled header here, so that it
// is first in the unity (testcases) build.
#include "stdinc.hpp"

int main(int argc, char** argv) {
  fmt::print("Hello World!\n");
  return EXIT_SUCCESS;
}
